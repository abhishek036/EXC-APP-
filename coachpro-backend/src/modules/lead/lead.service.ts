import { LeadRepository } from './lead.repository';
import { CreateLeadInput } from './lead.validator';

export class LeadService {
  private repo: LeadRepository;

  constructor() {
    this.repo = new LeadRepository();
  }

  async list(instituteId: string) {
    return this.repo.list(instituteId);
  }

  async create(instituteId: string, data: CreateLeadInput) {
    return this.repo.create(instituteId, data);
  }

  async updateStatus(instituteId: string, id: string, status: string) {
    return this.repo.updateStatus(instituteId, id, status);
  }
}
