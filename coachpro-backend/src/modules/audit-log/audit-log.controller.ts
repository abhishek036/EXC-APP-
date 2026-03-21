import { Request, Response, NextFunction } from 'express';
import { prisma } from '../../server';

export class AuditLogController {
  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const instituteId = req.user!.instituteId;
      const page = parseInt(req.query.page as string) || 1;
      const perPage = parseInt(req.query.perPage as string) || 30;
      const skip = (page - 1) * perPage;

      const [logs, total] = await Promise.all([
        prisma.auditLog.findMany({
          where: { institute_id: instituteId },
          orderBy: { created_at: 'desc' },
          skip,
          take: perPage,
          include: {
            actor: {
              select: { id: true, phone: true, role: true }
            }
          }
        }),
        prisma.auditLog.count({ where: { institute_id: instituteId } })
      ]);

      return res.status(200).json({
        success: true,
        data: logs,
        meta: {
          page,
          perPage,
          total,
          totalPages: Math.ceil(total / perPage)
        }
      });
    } catch (error) {
      next(error);
    }
  };
}
