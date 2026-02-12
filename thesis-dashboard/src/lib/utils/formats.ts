import * as d3 from 'd3';

export const fmtDate = d3.timeFormat('%b %d');
export const fmtDateFull = d3.timeFormat('%b %d, %Y');
export const fmtComma = d3.format(',');
export const fmtPct = d3.format('.1%');
export const fmtPct2 = d3.format('.2%');
export const fmtSi = d3.format('.2s');
export const fmtDec2 = d3.format('.2f');
export const fmtDec4 = d3.format('.4f');

export function fmtPvalue(p: number): string {
	if (p < 0.001) return '< 0.001';
	if (p < 0.01) return p.toFixed(3);
	return p.toFixed(2);
}

export function sigStars(p: number): string {
	if (p < 0.001) return '***';
	if (p < 0.01) return '**';
	if (p < 0.05) return '*';
	return '';
}

export function fmtLargeNumber(n: number): string {
	if (Math.abs(n) >= 1e9) return (n / 1e9).toFixed(1) + 'B';
	if (Math.abs(n) >= 1e6) return (n / 1e6).toFixed(1) + 'M';
	if (Math.abs(n) >= 1e3) return (n / 1e3).toFixed(1) + 'K';
	return String(Math.round(n));
}

export function parseDate(s: string): Date {
	return new Date(s + 'T00:00:00');
}
