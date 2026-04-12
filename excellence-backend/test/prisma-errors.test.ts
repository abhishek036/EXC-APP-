import { isLegacyColumnError } from '../src/utils/prisma-errors';

describe('Prisma Legacy Error Detection', () => {
    test('detects PrismaClientValidationError for missing columns', () => {
        const error = new Error('Unknown arg `subject` in where.subject');
        error.name = 'PrismaClientValidationError';
        expect(isLegacyColumnError(error)).toBe(true);
        expect(isLegacyColumnError(error, 'subject')).toBe(true);
        expect(isLegacyColumnError(error, 'other')).toBe(false);
    });

    test('detects P2022 (Column Not Found) errors', () => {
        const error = {
            code: 'P2022',
            meta: { column: 'Table.subject' }
        };
        expect(isLegacyColumnError(error)).toBe(true);
        expect(isLegacyColumnError(error, 'subject')).toBe(true);
    });

    test('ignores unrelated Prisma errors', () => {
        const error = { code: 'P2002' }; // Unique constraint
        expect(isLegacyColumnError(error)).toBe(false);
    });

    test('ignores general network errors', () => {
        const error = new Error('Database connection failed');
        expect(isLegacyColumnError(error)).toBe(false);
    });
});
