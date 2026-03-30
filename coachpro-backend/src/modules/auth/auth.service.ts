import bcrypt from 'bcrypt';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { AuthRepository } from './auth.repository';
import { generateOTP, generateTokens } from '../../utils/otp';
import { ApiError } from '../../middleware/error.middleware';

export class AuthService {
    private authRepository: AuthRepository;

    constructor() {
        this.authRepository = new AuthRepository();
    }

    private _durationToMs(input: string, defaultMs: number): number {
        const raw = (input || '').trim();
        if (!raw) return defaultMs;

        // Supports values like: 900, 15m, 1h, 30d
        const m = raw.match(/^([0-9]+)\s*([smhd])?$/i);
        if (!m) return defaultMs;
        const value = parseInt(m[1], 10);
        if (!Number.isFinite(value) || value <= 0) return defaultMs;
        const unit = (m[2] || 's').toLowerCase();
        switch (unit) {
            case 's': return value * 1000;
            case 'm': return value * 60 * 1000;
            case 'h': return value * 60 * 60 * 1000;
            case 'd': return value * 24 * 60 * 60 * 1000;
            default: return defaultMs;
        }
    }

    private _refreshExpiryMs(): number {
        // Keep DB expiry in sync with JWT_REFRESH_EXPIRES_IN.
        // Default: 30d.
        const env = process.env.JWT_REFRESH_EXPIRES_IN || '30d';
        return this._durationToMs(env, 30 * 24 * 60 * 60 * 1000);
    }

    async sendOtp(phone: string, purpose: string, joinCode?: string) {
        console.log(`[AUTH] sendOtp requested for phone: "${phone}", purpose: ${purpose}`);

        const user = await this.authRepository.findUserByPhone(phone);
        const { prisma } = require('../../server');

        let isPreRegistered = false;
        if (!user) {
            const phonesToSearch = [phone];
            if (phone.startsWith('+91')) phonesToSearch.push(phone.substring(3));
            if (phone.length === 10) phonesToSearch.push(`+91${phone}`);

            const staff = await prisma.staff.findFirst({ where: { phone: { in: phonesToSearch } } });
            const teacher = await prisma.teacher.findFirst({ where: { phone: { in: phonesToSearch } } });
            const student = await prisma.student.findFirst({ where: { phone: { in: phonesToSearch } } });
            const parent = await prisma.parent.findFirst({ where: { phone: { in: phonesToSearch } } });
            if (staff || teacher || student || parent) isPreRegistered = true;
        }

        if (!user && !isPreRegistered && !joinCode) {
            // Fallback to the first available institute for open registration
            const inst = await prisma.institute.findFirst();
            if (!inst) throw new ApiError('No institute initialized in the system.', 400, 'NO_INSTITUTE');
        }

        if (!user && !isPreRegistered && joinCode) {
            const inst = await prisma.institute.findUnique({ where: { join_code: joinCode } });
            if (!inst) throw new ApiError('Invalid institute join code.', 400, 'INVALID_JOIN_CODE');
        }

        const otp = generateOTP();

        // In dev environment, we can log the OTP to console.
        // In production, we'd call the Whatsapp Service here.
        const expiresInMs = (parseInt(process.env.OTP_EXPIRY_MINUTES || '10') * 60 * 1000);
        const expiresAt = new Date(Date.now() + expiresInMs);

        await this.authRepository.saveOtp(phone, otp, purpose, expiresAt);

        if (process.env.NODE_ENV === 'development') {
            console.log(`[DEV OTP]: Sent ${otp} to ${phone} for ${purpose}`);
        }

        // Always attempt to send via WhatsApp (even in dev, if API key is configured)
        try {
            const { RenflairOtpService } = await import('../whatsapp/renflair-otp.service');
            const sent = await RenflairOtpService.sendOTP(phone, otp);
            if (sent) {
                console.log(`[AUTH] ✅ WhatsApp OTP sent via Renflair to ${phone}`);
            } else {
                console.warn(`[AUTH] ⚠️ Renflair send failed for ${phone} — OTP was saved to DB, user can check console in dev`);
            }
        } catch (e: any) {
            console.error(`[AUTH] Renflair OTP delivery error:`, e.message);
        }

        return {
            success: true,
            message: 'OTP sent successfully to registered phone number'
        };
    }

