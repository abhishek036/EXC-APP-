import axios from 'axios';

/**
 * Renflair WhatsApp OTP Service
 * ─────────────────────────────
 * Uses whatsapp.renflair.in API to send OTP messages
 * via WhatsApp.
 *
 * API: GET https://whatsapp.renflair.in/V1.php?API=<key>&PHONE=<phone>&OTP=<otp>
 * Response: JSON { status, message }
 */
export class RenflairOtpService {
  private static get apiKey(): string {
    return process.env.RENFLAIR_API_KEY || '';
  }

  private static get countryCode(): string {
    return process.env.RENFLAIR_COUNTRY_CODE || '91';
  }

  /**
   * Normalize phone to 10-digit Indian format (strip +91 prefix).
   */
  private static normalizePhone(phone: string): string {
    let cleaned = phone.replace(/[\s\-()]/g, '');
    if (cleaned.startsWith('+91')) cleaned = cleaned.substring(3);
    if (cleaned.startsWith('91') && cleaned.length === 12) cleaned = cleaned.substring(2);
    return cleaned;
  }

  /**
   * Send OTP via WhatsApp using the Renflair API.
   * Returns true if sent, false if failed.
   */
  static async sendOTP(phone: string, otp: string): Promise<boolean> {
    const apiKey = this.apiKey;
    if (!apiKey || apiKey === 'YOUR_RENFLAIR_API_KEY_HERE') {
      console.warn('[RENFLAIR] API key not configured. OTP not sent. Set RENFLAIR_API_KEY in .env');
      return false;
    }

    const cleanPhone = this.normalizePhone(phone);
    if (cleanPhone.length !== 10) {
      console.error(`[RENFLAIR] Invalid phone number after normalization: "${cleanPhone}" (from "${phone}")`);
      return false;
    }

    const url = `https://whatsapp.renflair.in/V1.php`;

    try {
      console.log(`[RENFLAIR] Sending OTP ${otp} to ${cleanPhone}...`);

      const response = await axios.get(url, {
        params: {
          API: apiKey,
          PHONE: cleanPhone,
          OTP: otp,
          COUNTRY: this.countryCode,
        },
        timeout: 15000, // 15s timeout
      });

      const data = response.data;
      console.log(`[RENFLAIR] Response:`, JSON.stringify(data));

      // Renflair typically returns { status: true/false, message: "..." }
      // Treat HTTP 200 with status=false as delivery failure.
      const statusValue = String(data?.status ?? '').toLowerCase();
      if (
        data?.status === true ||
        data?.status === 'true' ||
        data?.status === 1 ||
        data?.status === '1' ||
        statusValue === 'success'
      ) {
        console.log(`[RENFLAIR] ✅ OTP sent successfully to ${cleanPhone}`);
        return true;
      }

      console.warn(`[RENFLAIR] ⚠️ API returned unexpected status:`, data);
      return false;

    } catch (error: any) {
      console.error(`[RENFLAIR] ❌ Failed to send OTP:`, error.response?.data || error.message);
      return false;
    }
  }
}
