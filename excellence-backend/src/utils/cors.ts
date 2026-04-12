export type CorsPolicy = {
  allowedOrigins: string[];
  hasWildcardOrigin: boolean;
  allowTrustedDevOrigins: boolean;
  supportsCredentials: boolean;
};

const normalizeOriginValue = (value: string): string => {
  const trimmed = String(value || '').trim();
  if (!trimmed || trimmed === '*') return trimmed;

  try {
    return new URL(trimmed).origin;
  } catch {
    return trimmed.replace(/\/+$/, '');
  }
};

const parseAllowedOrigins = (raw: string): string[] => {
  const normalized = raw
    .split(',')
    .map((origin) => normalizeOriginValue(origin))
    .filter(Boolean);

  return Array.from(new Set(normalized));
};

const isPrivateIpv4 = (hostname: string): boolean => {
  const match = hostname.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!match) return false;

  const octets = match.slice(1).map((part) => Number.parseInt(part, 10));
  if (octets.some((octet) => Number.isNaN(octet) || octet < 0 || octet > 255)) {
    return false;
  }

  const [a, b] = octets;
  if (a === 10) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  return false;
};

const isTrustedDevOrigin = (origin: string): boolean => {
  try {
    const parsed = new URL(origin);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return false;
    }

    const hostname = parsed.hostname.toLowerCase();
    if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1') {
      return true;
    }

    if (isPrivateIpv4(hostname)) {
      return true;
    }

    return hostname.endsWith('.local');
  } catch {
    return false;
  }
};

export const buildCorsPolicy = (
  nodeEnv: string | undefined = process.env.NODE_ENV,
  allowedOriginsRaw: string = process.env.ALLOWED_ORIGINS || '',
): CorsPolicy => {
  const allowedOrigins = parseAllowedOrigins(allowedOriginsRaw);
  const hasWildcardOrigin = allowedOrigins.includes('*');
  const isProduction = nodeEnv === 'production';
  const allowTrustedDevOrigins = !isProduction && allowedOrigins.length === 0;

  return {
    allowedOrigins,
    hasWildcardOrigin,
    allowTrustedDevOrigins,
    supportsCredentials: true,
  };
};

export const isOriginAllowed = (origin: string | undefined, policy: CorsPolicy): boolean => {
  if (!origin) return true;

  const normalizedOrigin = normalizeOriginValue(origin);
  if (!normalizedOrigin) return true;

  if (policy.hasWildcardOrigin) return true;
  if (policy.allowedOrigins.includes(normalizedOrigin)) return true;
  if (policy.allowTrustedDevOrigins && isTrustedDevOrigin(normalizedOrigin)) return true;

  return false;
};
