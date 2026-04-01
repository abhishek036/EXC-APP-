import { ChatRepository } from './chat.repository';
import { ApiError } from '../../middleware/error.middleware';

export class ChatService {
  static async getHistory(batchId: string, instituteId: string, userId: string, role: string, limit: number = 50, before?: string) {
    const canAccess = await ChatRepository.canAccessBatch(userId, role, instituteId, batchId);
    if (!canAccess) {
      throw new ApiError('You do not have access to this chat room', 403, 'FORBIDDEN');
    }
    return ChatRepository.getHistory(batchId, instituteId, limit, before);
  }

  static async sendMessage(data: {
    batchId: string;
    instituteId: string;
    senderId: string;
    senderName: string;
    senderRole: string;
    message?: string;
    imageUrl?: string;
  }) {
    const canAccess = await ChatRepository.canAccessBatch(data.senderId, data.senderRole, data.instituteId, data.batchId);
    if (!canAccess) {
      throw new ApiError('You do not have access to this chat room', 403, 'FORBIDDEN');
    }
    return ChatRepository.sendMessage(data);
  }

  static async deleteMessage(id: string, instituteId: string) {
    return ChatRepository.deleteMessage(id, instituteId);
  }

  static async getRooms(userId: string, role: string, instituteId: string) {
    const normalizedRole = (role || '').toLowerCase();
    if (normalizedRole === 'student') {
      return ChatRepository.getRoomsForStudent(userId, instituteId);
    } else if (normalizedRole === 'teacher') {
      return ChatRepository.getRoomsForTeacher(userId, instituteId);
    } else if (normalizedRole === 'parent') {
      return ChatRepository.getRoomsForParent(userId, instituteId);
    } else {
      return ChatRepository.getRoomsForAdmin(instituteId);
    }
  }
}
