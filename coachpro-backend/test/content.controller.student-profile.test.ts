jest.mock('../src/modules/upload/upload.controller', () => ({
  UploadController: class {},
}));

jest.mock('../src/server', () => ({
  prisma: {
    user: { findUnique: jest.fn() },
    student: { findMany: jest.fn(), updateMany: jest.fn() },
  },
}));

import { ContentController } from '../src/modules/content/content.controller';
import { prisma } from '../src/server';

describe('ContentController.resolveStudentProfile', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('prefers user-linked student over unlinked candidate even with more batches', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      phone: '+919876543210',
    });

    (prisma.student.findMany as jest.Mock).mockResolvedValue([
      {
        id: 'stu-linked',
        name: 'Linked Student',
        user_id: 'user-1',
        created_at: '2026-04-01T00:00:00.000Z',
        student_batches: [{ id: 'sb1', batch_id: 'batch-a' }],
      },
      {
        id: 'stu-unlinked',
        name: 'Unlinked Student',
        user_id: null,
        created_at: '2026-04-02T00:00:00.000Z',
        student_batches: [
          { id: 'sb2', batch_id: 'batch-a' },
          { id: 'sb3', batch_id: 'batch-b' },
        ],
      },
    ]);

    const controller = new ContentController();
    const result = await (controller as any).resolveStudentProfile('inst-1', 'user-1');

    expect(result).toEqual({
      id: 'stu-linked',
      name: 'Linked Student',
      batch_ids: ['batch-a'],
    });
    expect(prisma.student.updateMany).not.toHaveBeenCalled();
  });

  it('links user_id for selected unlinked student candidate', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({
      phone: '9876543210',
    });

    (prisma.student.findMany as jest.Mock).mockResolvedValue([
      {
        id: 'stu-raw',
        name: 'Phone Match',
        user_id: null,
        created_at: '2026-04-03T00:00:00.000Z',
        student_batches: [{ id: 'sb4', batch_id: 'batch-z' }],
      },
    ]);

    const controller = new ContentController();
    const result = await (controller as any).resolveStudentProfile('inst-1', 'user-1');

    expect(prisma.student.updateMany).toHaveBeenCalledWith({
      where: { id: 'stu-raw', institute_id: 'inst-1', user_id: null },
      data: { user_id: 'user-1' },
    });
    expect(result).toEqual({
      id: 'stu-raw',
      name: 'Phone Match',
      batch_ids: ['batch-z'],
    });
  });

  it('queries linked profile first and guarded phone matches', async () => {
    (prisma.user.findUnique as jest.Mock).mockResolvedValue({ phone: '+919876543210' });
    (prisma.student.findMany as jest.Mock).mockResolvedValue([]);

    const controller = new ContentController();
    const result = await (controller as any).resolveStudentProfile('inst-1', 'user-1');

    expect(result).toBeNull();
    expect(prisma.student.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          institute_id: 'inst-1',
          OR: expect.any(Array),
        }),
      }),
    );

    const args = (prisma.student.findMany as jest.Mock).mock.calls[0][0];
    expect(args.where.OR).toEqual(expect.arrayContaining([{ user_id: 'user-1' }]));
    const phoneClause = args.where.OR.find(
      (item: any) => Array.isArray(item?.AND),
    );
    expect(phoneClause).toBeTruthy();
    expect(phoneClause.AND[1]).toEqual({ OR: [{ user_id: null }, { user_id: 'user-1' }] });
  });
});
