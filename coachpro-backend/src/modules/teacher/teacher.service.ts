import { TeacherRepository } from './teacher.repository';
import { CreateTeacherInput, UpdateTeacherInput } from './teacher.validator';
import { ApiError } from '../../middleware/error.middleware';

export class TeacherService {
  private teacherRepository: TeacherRepository;

  constructor() {
    this.teacherRepository = new TeacherRepository();
  }

  async listTeachers(instituteId: string, query: { name?: string, phone?: string, page?: number, perPage?: number }) {
    const page = parseInt(query.page as any) || 1;
    const perPage = parseInt(query.perPage as any) || 20;
    const skip = (page - 1) * perPage;

    const { teachers, total } = await this.teacherRepository.listTeachers(instituteId, { name: query.name, phone: query.phone }, { skip, take: perPage });
    
    return {
      data: teachers.map(t => ({
        ...t,
        batches_count: t._count.batches
      })),
      meta: {
        page,
        perPage,
        total,
        totalPages: Math.ceil(total / perPage)
      }
    };
  }

  async getTeacherDetails(teacherId: string, instituteId: string) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) {
        throw new ApiError('Teacher not found', 404, 'NOT_FOUND');
    }
    return teacher;
  }

  async createTeacher(instituteId: string, data: CreateTeacherInput) {
    const createdTeacher = await this.teacherRepository.createTeacherWithUser(instituteId, data);
    return createdTeacher;
  }

  async updateTeacher(teacherId: string, instituteId: string, data: UpdateTeacherInput) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    return this.teacherRepository.updateTeacher(teacherId, instituteId, data);
  }

  async changeStatus(teacherId: string, instituteId: string, isActive: boolean) {
    const teacher = await this.teacherRepository.findTeacherById(teacherId, instituteId);
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    return this.teacherRepository.toggleStatus(teacherId, isActive);
  }
}
