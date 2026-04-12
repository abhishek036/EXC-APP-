import ExcelJS, { CellValue } from 'exceljs';
import { parse as parseCsv } from 'csv-parse/sync';

type ParsedRow = Record<string, unknown>;

const normalizeCellValue = (value: CellValue): unknown => {
    if (value == null) return null;
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        return value;
    }
    if (value instanceof Date) {
        return value.toISOString();
    }
    if (Array.isArray(value)) {
        return value
            .map((part) => (typeof part === 'object' && part && 'text' in part ? String(part.text) : String(part)))
            .join('');
    }
    if (typeof value === 'object') {
        if ('text' in value && value.text != null) {
            return String(value.text);
        }
        if ('result' in value) {
            return value.result ?? null;
        }
        if ('hyperlink' in value && value.hyperlink) {
            return String(value.hyperlink);
        }
        return JSON.stringify(value);
    }
    return String(value);
};

const parseXlsx = async (buffer: Buffer): Promise<ParsedRow[]> => {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer as unknown as any);
    const worksheet = workbook.worksheets[0];

    if (!worksheet) return [];

    const headerCells = worksheet.getRow(1).values as CellValue[];
    const headers = headerCells
        .slice(1)
        .map((header, index) => {
            const normalized = normalizeCellValue(header);
            const key = typeof normalized === 'string' ? normalized.trim() : String(normalized ?? '').trim();
            return key || `column_${index + 1}`;
        });

    const rows: ParsedRow[] = [];
    worksheet.eachRow((row, rowNumber) => {
        if (rowNumber === 1) return;

        const parsed: ParsedRow = {};
        let hasData = false;

        headers.forEach((header, index) => {
            const value = normalizeCellValue(row.getCell(index + 1).value);
            parsed[header] = value;
            if (value !== null && value !== '') {
                hasData = true;
            }
        });

        if (hasData) {
            rows.push(parsed);
        }
    });

    return rows;
};

const parseCsvBuffer = (buffer: Buffer): ParsedRow[] => {
    const text = buffer.toString('utf8');
    return parseCsv(text, {
        columns: true,
        skip_empty_lines: true,
        trim: true,
    }) as ParsedRow[];
};

export const parseExcel = async (buffer: Buffer): Promise<ParsedRow[]> => {
    try {
        return await parseXlsx(buffer);
    } catch {
        try {
            return parseCsvBuffer(buffer);
        } catch {
            throw new Error('Unable to parse file. Only .xlsx and .csv are supported.');
        }
    }
};
