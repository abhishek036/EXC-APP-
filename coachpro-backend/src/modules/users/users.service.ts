import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

const VALID_STATUSES = ['ACTIVE', 'INACTIVE', 'BLOCKED', 'PENDING'];
const VALID_ROLES = ['admin', 'teacher', 'student', 'parent'];

// Use any to bypass stale Prisma type definitions after migration
const USER_SELECT: any = {
  id: true, phone: true, email: true, role: true,
  status: true, is_active: true, created_at: true,
};

export class UsersService {
  private ensureInstituteId(instituteId?: string): string {
    const normalized = instituteId?.trim();
    if (!normalized) {
      throw new ApiError('Institute context is required', 400, 'INSTITUTE_ID_REQUIRED');
    }
    return normalized;
  }

  async listUsers(
    instituteId: string,
    filters: { role?: string; status?: string; search?: string; page: number; perPage: number }
  ) {
    instituteId = this.ensureInstituteId(instituteId);
    const { page, perPage } = filters;
    const skip = (page - 1) * perPage;

    const where: any = { institute_id: instituteId };
    if (filters.role) where.role = filters.role;
    if (filters.status) where.status = filters.status;
    if (filters.search) {
      where.OR = [
        { phone: { contains: filters.search, mode: 'insensitive' } },
        { email: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    const [users, total] = await Promise.all([
      (prisma.user as any).findMany({
        where,
        select: USER_SELECT,
        skip,
        take: perPage,
        orderBy: { created_at: 'desc' },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      data: users,
      meta: { page, perPage, total, totalPages: Math.ceil(total / perPage) },
    };
  }

  async getUserById(userId: string, instituteId: string) {
    instituteId = this.ensureInstituteId(instituteId);
    const user = await (prisma.user as any).findFirst({
      where: { id: userId, institute_id: instituteId },
      select: USER_SELECT,
    });
    if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');
    return user;
  }

  async updateStatus(userId: string, instituteId: string, status: string) {
    instituteId = this.ensureInstituteId(instituteId);
    if (!VALID_STATUSES.includes(status)) {
      throw new ApiError(`Invalid status. Must be one of: ${VALID_STATUSES.join(', ')}`, 400, 'INVALID_STATUS');
    }

    const user = await prisma.user.findFirst({ where: { id: userId, institute_id: instituteId } });
    if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');

    const isActive = status === 'ACTIVE';

    // Transaction to update user and all correlated data
    return prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id: userId },
        data: { status, is_active: isActive },
        select: USER_SELECT as any,
      });

      // Mirror the activation state to the user's primary profiles based on their role
      if (user.role === 'student') {
        await tx.student.updateMany({
           where: { phone: user.phone, institute_id: instituteId },
           data: { is_active: isActive }
        });
        if (!isActive) {
           const student = await tx.student.findFirst({ where: { phone: user.phone, institute_id: instituteId }});
           if (student) {
              await tx.studentBatch.updateMany({
                  where: { student_id: student.id, is_active: true },
                  data: { is_active: false, left_date: new Date() }
              });
           }
        }
      } else if (user.role === 'teacher') {
        await tx.teacher.updateMany({
           where: { phone: user.phone, institute_id: instituteId },
           data: { is_active: isActive }
        });
      }

      // 🛡️ SECURITY: If the user is being blocked or deactivated, revoke their current active login sessions immediately
      if (!isActive) {
        await tx.refreshToken.updateMany({
          where: { user_id: userId, revoked_at: null },
          data: { revoked_at: new Date() }
        });
      }

      return updated;
    });
  }

  async changeRole(userId: string, instituteId: string, role: string) {
    instituteId = this.ensureInstituteId(instituteId);
    if (!VALID_ROLES.includes(role)) {
      throw new ApiError(`Invalid role. Must be one of: ${VALID_ROLES.join(', ')}`, 400, 'INVALID_ROLE');
    }

    const user = await prisma.user.findFirst({ where: { id: userId, institute_id: instituteId } });
    if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');

    return prisma.$transaction(async (tx) => {
      const updatedUser = await tx.user.update({
        where: { id: userId },
        data: { role },
        select: { id: true, phone: true, role: true, is_active: true, email: true } as any,
      });

      if (role === 'teacher') {
        // Look for existing teacher
        const existingTeacher = await tx.teacher.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
        if (existingTeacher) {
          await tx.teacher.update({ where: { id: existingTeacher.id }, data: { user_id: userId, is_active: true } });
        } else {
          // Get name from student if available
          const student = await tx.student.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
          await tx.teacher.create({
            data: {
              institute_id: instituteId,
              user_id: userId,
              phone: user.phone,
              name: student?.name || 'New Teacher',
              email: user.email,
              is_active: true
            }
          });
        }
        // Disable student profile so they don't appear in active student lists
        await tx.student.updateMany({
          where: { phone: user.phone, institute_id: instituteId },
          data: { is_active: false }
        });
        // Remove from active batches
        const oldStudent = await tx.student.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
        if (oldStudent) {
            await tx.studentBatch.updateMany({
                where: { student_id: oldStudent.id, is_active: true },
                data: { is_active: false, left_date: new Date() }
            });
        }
      } else if (role === 'student') {
        // Look for existing student
        const existingStudent = await tx.student.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
        if (existingStudent) {
          await tx.student.update({ where: { id: existingStudent.id }, data: { user_id: userId, is_active: true } });
        } else {
          // Get name from teacher if available
          const teacher = await tx.teacher.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
          await tx.student.create({
            data: {
              institute_id: instituteId,
              user_id: userId,
              phone: user.phone,
              name: teacher?.name || 'New Student',
              is_active: true
            }
          });
        }
        // Disable teacher profile so they don't appear in active teacher contexts
        await tx.teacher.updateMany({
          where: { phone: user.phone, institute_id: instituteId },
          data: { is_active: false }
        });
        // Optional: Admin needs to manually reassign batches taught by this teacher
      } else {
        // If changing to parent, link or create a parent profile
        if (role === 'parent') {
          const existingParent = await tx.parent.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
          if (existingParent) {
            await tx.parent.update({ where: { id: existingParent.id }, data: { user_id: userId } });
          } else {
            const oldProf = await tx.student.findFirst({ where: { phone: user.phone, institute_id: instituteId } })
              || await tx.teacher.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
            
            await tx.parent.create({
              data: {
                institute_id: instituteId,
                user_id: userId,
                phone: user.phone,
                name: (oldProf as any)?.name || 'New Parent',
              }
            });
          }
        }

        // Deactivate both teacher and student to avoid listing them
        await tx.teacher.updateMany({
          where: { phone: user.phone, institute_id: instituteId },
          data: { is_active: false }
        });
        await tx.student.updateMany({
          where: { phone: user.phone, institute_id: instituteId },
          data: { is_active: false }
        });
        const oldStudent = await tx.student.findFirst({ where: { phone: user.phone, institute_id: instituteId } });
        if (oldStudent) {
            await tx.studentBatch.updateMany({
                where: { student_id: oldStudent.id, is_active: true },
                data: { is_active: false, left_date: new Date() }
            });
        }
      }

      // 🛡️ SECURITY: Revoke all refresh tokens for this user so they are forced to log in again with their new role capabilities
      await tx.refreshToken.updateMany({
        where: { user_id: userId, revoked_at: null },
        data: { revoked_at: new Date() }
      });

      return updatedUser;
    });
  }
}
