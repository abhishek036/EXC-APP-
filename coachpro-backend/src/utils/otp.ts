import crypto from 'crypto';
import jwt from 'jsonwebtoken';

export const generateOTP = (): string => {
  // Generate a random 6-digit OTP
  const otp = crypto.randomInt(100000, 999999).toString();
  return otp;
};

export const generateTokens = (payload: { userId: string, role: string, instituteId: string, phone: string }) => {
    const accessExpiresIn = (process.env.JWT_EXPIRES_IN || '8h') as jwt.SignOptions['expiresIn'];
    const refreshExpiresIn = (process.env.JWT_REFRESH_EXPIRES_IN || '30d') as jwt.SignOptions['expiresIn'];

    const accessToken = jwt.sign(
        payload,
        process.env.JWT_SECRET as string,
        { expiresIn: accessExpiresIn }
    );

    const refreshToken = jwt.sign(
        { userId: payload.userId, version: 1 }, // version could track manual revocations
        process.env.JWT_SECRET as string,
        { expiresIn: refreshExpiresIn }
    );

    return { accessToken, refreshToken };
}
