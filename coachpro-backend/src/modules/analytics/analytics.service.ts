import { AnalyticsRepository } from './analytics.repository';

export class AnalyticsService {
  static async getDashboard(instituteId: string) {
    return AnalyticsRepository.getDashboardStats(instituteId);
  }

  static async getStudentPerformance(studentId: string, instituteId: string) {
    return AnalyticsRepository.getStudentPerformance(studentId, instituteId);
  }
}
