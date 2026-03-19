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
  async listUsers(
    instituteId: string,
    filters: { role?: string; status?: string; search?: string; page: number; perPage: number }
  ) {
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
    const user = await (prisma.user as any).findFirst({
      where: { id: userId, institute_id: instituteId },
      select: USER_SELECT,
    });
    if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');
    return user;
  }

  async updateStatus(userId: string, instituteId: string, status: string) {
    if (!VALID_STATUSES.includes(status)) {
      throw new ApiError(`Invalid status. Must be one of: ${VALID_STATUSES.join(', ')}`, 400, 'INVALID_STATUS');
    }

    const user = await prisma.user.findFirst({ where: { id: userId, institute_id: instituteId } });
    if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');

    return (prisma.user as any).update({
      where: { id: userId },
      data: { status, is_active: status === 'ACTIVE' },
      select: USER_SELECT,
    });
  }

  async changeRole(userId: string, instituteId: string, role: string) {
    if (!VALID_ROLES.includes(role)) {
      throw new ApiError(`Invalid role. Must be one of: ${VALID_ROLES.join(', ')}`, 400, 'INVALID_ROLE');
    }

    const user = await prisma.user.findFirst({ where: { id: userId, institute_id: instituteId } });
    if (!user) throw new ApiError('User not found', 404, 'NOT_FOUND');

    return prisma.user.update({
      where: { id: userId },
      data: { role },
      select: { id: true, phone: true, role: true, is_active: true } as any,
    });
  }
}
