import crypto from 'crypto';
import jwt from 'jsonwebtoken';

const ACCESS_TOKEN_FALLBACK = '8h';

const parseDurationToMs = (value: string): number | null => {
    const input = (value || '').trim();
    const match = input.match(/^(\d+)([smhd])$/i);
    if (!match) return null;

    const amount = Number(match[1]);
    const unit = match[2].toLowerCase();
    if (!Number.isFinite(amount) || amount <= 0) return null;

    const unitMs: Record<string, number> = {
        s: 1000,
        m: 60 * 1000,
        h: 60 * 60 * 1000,
        d: 24 * 60 * 60 * 1000,
    };

    return amount * unitMs[unit];
};

const normalizeAccessExpiry = (rawValue?: string): string => {
    const configured = (rawValue || '').trim();
    if (!configured) return ACCESS_TOKEN_FALLBACK;

    const configuredMs = parseDurationToMs(configured);
    const fallbackMs = parseDurationToMs(ACCESS_TOKEN_FALLBACK) ?? 8 * 60 * 60 * 1000;

    if (configuredMs == null || configuredMs < 60 * 60 * 1000) {
        return ACCESS_TOKEN_FALLBACK;
    }

    if (configuredMs < fallbackMs) {
        return ACCESS_TOKEN_FALLBACK;
    }

    return configured;
};

export const generateOTP = (): string => {
  // Generate a random 6-digit OTP
  const otp = crypto.randomInt(100000, 999999).toString();
  return otp;
};

export const generateTokens = (payload: { userId: string, role: string, instituteId: string, phone: string }) => {
    const accessExpiresIn = normalizeAccessExpiry(process.env.JWT_EXPIRES_IN) as jwt.SignOptions['expiresIn'];
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
