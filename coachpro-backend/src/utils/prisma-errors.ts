export function isLegacyColumnError(error: unknown, columnName?: string): boolean {
    const errorStr = String(error);
    const isValidationError = errorStr.includes('PrismaClientValidationError') || 
                             (error as any)?.constructor?.name === 'PrismaClientValidationError';

    if (isValidationError && !columnName) return true;
    
    if (columnName) {
        const lowColumnName = columnName.toLowerCase();
        const code = (error as any)?.code;
        const meta = (error as any)?.meta;
        const message = (error as any)?.message || '';
        
        const inMessage = message.toLowerCase().includes(lowColumnName) || errorStr.toLowerCase().includes(lowColumnName);
        const inMeta = String(meta?.column ?? '').toLowerCase().includes(lowColumnName) || 
                       String(meta?.target ?? '').toLowerCase().includes(lowColumnName);
        
        return inMessage || inMeta || (isValidationError && errorStr.toLowerCase().includes(lowColumnName));
    }

    const code = (error as any)?.code;
    // P2022: Column not found
    // P2021: Table not found
    return code === 'P2022' || code === 'P2021' || isValidationError;
}
