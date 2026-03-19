import { InstituteRepository } from './institute.repository';
import { UpdateInstituteInput } from './institute.validator';
import { ApiError } from '../../middleware/error.middleware';

export class InstituteService {
  private repo: InstituteRepository;

  constructor() {
    this.repo = new InstituteRepository();
  }

  async getProfile(instituteId: string) {
    const record = await this.repo.getInstituteById(instituteId);
    if (!record) throw new ApiError('Institute configuration not found', 404, 'NOT_FOUND');
    return record;
  }

  async updateProfile(instituteId: string, data: UpdateInstituteInput) {
    return this.repo.updateInstitute(instituteId, data);
  }
}
