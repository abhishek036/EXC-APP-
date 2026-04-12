export const ATTENDANCE_PRESENT_STATUSES = new Set(['present', 'late']);

export const FEE_PENDING_STATUSES = new Set([
  'pending',
  'partial',
  'unpaid',
  'pending_verification',
  'rejected',
  'overdue',
]);

export const toSafeNumber = (value: unknown): number => {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (value && typeof value === 'object' && 'toString' in (value as Record<string, unknown>)) {
    const parsed = Number((value as { toString: () => string }).toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
};

export const normalizeStatus = (value: unknown): string =>
  String(value ?? '').trim().toLowerCase();

export const summarizeAttendanceFromStatuses = (statuses: unknown[]) => {
  let present = 0;
  let absent = 0;
  let late = 0;
  let leave = 0;

  for (const rawStatus of statuses) {
    const status = normalizeStatus(rawStatus);
    if (status === 'present') present += 1;
    else if (status === 'late') late += 1;
    else if (status === 'absent') absent += 1;
    else if (status === 'leave') leave += 1;
  }

  const total = statuses.length;
  const effectivePresent = present + late;
  const percentage = total > 0 ? Math.round((effectivePresent / total) * 100) : 0;

  return {
    total,
    present: effectivePresent,
    present_only: present,
    late,
    absent,
    leave,
    percentage,
  };
};

export const calculateFeeAmounts = (
  finalAmountInput: unknown,
  paidAmountInput: unknown,
  statusInput: unknown,
) => {
  const final_amount = toSafeNumber(finalAmountInput);
  const paid_amount = toSafeNumber(paidAmountInput);
  const remaining_amount = Math.max(final_amount - paid_amount, 0);
  const status = normalizeStatus(statusInput);

  const statusLooksPending = status.length === 0 || FEE_PENDING_STATUSES.has(status) || status !== 'paid';
  const is_pending = remaining_amount > 0 && statusLooksPending;

  return {
    final_amount,
    paid_amount,
    remaining_amount,
    status,
    is_pending,
  };
};
