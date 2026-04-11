import { Response } from 'express';

interface SuccessResponse<T> {
  res: Response;
  data: T;
  message?: string;
  statusCode?: number;
  meta?: {
    page: number;
    perPage: number;
    total: number;
    totalPages: number;
  };
}

const TEACHER_ROLE = 'teacher';
const DIRECT_REDACT_KEYS = new Set([
  'student_phone',
  'parent_phone',
  'guardian_phone',
  'father_phone',
  'mother_phone',
]);

const STUDENT_PARENT_CONTEXT_HINTS = [
  'student',
  'students',
  'parent',
  'parents',
  'guardian',
  'child',
  'children',
];

const shouldRedactPhoneInContext = (parentKey?: string): boolean => {
  const key = (parentKey ?? '').toLowerCase();
  if (!key) return false;
  return STUDENT_PARENT_CONTEXT_HINTS.some((hint) => key.includes(hint));
};

const redactTeacherSensitiveContacts = (
  payload: unknown,
  parentKey?: string,
): unknown => {
  if (Array.isArray(payload)) {
    return payload.map((item) => redactTeacherSensitiveContacts(item, parentKey));
  }

  if (!payload || typeof payload !== 'object') {
    return payload;
  }

  const source = payload as Record<string, unknown>;
  const target: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(source)) {
    const lowerKey = key.toLowerCase();
    if (DIRECT_REDACT_KEYS.has(lowerKey)) continue;

    if (lowerKey === 'phone' && shouldRedactPhoneInContext(parentKey)) {
      continue;
    }

    target[key] = redactTeacherSensitiveContacts(value, key);
  }

  return target;
};

export const sendResponse = <T>({
  res,
  data,
  message = 'Success',
  statusCode = 200,
  meta,
}: SuccessResponse<T>) => {
  const requesterRole = (res.req?.user?.role ?? '').toString().trim().toLowerCase();
  const sanitizedData = requesterRole === TEACHER_ROLE
    ? (redactTeacherSensitiveContacts(data) as T)
    : data;

  return res.status(statusCode).json({
    success: true,
    data: sanitizedData,
    message,
    ...(meta && { meta }),
  });
};
