export function isLegacyColumnError(error: unknown, columnName?: string): boolean {
    const errorStr = String(error);
    const isValidationError = errorStr.includes('PrismaClientValidationError') || 
                             (error as any)?.constructor?.name === 'PrismaClientValidationError';
    if (isValidationError) return true;

    const code = (error as any)?.code;
    const meta = (error as any)?.meta;
    const message = (error as any)?.message || '';
    
    // P2022: Column not found
    // P2021: Table not found
    if (code === 'P2022' || code === 'P2021') return true;
    
    if (columnName) {
        const column = String(meta?.column ?? '').toLowerCase();
        const target = String(meta?.target ?? '').toLowerCase();
        const lowColumnName = columnName.toLowerCase();
        
        return column.includes(lowColumnName) || 
               target.includes(lowColumnName) || 
               message.toLowerCase().includes(lowColumnName);
    }

    return false;
}