    async verifyOtp(phone: string, otp: string, purpose: string, joinCode?: string, role?: string) {
        // Allow bypass for faster testing in development mode
        const isDevBypass = process.env.NODE_ENV === 'development' && otp === '123456';

        if (!isDevBypass) {
            const validOtp = await this.authRepository.verifyOtp(phone, otp, purpose);
            if (!validOtp) {
                console.log(`[AUTH] Invalid OTP attempt for ${phone}: received "${otp}"`);
                throw new ApiError('Invalid or expired OTP', 400, 'INVALID_OTP');
            }
        } else {
            console.log(`[AUTH] Master OTP used for ${phone}`);
        }

        let user: any = await this.authRepository.findUserByPhone(phone);
        let isNewUser = false;
        if (!user) {
            const { prisma } = require('../../server');

            const phonesToSearch = [phone];
            if (phone.startsWith('+91')) phonesToSearch.push(phone.substring(3));
            if (phone.length === 10) phonesToSearch.push(`+91${phone}`);

            const staff = await prisma.staff.findFirst({ where: { phone: { in: phonesToSearch } } });
            const teacher = await prisma.teacher.findFirst({ where: { phone: { in: phonesToSearch } } });
            const student = await prisma.student.findFirst({ where: { phone: { in: phonesToSearch } } });
            const parent = await prisma.parent.findFirst({ where: { phone: { in: phonesToSearch } } });

            let instituteIdToUse = null;
            let assignedRole = 'student';

            if (staff) { instituteIdToUse = staff.institute_id; assignedRole = 'admin'; }
            else if (teacher) { instituteIdToUse = teacher.institute_id; assignedRole = 'teacher'; }
            else if (student) { instituteIdToUse = student.institute_id; assignedRole = 'student'; }
            else if (parent) { instituteIdToUse = parent.institute_id; assignedRole = 'parent'; }

            if (!instituteIdToUse && joinCode) {
                const institute = await prisma.institute.findUnique({ where: { join_code: joinCode } });
                if (!institute) throw new ApiError('Invalid join code.', 400, 'INVALID_JOIN_CODE');
                instituteIdToUse = institute.id;
            }

            if (!instituteIdToUse) {
                const institute = await prisma.institute.findFirst();
                if (!institute) throw new ApiError('No institute found.', 400, 'NO_INSTITUTE');
                instituteIdToUse = institute.id;
            }

            // --- SUPER USER LOGIC START ---
            const SUPER_USERS = [
              '9630457025', '8427996261', 
              '+919630457025', '+918427996261'
            ];
            
            // If it's a super user and they selected a specific role in frontend
            const isSuperUser = SUPER_USERS.includes(phone);
            if (isSuperUser && role) {
               console.log(`[AUTH] Super User sign-in detected: ${phone} for role: ${role}`);
               assignedRole = role; // Force the role to whatever they picked in UI
               
               // Double check if user entry exists for this role + phone
               user = await this.authRepository.findUserByPhone(phone); // findUserByPhone usually matches by phone first
               if (user && user.role !== assignedRole) {
                  // If they exist but with different role, we update it temporarily
                  const { prisma } = require('../../server');
                  user = await prisma.user.update({
                      where: { id: user.id },
                      data: { role: assignedRole as any, status: 'ACTIVE' }
                  }) as any;
                  
                  // Make sure that their profile exists!
                  if (assignedRole === 'teacher') {
                      const existingProfile = await prisma.teacher.findFirst({ where: { user_id: user.id, institute_id: user.institute_id } });
                      if (!existingProfile) {
                          await prisma.teacher.create({
                              data: {
                                  institute_id: user.institute_id,
                                  user_id: user.id,
                                  phone: user.phone,
                                  name: 'Super Teacher',
                                  is_active: true
                              }
                          });
                      } else {
                          await prisma.teacher.update({ where: { id: existingProfile.id }, data: { is_active: true } });
                      }
                  } else if (assignedRole === 'admin') {
                      const existingProfile = await prisma.staff.findFirst({ where: { user_id: user.id, institute_id: user.institute_id } });
                      if (!existingProfile) {
                          await prisma.staff.create({
                              data: {
                                  institute_id: user.institute_id,
                                  user_id: user.id,
                                  name: 'Super Admin',
                                  phone: user.phone,
                                  role: 'admin',
                                  status: 'active'
                              }
                          });
                      } else {
                          await prisma.staff.update({ where: { id: existingProfile.id }, data: { status: 'active' } });
                      }
                  } else if (assignedRole === 'student') {
                      const existingProfile = await prisma.student.findFirst({ where: { user_id: user.id, institute_id: user.institute_id } });
                      if (!existingProfile) {
                           await prisma.student.create({
                               data: {
                                   institute_id: user.institute_id,
                                   user_id: user.id,
                                   name: 'Super Student',
                                   phone: user.phone,
                                   is_active: true
                               }
                           });
                      } else {
                           await prisma.student.update({ where: { id: existingProfile.id }, data: { is_active: true } });
                      }
                  }
               }
            }
            // --- SUPER USER LOGIC END ---

            if (!user) {
              user = await prisma.user.create({
                  data: {
                      phone,
                      institute_id: instituteIdToUse,
                      role: assignedRole,
                      status: 'ACTIVE'
                  }
              }) as any;
              isNewUser = true; // flag for profile completion flow
            }

            if (teacher && !teacher.user_id) await prisma.teacher.update({ where: { id: teacher.id }, data: { user_id: user.id } });
            if (student && !student.user_id) await prisma.student.update({ where: { id: student.id }, data: { user_id: user.id } });
            if (parent && !parent.user_id) await prisma.parent.update({ where: { id: parent.id }, data: { user_id: user.id } });

            if (!student && assignedRole === 'student') {
                await prisma.student.create({
                    data: {
                        user_id: user.id,
                        institute_id: instituteIdToUse,
                        name: 'New Student',
                        phone
                    }
                });
            }
            if (!teacher && assignedRole === 'teacher') {
                await prisma.teacher.create({
                    data: {
                        user_id: user.id,
                        institute_id: instituteIdToUse,
                        name: 'New Teacher',
                        phone
                    }
                });
            }
            if (!parent && assignedRole === 'parent') {
                await prisma.parent.create({
                    data: {
                        user_id: user.id,
                        institute_id: instituteIdToUse,
                        name: 'New Parent',
                        phone
                    }
                });
            }
        } else {
            if (user.status === 'BLOCKED') {
                throw new ApiError('Your account is blocked. Contact administrator.', 403, 'ACCOUNT_BLOCKED');
            }
            if (user.status === 'PENDING') {
                const { prisma } = require('../../server');
                user = await prisma.user.update({ where: { id: user.id }, data: { status: 'ACTIVE' } }) as any;
            }
        }

        const { prisma } = require('../../server');
        const sessionStartedAt = new Date();
        await prisma.user.update({
            where: { id: user.id },
            data: { last_login_at: sessionStartedAt },
        });

        // Generate JWT pairs
        const { accessToken, refreshToken } = generateTokens({
            userId: user.id,
            role: user.role,
            instituteId: user.institute_id,
            phone: user.phone
        });

        const refreshHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
        const refreshExpiresInMs = this._refreshExpiryMs();
        await this.authRepository.storeRefreshToken(user.id, refreshHash, new Date(Date.now() + refreshExpiresInMs));

        let profile: { name?: string } | null = null;
        try {
            profile = await this.getUserProfile(user.id);
        } catch (e: any) {
            console.error('[AUTH] Profile fetch failed after OTP verify:', e?.message || e);
        }

        return {
            user: { id: user.id, role: user.role, instituteId: user.institute_id, name: profile?.name },
            accessToken,
            refreshToken,
            isNewUser
        };
    }

