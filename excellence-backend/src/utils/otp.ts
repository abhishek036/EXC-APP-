import crypto from 'crypto';
import jwt from 'jsonwebtoken';

const ACCESS_TOKEN_FALLBACK = '30m';
const REFRESH_TOKEN_FALLBACK = '14d';
const ACCESS_MIN_MS = 15 * 60 * 1000;
const ACCESS_MAX_MS = 60 * 60 * 1000;
const REFRESH_MIN_MS = 7 * 24 * 60 * 60 * 1000;
const REFRESH_MAX_MS = 30 * 24 * 60 * 60 * 1000;

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
    if (configuredMs == null || configuredMs < ACCESS_MIN_MS || configuredMs > ACCESS_MAX_MS) {
        return ACCESS_TOKEN_FALLBACK;
    }

    return configured;
};

const normalizeRefreshExpiry = (rawValue?: string): string => {
    const configured = (rawValue || '').trim();
    if (!configured) return REFRESH_TOKEN_FALLBACK;

    const configuredMs = parseDurationToMs(configured);
    if (configuredMs == null || configuredMs < REFRESH_MIN_MS || configuredMs > REFRESH_MAX_MS) {
        return REFRESH_TOKEN_FALLBACK;
    }

    return configured;
};

export const generateOTP = (): string => {
  // Generate a random 6-digit OTP
  const otp = crypto.randomInt(100000, 999999).toString();
  return otp;
};

export const generateTokens = (payload: { userId: string, role: string, instituteId: string, phone: string }) => {
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret || jwtSecret.trim().length < 32) {
        throw new Error('JWT secret is missing or too short. Configure JWT_SECRET with at least 32 characters.');
    }

    const accessExpiresIn = normalizeAccessExpiry(process.env.JWT_EXPIRES_IN) as jwt.SignOptions['expiresIn'];
    const refreshExpiresIn = normalizeRefreshExpiry(process.env.JWT_REFRESH_EXPIRES_IN) as jwt.SignOptions['expiresIn'];

    const accessToken = jwt.sign(
        payload,
        jwtSecret,
        {
            algorithm: 'HS256',
            expiresIn: accessExpiresIn,
        }
    );

    const refreshToken = jwt.sign(
        { userId: payload.userId, version: 1 }, // version could track manual revocations
        jwtSecret,
        {
            algorithm: 'HS256',
            expiresIn: refreshExpiresIn,
        }
    );

    return { accessToken, refreshToken };
}
