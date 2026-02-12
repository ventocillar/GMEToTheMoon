import { writable } from 'svelte/store';
import type {
	TimelineRow, SummaryStatRow, GrangerRow, RegressionData,
	DidData, IrfRow, EmotionRow, EmojiTopRow, WordContribRow,
	BootstrapCIRow, RobustnessData
} from '$lib/types';

export const timeline = writable<TimelineRow[]>([]);
export const summaryStats = writable<SummaryStatRow[]>([]);
export const granger = writable<GrangerRow[]>([]);
export const regressionData = writable<RegressionData | null>(null);
export const didData = writable<DidData | null>(null);
export const irfData = writable<IrfRow[]>([]);
export const emotions = writable<EmotionRow[]>([]);
export const emojiTop = writable<EmojiTopRow[]>([]);
export const wordContributions = writable<WordContribRow[]>([]);
export const bootstrapCI = writable<BootstrapCIRow[]>([]);
export const robustnessData = writable<RobustnessData | null>(null);
export const dataLoaded = writable(false);

async function loadJSON<T>(path: string): Promise<T> {
	const res = await fetch(path);
	return res.json();
}

export async function loadAllData() {
	const [
		timelineRaw, summaryRaw, grangerRaw, regRaw,
		didRaw, irfRaw, emotionsRaw, emojiRaw,
		wordRaw, bootstrapRaw, robustnessRaw
	] = await Promise.all([
		loadJSON<TimelineRow[]>('/data/timeline.json'),
		loadJSON<SummaryStatRow[]>('/data/summary_stats.json'),
		loadJSON<GrangerRow[]>('/data/granger.json'),
		loadJSON<RegressionData>('/data/regression_coefs.json'),
		loadJSON<DidData>('/data/did_results.json'),
		loadJSON<IrfRow[]>('/data/irf.json'),
		loadJSON<EmotionRow[]>('/data/emotions.json'),
		loadJSON<EmojiTopRow[]>('/data/emoji_top.json'),
		loadJSON<WordContribRow[]>('/data/word_contributions.json'),
		loadJSON<BootstrapCIRow[]>('/data/bootstrap_ci.json'),
		loadJSON<RobustnessData>('/data/robustness.json')
	]);

	timeline.set(timelineRaw);
	summaryStats.set(summaryRaw);
	granger.set(grangerRaw);
	regressionData.set(regRaw);
	didData.set(didRaw);
	irfData.set(irfRaw);
	emotions.set(emotionsRaw);
	emojiTop.set(emojiRaw);
	wordContributions.set(wordRaw);
	bootstrapCI.set(bootstrapRaw);
	robustnessData.set(robustnessRaw);
	dataLoaded.set(true);
}
