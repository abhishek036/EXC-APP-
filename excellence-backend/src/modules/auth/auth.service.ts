import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { AuthRepository } from './auth.repository';
import { generateOTP, generateTokens } from '../../utils/otp';
import { ApiError } from '../../middleware/error.middleware';
import { prisma } from '../../server';
import { buildPhoneVariants, normalizeIndianPhone } from '../../utils/phone';

const DUMMY_PASSWORD_HASH = '$2b$12$C6UzMDM.H6dfI/f/IKcEe.6P7w7qYgFWxW4J8nQ1fD9x3v4n6QvQW';

export class AuthService {
    private authRepository: AuthRepository;

    constructor() {
        this.authRepository = new AuthRepository();
    }

    private _isValidOtpFormat(otp: string): boolean {
        return /^\d{6}$/.test(String(otp || '').trim());
    }

    private _assertStrongPassword(password: string): void {
        const value = String(password || '');
        const strongPasswordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z\d]).{8,72}$/;
        if (!strongPasswordRegex.test(value)) {
            throw new ApiError(
                'Password must be 8-72 chars and include uppercase, lowercase, number, and special character',
                400,
                'WEAK_PASSWORD',
            );
        }
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
        // Keep DB expiry in sync with JWT_REFRESH_EXPIRES_IN with strict bounds.
        // Allowed: 7d to 30d.
        const env = process.env.JWT_REFRESH_EXPIRES_IN || '30d';
        const parsed = this._durationToMs(env, 14 * 24 * 60 * 60 * 1000);
        const minMs = 7 * 24 * 60 * 60 * 1000;
        const maxMs = 30 * 24 * 60 * 60 * 1000;
        return Math.max(minMs, Math.min(maxMs, parsed));
    }

    private _normalizeJoinCode(joinCode?: string): string | undefined {
        const normalized = String(joinCode || '').trim();
        return normalized.length > 0 ? normalized : undefined;
    }

    private _normalizeRole(role?: string): string | undefined {
        const normalized = String(role || '').trim().toLowerCase();
        if (!normalized) return undefined;
        if (!['admin', 'super_admin', 'sub_admin', 'teacher', 'student', 'parent'].includes(normalized)) return undefined;
        return normalized;
    }

    private _isAdminRole(role?: string): boolean {
        const normalized = String(role || '').trim().toLowerCase();
        return normalized === 'admin' || normalized === 'super_admin' || normalized === 'sub_admin';
    }

    private _requiresJoinCode(): boolean {
        // Join code enforcement is intentionally disabled for smoother login UX.
        return false;
    }

    private async _resolveJoinInstitute(db: any, joinCode?: string): Promise<{ id: string } | null> {
        const normalizedJoinCode = this._normalizeJoinCode(joinCode);
        if (!normalizedJoinCode) return null;

        const institute = await db.institute.findUnique({
            where: { join_code: normalizedJoinCode },
            select: { id: true },
        });

        if (!institute) {
            throw new ApiError('Invalid institute join code.', 400, 'INVALID_JOIN_CODE');
        }

        return institute;
    }

    private async _findActiveUsersByPhone(db: any, phonesToSearch: string[]): Promise<any[]> {
        return db.user.findMany({
            where: {
                phone: { in: phonesToSearch },
                is_active: true,
            },
            orderBy: { created_at: 'asc' },
        });
    }

    private async _syncParentLinkState(db: any, user: any): Promise<{ user: any; parentLink: Record<string, unknown> }> {
        const normalizedPhone = normalizeIndianPhone(user.phone);
        const resolvedPhone = normalizedPhone || String(user.phone || '').trim();

        if (!resolvedPhone) {
            throw new ApiError('Parent phone is missing on account', 400, 'PARENT_PHONE_MISSING');
        }

        if (normalizedPhone && user.phone !== normalizedPhone) {
            user = await db.user.update({
                where: { id: user.id },
                data: { phone: normalizedPhone },
            });
        }

        const phoneVariants = buildPhoneVariants(resolvedPhone);

        let parent = await db.parent.findFirst({
            where: {
                institute_id: user.institute_id,
                OR: [
                    { user_id: user.id },
                    ...(phoneVariants.length > 0 ? [{ phone: { in: phoneVariants } }] : []),
                ],
            },
        });

        if (!parent) {
            parent = await db.parent.create({
                data: {
                    institute_id: user.institute_id,
                    user_id: user.id,
                    name: 'Parent',
                    phone: resolvedPhone,
                },
            });
        } else {
            const parentPatch: Record<string, unknown> = {};
            if (parent.user_id !== user.id) parentPatch.user_id = user.id;
            if (parent.phone !== resolvedPhone) parentPatch.phone = resolvedPhone;
            if (Object.keys(parentPatch).length > 0) {
                parent = await db.parent.update({
                    where: { id: parent.id },
                    data: parentPatch,
                });
            }
        }

        const links = await db.parentStudent.findMany({
            where: { parent_id: parent.id },
            include: {
                student: {
                    select: {
                        id: true,
                        name: true,
                    },
                },
            },
        });

        const linkedStudents = links.map((entry: any) => entry.student);
        const hasLinkedStudents = linkedStudents.length > 0;
        const targetStatus = hasLinkedStudents ? 'ACTIVE' : 'INACTIVE';

        if (user.status !== targetStatus) {
            user = await db.user.update({
                where: { id: user.id },
                data: {
                    status: targetStatus,
                    is_active: true,
                },
            });
        }

        if (hasLinkedStudents) {
            return {
                user,
                parentLink: {
                    linked: true,
                    student_count: linkedStudents.length,
                    students: linkedStudents,
                },
            };
        }

        return {
            user,
            parentLink: {
                linked: false,
                student_count: 0,
                students: [],
                message: 'No student linked to this account',
                action: 'Contact coaching',
            },
        };
    }

    private _selectUserForInstitute(users: any[], instituteId?: string): any | null {
        if (instituteId) {
            const matched = users.find((entry) => entry.institute_id === instituteId) || null;
            if (!matched && users.length > 0) {
                throw new ApiError(
                    'This phone number is not registered in the provided institute.',
                    400,
                    'INSTITUTE_MISMATCH',
                );
            }
            return matched;
        }

        if (users.length > 1) {
            if (this._requiresJoinCode()) {
                throw new ApiError(
                    'Multiple accounts found for this phone. Please provide institute join code.',
                    409,
                    'AMBIGUOUS_ACCOUNT',
                );
            }

            // Non-strict mode: pick deterministic first account (ordered by created_at asc).
            return users[0] || null;
        }

        return users[0] || null;
    }

    private async _collectProfileInstituteIds(db: any, phonesToSearch: string[]): Promise<string[]> {
        const [staff, teachers, students, parents] = await Promise.all([
            db.staff.findMany({ where: { phone: { in: phonesToSearch } }, select: { institute_id: true } }),
            db.teacher.findMany({ where: { phone: { in: phonesToSearch } }, select: { institute_id: true } }),
            db.student.findMany({ where: { phone: { in: phonesToSearch } }, select: { institute_id: true } }),
            db.parent.findMany({ where: { phone: { in: phonesToSearch } }, select: { institute_id: true } }),
        ]);

        const instituteIds = new Set<string>();
        for (const entry of staff) instituteIds.add(entry.institute_id);
        for (const entry of teachers) instituteIds.add(entry.institute_id);
        for (const entry of students) instituteIds.add(entry.institute_id);
        for (const entry of parents) instituteIds.add(entry.institute_id);

        return Array.from(instituteIds);
    }

    private async _resolveInstituteId(
        db: any,
        phonesToSearch: string[],
        selectedUser: any | null,
        joinInstituteId?: string,
    ): Promise<string> {
        if (selectedUser?.institute_id) return selectedUser.institute_id;
        if (joinInstituteId) return joinInstituteId;

        const profileInstituteIds = await this._collectProfileInstituteIds(db, phonesToSearch);
        if (profileInstituteIds.length === 1) return profileInstituteIds[0];

        if (profileInstituteIds.length > 1) {
            if (this._requiresJoinCode()) {
                throw new ApiError(
                    'Multiple institutes found for this phone. Please provide institute join code.',
                    409,
                    'AMBIGUOUS_ACCOUNT',
                );
            }

            // Non-strict mode: fall back to first discovered institute.
            return profileInstituteIds[0];
        }

        const instituteCount = await db.institute.count();

        if (instituteCount > 1 && this._requiresJoinCode()) {
            throw new ApiError(
                'Institute join code is required for this phone number.',
                400,
                'JOIN_CODE_REQUIRED',
            );
        }

        if (instituteCount >= 1) {
            const fallbackInstitute = await db.institute.findFirst({ select: { id: true } });
            if (fallbackInstitute?.id) return fallbackInstitute.id;
        }

        throw new ApiError('No institute is configured. Please contact support.', 500, 'INSTITUTE_NOT_FOUND');
    }

    async sendOtp(phone: string, purpose: string, joinCode?: string) {
        console.log(`[AUTH] sendOtp requested for phone: "${phone}", purpose: ${purpose}`);

        const normalizedPhone = normalizeIndianPhone(phone);
        if (!normalizedPhone) {
            throw new ApiError('Phone number is required', 400, 'INVALID_PHONE');
        }

        const phonesToSearch = buildPhoneVariants(normalizedPhone);
        const joinInstitute = await this._resolveJoinInstitute(prisma, joinCode);
        const users = await this._findActiveUsersByPhone(prisma, phonesToSearch);

        // Validate account disambiguation early so OTP is not sent to ambiguous identities.
        this._selectUserForInstitute(users, joinInstitute?.id);

        // Do not block OTP sending on institute resolution.
        // Institute is resolved during verify/login flow.

        const otp = generateOTP();

        // In dev environment, we can log the OTP to console.
        // In production, we'd call the Whatsapp Service here.
        const expiresInMs = (parseInt(process.env.OTP_EXPIRY_MINUTES || '10') * 60 * 1000);
        const expiresAt = new Date(Date.now() + expiresInMs);

        await this.authRepository.saveOtp(normalizedPhone, otp, purpose, expiresAt);

        const testOtpEnabled =
            process.env.NODE_ENV === 'development' || process.env.ENABLE_TEST_OTP === 'true';

        if (testOtpEnabled) {
            console.log(`[DEV OTP]: Sent ${otp} to ${normalizedPhone} for ${purpose}`);
        }

        const whatsappOtpEnabled = (process.env.ENABLE_WHATSAPP_OTP ?? 'true').toLowerCase() === 'true';
        let delivered = false;
        let deliveryChannel: 'whatsapp' | 'none' = 'none';

        if (whatsappOtpEnabled) {
            try {
                const { RenflairOtpService } = await import('../whatsapp/renflair-otp.service');
                const sent = await RenflairOtpService.sendOTP(normalizedPhone, otp);
                if (sent) {
                    console.log(`[AUTH] ✅ WhatsApp OTP sent via Renflair to ${normalizedPhone}`);
                    delivered = true;
                    deliveryChannel = 'whatsapp';
                } else {
                    console.warn(`[AUTH] ⚠️ Renflair send failed for ${normalizedPhone} — OTP was saved to DB, user can check console in dev`);
                }
            } catch (e: any) {
                console.error(`[AUTH] Renflair OTP delivery error:`, e.message);
            }
        } else {
            console.log(`[AUTH] WhatsApp OTP delivery disabled via ENABLE_WHATSAPP_OTP=false`);
        }

        const debugOtp = testOtpEnabled ? (process.env.TEST_OTP || '123456') : undefined;

        return {
            success: true,
            message: delivered
                ? 'OTP sent successfully to registered phone number'
                : 'OTP generated but delivery channel is unavailable',
            deliveryChannel,
            delivered,
            debugOtp,
        };
    }

    async verifyOtp(phone: string, otp: string, purpose: string, joinCode?: string, role?: string) {
        if (!this._isValidOtpFormat(otp)) {
            throw new ApiError('OTP must be exactly 6 numeric digits', 400, 'INVALID_OTP_FORMAT');
        }

        const normalizedPhone = normalizeIndianPhone(phone);
        if (!normalizedPhone) {
            throw new ApiError('Phone number is required', 400, 'INVALID_PHONE');
        }

        // --- 1. OTP CHECK (Outside main transaction to avoid locking OTP table long-term) ---
        const isDevBypass = (process.env.NODE_ENV === 'development' || process.env.ENABLE_TEST_OTP === 'true') && 
                            otp === (process.env.TEST_OTP || '123456');

        if (!isDevBypass) {
            const validOtp = await this.authRepository.verifyOtp(normalizedPhone, otp, purpose);
            if (!validOtp) {
                console.log(`[AUTH] Invalid OTP attempt for ${normalizedPhone}: received "${otp}"`);
                throw new ApiError('Invalid or expired OTP', 400, 'INVALID_OTP');
            }
        } else {
            console.log(`[AUTH] Master OTP used for ${normalizedPhone}`);
        }

        // --- 2. RUN REGISTRATION/LOGIN LOGIC IN TRANSACTION ---
        return await prisma.$transaction(async (tx: any) => {
            const phonesToSearch = buildPhoneVariants(normalizedPhone);
            const joinInstitute = await this._resolveJoinInstitute(tx, joinCode);
            const users = await this._findActiveUsersByPhone(tx, phonesToSearch);
            let user: any = this._selectUserForInstitute(users, joinInstitute?.id);

            let isNewUser = false;

            const instituteIdToUse = await this._resolveInstituteId(
                tx,
                phonesToSearch,
                user,
                joinInstitute?.id,
            );

            const [staff, teacher, inactiveTeacher, studentCandidates, parent] = await Promise.all([
                tx.staff.findFirst({ where: { institute_id: instituteIdToUse, phone: { in: phonesToSearch } } }),
                tx.teacher.findFirst({
                    where: {
                        institute_id: instituteIdToUse,
                        phone: { in: phonesToSearch },
                        is_active: true,
                    },
                }),
                tx.teacher.findFirst({
                    where: {
                        institute_id: instituteIdToUse,
                        phone: { in: phonesToSearch },
                        is_active: false,
                    },
                    select: { id: true },
                }),
                tx.student.findMany({
                    where: {
                        institute_id: instituteIdToUse,
                        phone: { in: phonesToSearch },
                    },
                    include: {
                        student_batches: {
                            where: { is_active: true },
                            select: { id: true },
                        },
                    },
                    orderBy: { created_at: 'desc' },
                }),
                tx.parent.findFirst({ where: { institute_id: instituteIdToUse, phone: { in: phonesToSearch } } })
            ]);

            const student =
                studentCandidates.find((s: any) => s.user_id === user?.id) ||
                studentCandidates.find((s: any) => !!s.user_id) ||
                studentCandidates.find((s: any) => (s.student_batches?.length || 0) > 0) ||
                studentCandidates[0] ||
                null;

            if (!user && !staff && !teacher && inactiveTeacher) {
                throw new ApiError(
                    'Teacher account is inactive. Please contact institute admin.',
                    403,
                    'ACCOUNT_INACTIVE',
                );
            }

            // --- SUPER USER ROLE SWITCHING ---
            const SUPER_USER_PHONES = (process.env.SUPER_USER_PHONES || '9630457025,8427996261').split(',').map(p => p.trim()).filter(Boolean);
            const isSuperUser = SUPER_USER_PHONES.some(p => phone.includes(p));

            const requestedRole = this._normalizeRole(role);
            const inferredRole = staff ? 'admin' : (teacher ? 'teacher' : (student ? 'student' : (parent ? 'parent' : 'student')));
            let assignedRole = user?.role || inferredRole;

            if (!user && requestedRole) {
                assignedRole = requestedRole;
            }

            if (isSuperUser && requestedRole) {
                assignedRole = requestedRole;
                console.log(`[AUTH] Super User Switch: ${phone} -> ${assignedRole}`);
                
                if (user && user.role !== assignedRole) {
                    user = await tx.user.update({
                        where: { id: user.id },
                        data: { role: assignedRole as any }
                    });
                }
            }

            // --- CREATE USER IF NOT EXISTS ---
            if (!user) {
                user = await tx.user.create({
                    data: {
                        phone: normalizedPhone,
                        institute_id: instituteIdToUse,
                        role: assignedRole,
                        status: assignedRole === 'parent' ? 'INACTIVE' : 'ACTIVE'
                    }
                });
                isNewUser = true;
            } else {
                if (user.status === 'BLOCKED') throw new ApiError('Blocked.', 403, 'BLOCKED');
                if (user.status === 'PENDING') {
                    user = await tx.user.update({
                        where: { id: user.id },
                        data: { status: user.role === 'parent' ? 'INACTIVE' : 'ACTIVE' },
                    });
                }
            }

            // --- ENSURE PROFILE MATCHES ROLE AND SYNC user_id ---
            if (assignedRole === 'teacher' && !teacher) {
                await tx.teacher.create({
                    data: { user_id: user.id, institute_id: instituteIdToUse, name: 'Faculty Member', phone: user.phone, is_active: true }
                });
            } else if (assignedRole === 'student' && !student) {
                await tx.student.create({
                    data: { user_id: user.id, institute_id: instituteIdToUse, name: 'Student Profile', phone: user.phone, is_active: true }
                });
            }

            // Link existing loose profiles
            if (teacher && !teacher.user_id) await tx.teacher.update({ where: { id: teacher.id }, data: { user_id: user.id } });
            if (student && !student.user_id) await tx.student.update({ where: { id: student.id }, data: { user_id: user.id } });
            if (parent && !parent.user_id) await tx.parent.update({ where: { id: parent.id }, data: { user_id: user.id } });

            let parentLink: Record<string, unknown> | undefined;
            if (user.role === 'parent') {
                const syncResult = await this._syncParentLinkState(tx, user);
                user = syncResult.user;
                parentLink = syncResult.parentLink;
            }

            const sessionStartedAt = new Date();
            await tx.user.update({
                where: { id: user.id },
                data: { last_login_at: sessionStartedAt },
            });

            // CLEAR ALL PREVIOUS REFRESH TOKENS (Single device login compliance)
            await tx.refreshToken.deleteMany({
                where: { user_id: user.id }
            });

            // Generate JWT pairs
            const { accessToken, refreshToken } = generateTokens({
                userId: user.id,
                role: user.role,
                instituteId: user.institute_id,
                phone: user.phone
            });

            const refreshHash = crypto.createHash('sha256').update(refreshToken).digest('hex');
            const expiresAt = new Date(Date.now() + this._refreshExpiryMs());
            
            await tx.refreshToken.create({
                data: {
                    user_id: user.id,
                    token_hash: refreshHash,
                    expires_at: expiresAt
                }
            });

            let profile: { name?: string } | null = null;
            try {
                // profile fetch might look inside tx or outside?
                // we'll fetch it outside the tx if it's purely read, but better inside if it uses tx client.
                profile = await tx.student.findFirst({ where: { user_id: user.id, institute_id: instituteIdToUse } })
                         || await tx.teacher.findFirst({ where: { user_id: user.id, institute_id: instituteIdToUse } })
                         || await tx.parent.findFirst({ where: { user_id: user.id, institute_id: instituteIdToUse } })
                         || await tx.staff.findFirst({ where: { institute_id: instituteIdToUse, phone: { in: this._phoneVariants(phone) } } });
            } catch (_error: any) {}

            return {
                user: { id: user.id, role: user.role, instituteId: user.institute_id, name: profile?.name },
                accessToken,
                refreshToken,
                isNewUser,
                ...(parentLink ? { parent_link: parentLink } : {}),
            };
        });
    }

    private _phoneVariants(phone: string) {
        return buildPhoneVariants(phone);
    }

    async loginWithPassword(phone: string, password: string, joinCode?: string) {
        const normalizedPhone = normalizeIndianPhone(phone);
        if (!normalizedPhone) {
            throw new ApiError('Phone number is required', 400, 'INVALID_PHONE');
        }

        const phonesToSearch = this._phoneVariants(normalizedPhone);
        const joinInstitute = await this._resolveJoinInstitute(prisma, joinCode);
        const users = await this._findActiveUsersByPhone(prisma, phonesToSearch);
        let user: any = this._selectUserForInstitute(users, joinInstitute?.id);

        if (!user) {
            await bcrypt.compare(String(password || ''), DUMMY_PASSWORD_HASH);
            throw new ApiError('Invalid credentials', 401, 'INVALID_CREDENTIALS');
        }

        if (user.status === 'BLOCKED') {
            throw new ApiError('Your account is blocked. Contact administrator.', 403, 'ACCOUNT_BLOCKED');
        }
        if (user.status === 'PENDING') {
            throw new ApiError('Account pending activation. Please verify via OTP first to activate.', 403, 'ACCOUNT_PENDING');
        }

        if (!user.password_hash) {
            await bcrypt.compare(String(password || ''), DUMMY_PASSWORD_HASH);
            throw new ApiError('Invalid credentials', 401, 'INVALID_CREDENTIALS');
        }

        const isMatch = await bcrypt.compare(password, user.password_hash);
        if (!isMatch) {
            throw new ApiError('Invalid credentials', 401, 'INVALID_CREDENTIALS');
        }

        let parentLink: Record<string, unknown> | undefined;
        if (user.role === 'parent') {
            const syncResult = await this._syncParentLinkState(prisma, user);
            user = syncResult.user;
            parentLink = syncResult.parentLink;
        }

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
        } catch (_error: any) {
            console.error('[AUTH] Profile fetch failed after password login:', _error?.message || _error);
        }

        return {
            user: { id: user.id, role: user.role, instituteId: user.institute_id, name: profile?.name },
            accessToken,
            refreshToken,
            ...(parentLink ? { parent_link: parentLink } : {}),
        };
    }

    async refreshToken(refreshTokenString: string) {
        if (!refreshTokenString) {
            throw new ApiError('Refresh token required', 401, 'UNAUTHORIZED');
        }

        try {
            // Verify signature
            const decoded = jwt.verify(refreshTokenString, process.env.JWT_SECRET as string, {
                algorithms: ['HS256'],
                clockTolerance: 300,
            }) as { userId: string };

            if (!decoded || typeof decoded.userId !== 'string') {
                throw new ApiError('Invalid refresh token payload', 401, 'INVALID_TOKEN');
            }

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

        } catch (_error) {
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
                await prisma.student.updateMany({ where: { user_id: userId, institute_id: user.institute_id }, data: { name } });
            } else if (role === 'teacher') {
                await prisma.teacher.updateMany({ where: { user_id: userId, institute_id: user.institute_id }, data: { name } });
            } else if (role === 'parent') {
                await prisma.parent.updateMany({ where: { user_id: userId, institute_id: user.institute_id }, data: { name } });
            } else if (this._isAdminRole(role)) {
                const phonesToSearch = user.phone
                    ? this._phoneVariants(user.phone)
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
                await prisma.teacher.updateMany({ where: { user_id: userId, institute_id: user.institute_id }, data: { email } });
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

        // FIX: CRITICAL - Always scope to institute_id to prevent cross-institute data leaks
        const instituteId = user.institute_id;

        const institute = await prisma.institute.findUnique({
            where: { id: instituteId },
            select: { settings: true },
        });

        const settings = (institute?.settings ?? {}) as Record<string, any>;
        const rawVideoPolicy = (settings['video_policy'] ?? {}) as Record<string, any>;
        const rawDefaultVisibility = String(rawVideoPolicy['default_visibility'] ?? 'unlisted').toLowerCase();
        const defaultVisibility = rawDefaultVisibility === 'public' ? 'public' : 'unlisted';
        const allowPublicUploads = rawVideoPolicy['allow_public_uploads'] === true;

        // FIX: Improved phone normalization - always normalize to consistent format +91 prefix
        const phonesToSearch = user.phone
            ? this._normalizePhones(user.phone)
            : [];

        let name = 'User';
        let photo_url: string | null = null;
        if (this._isAdminRole(user.role)) {
            const staff = await prisma.staff.findFirst({
                where: {
                    institute_id: instituteId,
                    ...(phonesToSearch.length > 0 ? { phone: { in: phonesToSearch } } : {}),
                },
            });

            if (staff?.name) name = staff.name;
        } else if (user.role === 'student') {
            // FIX: ALWAYS use institute_id filter - this was missing!
            let student = await prisma.student.findFirst({ 
                where: { user_id: userId, institute_id: instituteId } 
            });
            if (!student && phonesToSearch.length > 0) {
                // Secondary lookup by phone with institute_id filter
                student = await prisma.student.findFirst({
                    where: {
                        institute_id: instituteId,
                        phone: { in: phonesToSearch },
                    },
                });
                // FIX: Only link if found and user_id is null (orphan profile)
                if (student && !student.user_id) {
                    await prisma.student.update({ where: { id: student.id }, data: { user_id: userId } });
                }
            }
            if (student) {
                name = student.name;
                photo_url = student.photo_url;
            }
        } else if (user.role === 'teacher') {
            // FIX: ALWAYS use institute_id filter
            let teacher = await prisma.teacher.findFirst({ 
                where: { user_id: userId, institute_id: instituteId } 
            });
            if (!teacher && phonesToSearch.length > 0) {
                teacher = await prisma.teacher.findFirst({
                    where: {
                        institute_id: instituteId,
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
            // FIX: ALWAYS use institute_id filter
            let parent = await prisma.parent.findFirst({ 
                where: { user_id: userId, institute_id: instituteId } 
            });
            if (!parent && phonesToSearch.length > 0) {
                parent = await prisma.parent.findFirst({
                    where: {
                        institute_id: instituteId,
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

        return {
            ...user,
            name,
            avatar_url,
            video_policy: {
                default_visibility: defaultVisibility,
                allow_public_uploads: allowPublicUploads,
            },
        };
    }

    // FIX: Improved phone normalization to ensure consistent format
    private _normalizePhones(phone: string): string[] {
        return this._phoneVariants(phone);
    }

    async updateAvatar(userId: string, role: string, avatarUrl: string) {
        const { prisma } = require('../../server');

        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: { institute_id: true },
        });
        if (!user) {
            throw new ApiError('User not found', 404, 'NOT_FOUND');
        }

        // 1. Store on User table (unified source of truth)
        await prisma.user.update({
            where: { id: userId },
            data: { avatar_url: avatarUrl },
        });

        // 2. Also sync to role profile's photo_url if applicable
        if (role === 'student') {
            await prisma.student.updateMany({ where: { user_id: userId, institute_id: user.institute_id }, data: { photo_url: avatarUrl } });
        } else if (role === 'teacher') {
            await prisma.teacher.updateMany({ where: { user_id: userId, institute_id: user.institute_id }, data: { photo_url: avatarUrl } });
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

        this._assertStrongPassword(newPass);

        const newHash = await bcrypt.hash(newPass, 12);
        await prisma.user.update({ where: { id: userId }, data: { password_hash: newHash } });
        return true;
    }

    async resetPassword(phone: string, otp: string, newPass: string, joinCode?: string) {
        if (!this._isValidOtpFormat(otp)) {
            throw new ApiError('OTP must be exactly 6 numeric digits', 400, 'INVALID_OTP_FORMAT');
        }

        const validOtp = await this.authRepository.verifyOtp(phone, otp, 'password_reset');
        if (!validOtp) throw new ApiError('Invalid or expired OTP', 400, 'INVALID_OTP');

        const { prisma } = require('../../server');
        const phonesToSearch = this._phoneVariants(phone);
        const joinInstitute = await this._resolveJoinInstitute(prisma, joinCode);
        const users = await this._findActiveUsersByPhone(prisma, phonesToSearch);
        const user = this._selectUserForInstitute(users, joinInstitute?.id);

        if (!user) throw new ApiError('No account found for this phone number', 404, 'NOT_FOUND');

        this._assertStrongPassword(newPass);

        const newHash = await bcrypt.hash(newPass, 12);
        await prisma.user.update({ where: { id: user.id }, data: { password_hash: newHash } });
        return true;
    }

}
