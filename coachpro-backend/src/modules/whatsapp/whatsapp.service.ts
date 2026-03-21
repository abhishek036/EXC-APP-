import axios from 'axios';
import dotenv from 'dotenv';
dotenv.config();

export class WhatsAppService {
  private static get baseUrl() {
    return `https://graph.facebook.com/v18.0/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`;
  }
  
  private static get headers() {
    return {
      'Authorization': `Bearer ${process.env.WHATSAPP_ACCESS_TOKEN}`,
      'Content-Type': 'application/json'
    };
  }

  private static async sendMessage(to: string, templateName: string, languageCode: string = 'en', components: any[] = []) {
    if (!process.env.WHATSAPP_PHONE_NUMBER_ID || !process.env.WHATSAPP_ACCESS_TOKEN) {
      console.warn('WhatsApp API not configured, skipping message to', to);
      return;
    }

    try {
      const payload = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to,
        type: "template",
        template: {
          name: templateName,
          language: { code: languageCode },
          components: components
        }
      };

      await axios.post(this.baseUrl, payload, { headers: this.headers });
    } catch (error: any) {
      console.error('WhatsApp API Error:', error.response?.data || error.message);
    }
  }

  static async sendOTP(phone: string, otp: string): Promise<void> {
    // POC: Using hello_world until otp_verification template is approved
    await this.sendMessage(phone, 'hello_world', 'en_US', []);
  }

  static async sendFeeReminder(phone: string, parentName: string, studentName: string, amount: number, dueDate: string, paymentLink: string, institutePhone: string): Promise<void> {
    await this.sendMessage(phone, 'fee_reminder', 'en', [
      {
        type: 'body',
        parameters: [
          { type: 'text', text: parentName },
          { type: 'text', text: amount.toString() },
          { type: 'text', text: studentName },
          { type: 'text', text: dueDate },
          { type: 'text', text: paymentLink },
          { type: 'text', text: institutePhone }
        ]
      }
    ]);
  }

  static async sendAbsentAlert(phone: string, studentName: string, date: string, batchName: string, teacherName: string, instituteName: string): Promise<void> {
    await this.sendMessage(phone, 'absent_alert', 'en', [
      {
        type: 'body',
        parameters: [
          { type: 'text', text: studentName },
          { type: 'text', text: date },
          { type: 'text', text: batchName },
          { type: 'text', text: teacherName },
          { type: 'text', text: instituteName }
        ]
      }
    ]);
  }

  static async sendResultNotification(phone: string, studentName: string, marks: string, total: string, examName: string, grade: string, rank: string, instituteName: string): Promise<void> {
    await this.sendMessage(phone, 'result_published', 'en', [
      {
        type: 'body',
        parameters: [
          { type: 'text', text: studentName },
          { type: 'text', text: marks },
          { type: 'text', text: total },
          { type: 'text', text: examName },
          { type: 'text', text: grade },
          { type: 'text', text: rank },
          { type: 'text', text: instituteName }
        ]
      }
    ]);
  }

  static async sendBulkAnnouncement(phoneList: string[], message: string): Promise<void> {
    for (const phone of phoneList) {
      await this.sendMessage(phone, 'announcement', 'en', [
         {
           type: 'body',
           parameters: [
              { type: 'text', text: message }
           ]
         }
      ]);
    }
  }
}
