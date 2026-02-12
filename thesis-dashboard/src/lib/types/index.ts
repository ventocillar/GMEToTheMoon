export interface TimelineRow {
	date: string;
	gme_return: number;
	gme_close: number;
	gme_volume: number;
	gme_abnormal_volume: number;
	afinn_score: number;
	wsb_score: number;
	nrc_net: number;
	bing_net: number;
	emoji_score: number;
	n_comments: number;
	n_authors: number;
}

export interface SummaryStatRow {
	variable: string;
	N: number;
	Mean: number;
	SD: number;
	Min: number;
	Q1: number;
	Median: number;
	Q3: number;
	Max: number;
}

export interface GrangerRow {
	direction: string;
	f_statistic: number;
	p_value: number;
	significant: boolean;
}

export interface RegressionCoef {
	variable: string;
	estimate: number;
	std_error: number;
	t_stat: number;
	p_value: number;
	ci_lower: number;
	ci_upper: number;
	model: string;
}

export interface EmojiF {
	f_statistic: number;
	p_value: number;
	df1: number;
	df2: number;
}

export interface RegressionData {
	coefficients: RegressionCoef[];
	emoji_f_test: EmojiF;
}

export interface EventStudyCoef {
	period: number;
	estimate: number;
	'std.error': number;
	'conf.low': number;
	'conf.high': number;
	'p.value': number;
	pre_treatment: boolean;
}

export interface DidCoef {
	model: string;
	coefficient: number;
	p_value: number;
}

export interface CumulativeReturn {
	group: string;
	date: string;
	mean_return: number;
	cumulative_return: number;
}

export interface DidData {
	event_study: EventStudyCoef[];
	did_coefs: DidCoef[];
	cumulative_returns: CumulativeReturn[];
}

export interface IrfRow {
	horizon: number;
	response: number;
	lower: number;
	upper: number;
	impulse: string;
	response_var: string;
}

export interface EmotionRow {
	date: string;
	emotion: string;
	normalized: number;
}

export interface EmojiTopRow {
	emoji: string;
	count: number;
	sentiment_value: number | null;
	description: string | null;
}

export interface WordContribRow {
	word: string;
	sentiment: string;
	count: number;
}

export interface BootstrapCIRow {
	coefficient: string;
	ci_lower: number;
	ci_upper: number;
	mean_est: number;
}

export interface RobustnessCoef {
	variable: string;
	estimate: number;
	std_error: number;
	p_value: number;
	model: string;
}

export interface PlaceboResult {
	coefficient: number;
	p_value: number;
}

export interface RobustnessData {
	coefficients: RobustnessCoef[];
	placebo: PlaceboResult;
}
