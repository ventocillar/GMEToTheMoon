<script lang="ts">
	import { COLORS, VERONESE } from '$lib/utils/colors';

	let openCard = $state<string | null>(null);

	function toggle(id: string) {
		openCard = openCard === id ? null : id;
	}

	const cards = [
		{
			id: 'data',
			title: 'Data Collection',
			icon: '📊',
			summary: '14.37M Reddit comments from r/WallStreetBets',
			detail: 'Comments scraped via Arctic Shift API for Dec 2020 - Mar 2021. 4.6 GB SQLite database containing comment text, scores, authors, and timestamps. Processing was chunked by month to fit within 16 GB RAM constraints.'
		},
		{
			id: 'lexicons',
			title: 'Sentiment Lexicons',
			icon: '📖',
			summary: '6 lexicons including 2 custom WSB/emoji lexicons',
			detail: 'Standard: NRC (10 emotions), BING (binary), AFINN (-5 to +5), Loughran-McDonald (financial). Custom: WSB slang lexicon (58 terms, e.g. "tendies" = +2, "paperhands" = -2) and emoji lexicon (30 emojis, e.g. 🚀 = +3, 🐻 = -2). Context-inverted terms like "retard" and "autist" coded as positive per WSB community norms.'
		},
		{
			id: 'models',
			title: 'Statistical Models',
			icon: '📐',
			summary: 'OLS, VAR/Granger, Difference-in-Differences',
			detail: 'OLS with Newey-West HAC standard errors (5 lags) for autocorrelation. Bivariate VAR models with ADF-confirmed stationarity and AIC-selected lag order. Granger causality tests in both directions. Two-way fixed effects DiD (stock + date FE) with clustered standard errors at the stock level.'
		},
		{
			id: 'robustness',
			title: 'Robustness Checks',
			icon: '🔍',
			summary: '6 sensitivity analyses confirm main findings',
			detail: 'Alternative lexicons (BING, NRC, combined). Score-weighted vs. unweighted sentiment. High-engagement subsample (score > 10). Placebo DiD with Dec 15, 2020 fake event (p = 0.59, not significant — good). 1,000-rep bootstrap confidence intervals. 200-comment manual validation sample.'
		}
	];
</script>

<div class="mx-auto max-w-3xl space-y-3">
	{#each cards as card}
		<button
			onclick={() => toggle(card.id)}
			class="w-full text-left rounded-lg border transition-all"
			style="background: {COLORS.card}; border-color: {openCard === card.id ? VERONESE[3] + '60' : COLORS.border}"
		>
			<div class="flex items-center gap-4 p-5">
				<span class="text-2xl">{card.icon}</span>
				<div class="flex-1">
					<h4 class="font-semibold" style="color: {COLORS.text}">{card.title}</h4>
					<p class="text-sm" style="color: {COLORS.textMuted}">{card.summary}</p>
				</div>
				<span
					class="text-lg transition-transform duration-200"
					style="color: {COLORS.textDim}; transform: rotate({openCard === card.id ? '180deg' : '0deg'})"
				>
					▾
				</span>
			</div>

			{#if openCard === card.id}
				<div class="border-t px-5 pb-5 pt-4" style="border-color: {COLORS.border}">
					<p class="text-sm leading-relaxed" style="color: {COLORS.textMuted}">
						{card.detail}
					</p>
				</div>
			{/if}
		</button>
	{/each}

	<!-- Pipeline diagram -->
	<div class="mt-8 rounded-lg border p-6" style="background: {COLORS.card}; border-color: {COLORS.border}">
		<h4 class="mb-4 text-sm font-semibold" style="color: {COLORS.text}">Data Pipeline</h4>
		<div class="flex flex-wrap items-center justify-center gap-2 text-xs">
			{#each ['Reddit API', 'SQLite DB', 'Tokenize', 'Sentiment', 'Merge', 'Regression', 'Granger', 'DiD', 'Robustness'] as step, i}
				{#if i > 0}
					<span style="color: {COLORS.textDim}">→</span>
				{/if}
				<span
					class="rounded-md px-3 py-1.5"
					style="background: {VERONESE[i % 10]}20; color: {VERONESE[i % 10]}; border: 1px solid {VERONESE[i % 10]}40"
				>
					{step}
				</span>
			{/each}
		</div>
	</div>
</div>