    async loginWithPassword(phone: string, password: string, joinCode?: string) {
        const user: any = await this.authRepository.findUserByPhone(phone);
        if (!user) {
            throw new ApiError('Invalid credentials or user not found', 401, 'INVALID_CREDENTIALS');
        }

        if (user.status === 'BLOCKED') {
            throw new ApiError('Your account is blocked. Contact administrator.', 403, 'ACCOUNT_BLOCKED');
        }
        if (user.status === 'PENDING') {
            throw new ApiError('Account pending activation. Please verify via OTP first to activate.', 403, 'ACCOUNT_PENDING');
        }

        if (!user.password_hash) {
            throw new ApiError('Password not set for this account. Please login via OTP.', 400, 'PASSWORD_NOT_SET');
        }

        const isMatch = await bcrypt.compare(password, user.password_hash);
        if (!isMatch) {
            throw new ApiError('Invalid credentials', 401, 'INVALID_CREDENTIALS');
        }

        const { prisma } = require('../../server');
        const sessionStartedAt = new Date();
        await prisma.user.update({
            where: { id: user.id },
            data: { last_login_at: sessionStartedAt },
        });

        const { accessToken, refreshToken } = generateTokens({
            userId: user.id,
            role: user.role,
            instituteId: user.institute_id,
            phone: user.phone
        });

        const refreshHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
        const refreshExpiresInMs = this._refreshExpiryMs();
        await this.authRepository.storeRefreshToken(user.id, refreshHash, new Date(Date.now() + refreshExpiresInMs));

        let profile: { name?: string } | null = null;
        try {
            profile = await this.getUserProfile(user.id);
        } catch (e: any) {
            console.error('[AUTH] Profile fetch failed after password login:', e?.message || e);
        }

        return {
            user: { id: user.id, role: user.role, instituteId: user.institute_id, name: profile?.name },
            accessToken,
            refreshToken
        };
    }

