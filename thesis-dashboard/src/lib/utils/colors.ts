// MetBrewer Veronese palette (10 colors)
export const VERONESE = [
	'#67322E', // 0: dark burgundy — negative / bearish
	'#885116', // 1: brown — secondary negative
	'#A7700E', // 2: amber — caution
	'#C38F16', // 3: gold — accent / highlight
	'#8A9264', // 4: olive — transition
	'#58867F', // 5: teal — neutral-positive
	'#2C6B67', // 6: dark teal — positive
	'#1E5B53', // 7: deep teal — meme stocks
	'#154647', // 8: dark cyan — controls
	'#122C43'  // 9: navy — background accent
] as const;

export const COLORS = {
	// Semantic
	negative: VERONESE[0],
	bearish: VERONESE[0],
	caution: VERONESE[2],
	gold: VERONESE[3],
	highlight: VERONESE[3],
	neutral: VERONESE[5],
	positive: VERONESE[6],
	meme: VERONESE[7],
	control: VERONESE[8],
	navy: VERONESE[9],

	// UI
	bg: '#0a0a0f',
	card: '#12121a',
	border: '#1e1e2e',
	borderLight: '#2a2a3e',
	text: '#e4e4e7',
	textMuted: '#a1a1aa',
	textDim: '#71717a',

	// Chart
	grid: '#1e1e2e',
	axis: '#3f3f50',
	tooltipBg: '#1a1a28',

	// Emotions (NRC)
	anger: '#E74C3C',
	anticipation: '#F39C12',
	disgust: '#8E44AD',
	fear: '#2C3E50',
	joy: '#F1C40F',
	sadness: '#3498DB',
	surprise: '#E67E22',
	trust: '#27AE60'
} as const;

export const EMOTION_COLORS: Record<string, string> = {
	anger: COLORS.anger,
	anticipation: COLORS.anticipation,
	disgust: COLORS.disgust,
	fear: COLORS.fear,
	joy: COLORS.joy,
	sadness: COLORS.sadness,
	surprise: COLORS.surprise,
	trust: COLORS.trust
};
