export const normalizeIdList = (values: unknown[]): string[] => {
  return Array.from(
    new Set(
      values
        .map((value) => String(value ?? '').trim())
        .filter((value) => value.length > 0),
    ),
  );
};

export const resolveBatchTeacherIds = (
  meta: Record<string, unknown> | undefined,
  fallbackTeacherId?: string | null,
): string[] => {
  if (meta && Object.prototype.hasOwnProperty.call(meta, 'teacher_ids')) {
    const rawTeacherIds = Array.isArray(meta.teacher_ids) ? meta.teacher_ids : [];
    return normalizeIdList(rawTeacherIds);
  }

  return normalizeIdList([fallbackTeacherId]);
};

export const batchHasTeacher = (
  meta: Record<string, unknown> | undefined,
  fallbackTeacherId: string | null | undefined,
  teacherIdentifiers: Array<string | null | undefined>,
): boolean => {
  const assignedTeacherIds = resolveBatchTeacherIds(meta, fallbackTeacherId);
  if (assignedTeacherIds.length === 0) return false;

  const normalizedTeacherIds = normalizeIdList(teacherIdentifiers);
  if (normalizedTeacherIds.length === 0) return false;

  return assignedTeacherIds.some((teacherId) => normalizedTeacherIds.includes(teacherId));
};