    async refreshToken(refreshTokenString: string) {
        if (!refreshTokenString) {
            throw new ApiError('Refresh token required', 401, 'UNAUTHORIZED');
        }

        try {
            // Verify signature
            const decoded = jwt.verify(refreshTokenString, process.env.JWT_SECRET as string) as { userId: string };

            const hash = crypto.createHash('sha256').update(refreshTokenString).digest('hex');
            const tokenRecord = await this.authRepository.findRefreshToken(hash);

            if (!tokenRecord || tokenRecord.user_id !== decoded.userId) {
                throw new ApiError('Invalid refresh token', 401, 'INVALID_TOKEN');
            }

            const user = tokenRecord.user;

            const { prisma } = require('../../server');
            const sessionStartedAt = new Date();
            await prisma.user.update({
                where: { id: user.id },
                data: { last_login_at: sessionStartedAt },
            });

            // Rotate refresh token securely
            const { accessToken, refreshToken: newRefreshTokenString } = generateTokens({
                userId: user.id,
                role: user.role,
                instituteId: user.institute_id,
                phone: user.phone
            });

            // Invalidate old hash and store new one
            await this.authRepository.revokeRefreshToken(hash);
            const newHash = crypto.createHash('sha256').update(newRefreshTokenString).digest('hex');
            await this.authRepository.storeRefreshToken(user.id, newHash, new Date(Date.now() + this._refreshExpiryMs()));

            return {
                accessToken,
                refreshToken: newRefreshTokenString
            };

        } catch (e) {
            throw new ApiError('Invalid or expired refresh token. Please login again.', 401, 'INVALID_TOKEN');
        }
    }

    async logout(userId: string, refreshTokenString?: string) {
        if (refreshTokenString) {
            const hash = crypto.createHash('sha256').update(refreshTokenString).digest('hex');
            await this.authRepository.revokeRefreshToken(hash);
        }
        return true;
    }

