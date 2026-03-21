import { StudentRepository } from './student.repository';
import { CreateStudentInput, UpdateStudentInput } from './student.validator';
import { ApiError } from '../../middleware/error.middleware';

export class StudentService {
  private studentRepository: StudentRepository;

  constructor() {
    this.studentRepository = new StudentRepository();
  }

  async listStudents(instituteId: string, query: { name?: string, phone?: string, batchId?: string, isActive?: boolean, page?: number, perPage?: number }) {
    const page = parseInt(query.page as any) || 1;
    const perPage = parseInt(query.perPage as any) || 20;
    const skip = (page - 1) * perPage;

    const { students, total } = await this.studentRepository.listStudents(
        instituteId, 
        { name: query.name, phone: query.phone, batchId: query.batchId, isActive: query.isActive }, 
        { skip, take: perPage }
    );
    
    return {
      data: students.map(s => ({
        ...s,
        active_batches_count: s._count.student_batches,
        attendancePercent: 0 // In a real app, calculate this or join from record counts
      })),
      meta: {
        page,
        perPage,
        total,
        totalPages: Math.ceil(total / perPage)
      }
    };
  }

  async getStudentDetails(studentId: string, instituteId: string) {
    const student = await this.studentRepository.findStudentById(studentId, instituteId);
    if (!student) {
        throw new ApiError('Student not found', 404, 'NOT_FOUND');
    }
    
    // Format output
    const s = student as any;
    return {
       ...s,
       batches: s.student_batches?.map((sb: any) => sb.batch) || []
    }
  }

  async createStudent(instituteId: string, data: CreateStudentInput) {
    // 1. Check if student already exists in this institute with this phone
    if (data.phone) {
        const existing = await this.studentRepository.findStudentByPhone(data.phone, instituteId);
        if (existing) {
            throw new ApiError('Student with this phone number already exists in this institute', 400, 'DUPLICATE_PHONE');
        }
    }

    // 2. Check batch capacity if batch_ids are provided
    if (data.batch_ids && data.batch_ids.length > 0) {
        const { prisma } = require('../../server');
        for (const batchId of data.batch_ids) {
            const batch = await prisma.batch.findUnique({
                where: { id: batchId },
                include: { _count: { select: { student_batches: true } } }
            });
            if (batch && batch.capacity && batch._count.student_batches >= batch.capacity) {
                throw new ApiError(`Batch "${batch.name}" is already full (Capacity: ${batch.capacity})`, 400, 'BATCH_FULL');
            }
        }
    }

    // 3. Create student
    const createdStudent = await this.studentRepository.createStudentWithUserAndParent(instituteId, data);

    // 4. Update Lead status if lead_id is provided
    if (data.lead_id) {
        const { prisma } = await import('../../server');
        await prisma.lead.update({
            where: { id: data.lead_id, institute_id: instituteId },
            data: { status: 'Converted' }
        }).catch(err => console.error('Failed to update lead status:', err));
    }

    return createdStudent;
  }

  async updateStudent(studentId: string, instituteId: string, data: UpdateStudentInput) {
    const student = await this.studentRepository.findStudentById(studentId, instituteId);
    if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

    return this.studentRepository.updateStudent(studentId, instituteId, data);
  }

  async changeStatus(studentId: string, instituteId: string, isActive: boolean) {
    const student = await this.studentRepository.findStudentById(studentId, instituteId);
    if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

    return this.studentRepository.toggleStatus(studentId, isActive);
  }

  async importExcel(instituteId: string, fileBuffer: Buffer, batchId?: string) {
    const { parseExcel } = await import('../../utils/excel');
    const data = parseExcel(fileBuffer);
    
    let processed = 0;
    let errors: string[] = [];

    for (const row of data as any[]) {
      try {
        const studentData: CreateStudentInput = {
          name: row.name || row.Name || row.student_name,
          phone: row.phone?.toString() || row.Phone?.toString() || row.phone_number?.toString(),
          gender: row.gender || row.Gender,
          batch_ids: batchId ? [batchId] : (row.batch_id ? [row.batch_id] : [])
        };

        if (row.parent_name || row.ParentName) {
            studentData.parent_name = row.parent_name || row.ParentName;
            studentData.parent_phone = row.parent_phone?.toString() || row.ParentPhone?.toString();
        }

        if (studentData.name && studentData.phone) {
            await this.createStudent(instituteId, studentData);
            processed++;
        }
      } catch (err: any) {
        errors.push(`Row ${processed + errors.length + 1}: ${err.message}`);
      }
    }

    return { 
      message: `Successfully imported ${processed} students`, 
      errors: errors.length > 0 ? errors : undefined 
    };
  }
}
