import { ChatRepository } from './chat.repository';

export class ChatService {
  static async getHistory(batchId: string, instituteId: string, limit: number = 50, before?: string) {
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
    return ChatRepository.sendMessage(data);
  }

  static async deleteMessage(id: string, instituteId: string) {
    return ChatRepository.deleteMessage(id, instituteId);
  }

  static async getRooms(userId: string, role: string, instituteId: string) {
    if (role === 'student') {
      return ChatRepository.getRoomsForStudent(userId, instituteId);
    } else if (role === 'teacher') {
      return ChatRepository.getRoomsForTeacher(userId, instituteId);
    } else {
      return ChatRepository.getRoomsForAdmin(instituteId);
    }
  }
}