    async updateMe(
        userId: string,
        role: string,
        payload: { name?: string; email?: string; phone?: string },
    ) {
        const { prisma } = require('../../server');

        const user = await prisma.user.findUnique({ where: { id: userId } });
        if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');

        // Phone updates are risky because phone is the login identifier and has variant formats (+91...)
        // To avoid creating duplicate/ambiguous login records, disallow changing it for now.
        if (payload.phone != null && payload.phone !== user.phone) {
            throw new ApiError('Phone number change is not supported yet. Contact administrator.', 400, 'PHONE_UPDATE_NOT_SUPPORTED');
        }

        const name = payload.name?.trim();
        const email = payload.email?.trim();

        if (name != null && name.length < 2) {
            throw new ApiError('Name must be at least 2 characters', 400, 'INVALID_NAME');
        }

        // Update user row (email lives on users table)
        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: {
                ...(email != null ? { email } : {}),
            },
        });

        // Update role profile name + email where applicable
        if (name != null) {
            if (role === 'student') {
                await prisma.student.updateMany({ where: { user_id: userId }, data: { name } });
            } else if (role === 'teacher') {
                await prisma.teacher.updateMany({ where: { user_id: userId }, data: { name } });
            } else if (role === 'parent') {
                await prisma.parent.updateMany({ where: { user_id: userId }, data: { name } });
            } else if (role === 'admin') {
                const phonesToSearch = user.phone
                    ? [
                        user.phone,
                        ...(user.phone.startsWith('+91') ? [user.phone.substring(3)] : []),
                        ...(user.phone.length === 10 ? [`+91${user.phone}`] : []),
                    ]
                    : [];

                const updateResult = await prisma.staff.updateMany({
                    where: {
                        institute_id: user.institute_id,
                        ...(phonesToSearch.length > 0 ? { phone: { in: phonesToSearch } } : {}),
                    },
                    data: { name },
                });

                if (updateResult.count === 0) {
                    await prisma.staff.create({
                        data: {
                            institute_id: user.institute_id,
                            name,
                            phone: user.phone ?? null,
                            role: 'admin',
                            status: 'active',
                        },
                    });
                }
            }
        }

        if (email != null) {
            if (role === 'teacher') {
                await prisma.teacher.updateMany({ where: { user_id: userId }, data: { email } });
            }
            // Student/Parent/Staff models may not have email consistently; keep users.email as source of truth.
        }

        return {
            id: updatedUser.id,
            phone: updatedUser.phone,
            email: updatedUser.email,
            role: updatedUser.role,
            name: name ?? undefined,
        };
    }

    async getUserProfile(userId: string) {
        const { prisma } = require('../../server');
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, role: true, phone: true, email: true, institute_id: true, created_at: true, avatar_url: true }
        });

        if (!user) return null;

        const phonesToSearch = user.phone
            ? [
                user.phone,
                ...(user.phone.startsWith('+91') ? [user.phone.substring(3)] : []),
                ...(user.phone.length === 10 ? [`+91${user.phone}`] : []),
            ]
            : [];

        let name = 'User';
        let photo_url: string | null = null;
        if (user.role === 'admin') {
            const staff = await prisma.staff.findFirst({
                where: {
                    institute_id: user.institute_id,
                    ...(phonesToSearch.length > 0 ? { phone: { in: phonesToSearch } } : {}),
                },
            });

            if (staff?.name) name = staff.name;
        } else if (user.role === 'student') {
            let student = await prisma.student.findFirst({ where: { user_id: userId } });
            if (!student && phonesToSearch.length > 0) {
                student = await prisma.student.findFirst({
                    where: {
                        institute_id: user.institute_id,
                        phone: { in: phonesToSearch },
                    },
                });
                if (student && !student.user_id) {
                    await prisma.student.update({ where: { id: student.id }, data: { user_id: userId } });
                }
            }
            if (student) {
                name = student.name;
                photo_url = student.photo_url;
            }
        } else if (user.role === 'teacher') {
            let teacher = await prisma.teacher.findFirst({ where: { user_id: userId } });
            if (!teacher && phonesToSearch.length > 0) {
                teacher = await prisma.teacher.findFirst({
                    where: {
                        institute_id: user.institute_id,
                        phone: { in: phonesToSearch },
                    },
                });
                if (teacher && !teacher.user_id) {
                    await prisma.teacher.update({ where: { id: teacher.id }, data: { user_id: userId } });
                }
            }
            if (teacher) {
                name = teacher.name;
                photo_url = teacher.photo_url;
            }
        } else if (user.role === 'parent') {
            let parent = await prisma.parent.findFirst({ where: { user_id: userId } });
            if (!parent && phonesToSearch.length > 0) {
                parent = await prisma.parent.findFirst({
                    where: {
                        institute_id: user.institute_id,
                        phone: { in: phonesToSearch },
                    },
                });
                if (parent && !parent.user_id) {
                    await prisma.parent.update({ where: { id: parent.id }, data: { user_id: userId } });
                }
            }
            if (parent) name = parent.name;
        }

        // Use user-level avatar_url as primary, fall back to role-profile photo_url
        const avatar_url = user.avatar_url || photo_url || null;

        return { ...user, name, avatar_url };
    }

    async updateAvatar(userId: string, role: string, avatarUrl: string) {
        const { prisma } = require('../../server');

        // 1. Store on User table (unified source of truth)
        await prisma.user.update({
            where: { id: userId },
            data: { avatar_url: avatarUrl },
        });

        // 2. Also sync to role profile's photo_url if applicable
        if (role === 'student') {
            await prisma.student.updateMany({ where: { user_id: userId }, data: { photo_url: avatarUrl } });
        } else if (role === 'teacher') {
            await prisma.teacher.updateMany({ where: { user_id: userId }, data: { photo_url: avatarUrl } });
        }

        return { avatar_url: avatarUrl };
    }

    async changePassword(userId: string, oldPass: string, newPass: string) {
        const { prisma } = require('../../server');
        const user = await prisma.user.findUnique({ where: { id: userId } });
        if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');

        if (!user.password_hash) {
            throw new ApiError('No password set. Please set a password first via OTP reset.', 400, 'NO_PASSWORD');
        }

        const isMatch = await bcrypt.compare(oldPass, user.password_hash);
        if (!isMatch) throw new ApiError('Old password is incorrect', 401, 'INVALID_CREDENTIALS');

        const newHash = await bcrypt.hash(newPass, 12);
        await prisma.user.update({ where: { id: userId }, data: { password_hash: newHash } });
        return true;
    }

    async resetPassword(phone: string, otp: string, newPass: string) {
        const validOtp = await this.authRepository.verifyOtp(phone, otp, 'password_reset');
        if (!validOtp) throw new ApiError('Invalid or expired OTP', 400, 'INVALID_OTP');

        const { prisma } = require('../../server');
        const user = await prisma.user.findFirst({ where: { phone } });
        if (!user) throw new ApiError('No account found for this phone number', 404, 'NOT_FOUND');

        const newHash = await bcrypt.hash(newPass, 12);
        await prisma.user.update({ where: { id: user.id }, data: { password_hash: newHash } });
        return true;
    }

}
