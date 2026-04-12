import { prisma } from '../../server';
import { buildPhoneVariants } from '../../utils/phone';

export class AuthRepository {
    private _phoneVariants(phone: string) {
        return buildPhoneVariants(phone);
    }

  async findUserByPhone(phone: string) {
        const phonesToSearch = this._phoneVariants(phone);

    return prisma.user.findFirst({
        where: { phone: { in: phonesToSearch }, is_active: true },
        include: { institute: true }
    });
  }

  async saveOtp(phone: string, otp: string, purpose: string, expiresAt: Date) {
        const phonesToSearch = this._phoneVariants(phone);
      // Invalidate existing OTPs for this phone + purpose
      await prisma.otpCode.updateMany({
            where: { phone: { in: phonesToSearch }, purpose, used_at: null, expires_at: { gt: new Date() } },
         data: { used_at: new Date() } // Mark unused as "used" to invalidate
      });

      return prisma.otpCode.create({
          data: {
              phone,
              code: otp,
              purpose,
              expires_at: expiresAt
          }
      });
  }

  async verifyOtp(phone: string, otp: string, purpose: string) {
      const phonesToSearch = this._phoneVariants(phone);
      const validOtp = await prisma.otpCode.findFirst({
          where: {
              phone: { in: phonesToSearch },
              code: otp.trim(),
              purpose,
              used_at: null,
              expires_at: {
                  gt: new Date()
              }
          },
          orderBy: { created_at: 'desc' },
      });

      if (validOtp) {
          // Mark as used
          await prisma.otpCode.update({
              where: { id: validOtp.id },
              data: { used_at: new Date() }
          });
      }

      return validOtp;
  }

  async storeRefreshToken(userId: string, tokenHash: string, expiresAt: Date) {
      // CLEAR ALL PREVIOUS SESSIONS FOR THIS USER
      // (This enforces single device login as requested by the user)
      await prisma.refreshToken.deleteMany({
          where: { user_id: userId }
      });

      return prisma.refreshToken.create({
          data: {
              user_id: userId,
              token_hash: tokenHash,
              expires_at: expiresAt
          }
      });
  }

  async revokeRefreshToken(tokenHash: string) {
      return prisma.refreshToken.deleteMany({
          where: { token_hash: tokenHash }
      });
  }
  
  async findRefreshToken(tokenHash: string) {
      return prisma.refreshToken.findFirst({
         where: { 
            token_hash: tokenHash,
            revoked_at: null,
            expires_at: { gt: new Date() }
         },
         include: { user: true }
      });
  }
}
