export function calculateTotal(amounts: string): number {
    if (amounts.trim() === "") {
        return 0;
    }
    
    const amountArray = amounts.split(/[\n,]+/).map(amt => amt.trim()).filter(amt => amt !== '');
    
    // Check if ALL values are valid numbers
    for (const amt of amountArray) {
        const num = parseFloat(amt);
        if (isNaN(num)) {
            return 0; // Return 0 immediately if any value is invalid
        }
    }
    
    // If all values are valid, sum them
    return amountArray
        .map(amt => parseFloat(amt))
        .reduce((sum, num) => sum + num, 0);
}