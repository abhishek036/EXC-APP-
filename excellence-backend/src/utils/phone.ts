export const INDIA_COUNTRY_CODE = '+91';

const stripNonDigits = (value: string): string => value.replace(/\D/g, '');

const normalizeIndianLocal = (phone: string): string | null => {
  const digits = stripNonDigits(phone || '');
  if (!digits) return null;

  if (digits.length === 10) return digits;
  if (digits.length === 11 && digits.startsWith('0')) return digits.slice(1);
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);

  // Gracefully support values like 0091XXXXXXXXXX or longer inputs with prefixes.
  if (digits.length > 10) {
    const lastTen = digits.slice(-10);
    if (/^\d{10}$/.test(lastTen)) return lastTen;
  }

  return null;
};

export const normalizeIndianPhone = (phone?: string | null): string | null => {
  if (typeof phone !== 'string') return null;
  const trimmed = phone.trim();
  if (!trimmed) return null;

  const local = normalizeIndianLocal(trimmed);
  if (!local) return null;

  return `${INDIA_COUNTRY_CODE}${local}`;
};

export const buildPhoneVariants = (phone?: string | null): string[] => {
  const variants = new Set<string>();
  if (typeof phone === 'string' && phone.trim()) {
    variants.add(phone.trim());
  }

  const normalized = normalizeIndianPhone(phone);
  if (!normalized) return Array.from(variants);

  const local = normalized.slice(3);
  variants.add(normalized);
  variants.add(local);
  variants.add(`91${local}`);

  return Array.from(variants);
};
