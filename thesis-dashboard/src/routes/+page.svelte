<script lang="ts">
	import {
		dataLoaded, timeline, granger, regressionData, didData,
		irfData, emotions, emojiTop, wordContributions, bootstrapCI,
		robustnessData
	} from '$lib/stores/data.svelte';
	import { VERONESE, COLORS } from '$lib/utils/colors';
	import { fmtPvalue, sigStars, fmtLargeNumber, fmtPct } from '$lib/utils/formats';
	import Section from '$lib/components/layout/Section.svelte';
	import Nav from '$lib/components/layout/Nav.svelte';
	import HeroSection from '$lib/components/hero/HeroSection.svelte';
	import TimelineChart from '$lib/components/timeline/TimelineChart.svelte';
	import GrangerArrow from '$lib/components/granger/GrangerArrow.svelte';
	import NullResultCard from '$lib/components/granger/NullResultCard.svelte';
	import CoefficientPlot from '$lib/components/regression/CoefficientPlot.svelte';
	import EventStudyChart from '$lib/components/did/EventStudyChart.svelte';
	import CumulativeReturns from '$lib/components/did/CumulativeReturns.svelte';
	import IrfChart from '$lib/components/irf/IrfChart.svelte';
	import EmotionRadar from '$lib/components/emotions/EmotionRadar.svelte';
	import EmotionStream from '$lib/components/emotions/EmotionStream.svelte';
	import EmojiBar from '$lib/components/culture/EmojiBar.svelte';
	import WordCloud from '$lib/components/culture/WordCloud.svelte';
	import BootstrapCI from '$lib/components/robustness/BootstrapCI.svelte';
	import LexiconGrid from '$lib/components/robustness/LexiconGrid.svelte';
	import MethodologyCards from '$lib/components/methodology/MethodologyCards.svelte';

	let loaded = $derived($dataLoaded);
	let tl = $derived($timeline);
	let gr = $derived($granger);
	let reg = $derived($regressionData);
	let did = $derived($didData);
	let irf = $derived($irfData);
	let emo = $derived($emotions);
	let emj = $derived($emojiTop);
	let wc = $derived($wordContributions);
	let bci = $derived($bootstrapCI);
	let rob = $derived($robustnessData);

	let activeSection = $state('hero');

	function onSectionVisible(id: string) {
		activeSection = id;
	}

	// IRF derived subsets
	let irfSentToReturn = $derived(irf.filter(d => d.response_var === 'GME Return'));
	let irfRetToSent = $derived(irf.filter(d => d.response_var !== 'GME Return'));
	let irfAfinnToRet = $derived(irfSentToReturn.filter(d => d.impulse === 'AFINN Sentiment'));
	let irfWsbToRet = $derived(irfSentToReturn.filter(d => d.impulse === 'WSB Sentiment'));
	let irfRetToAfinn = $derived(irfRetToSent.filter(d => d.impulse === 'GME Return' && d.response_var === 'AFINN Sentiment'));
	let irfRetToWsb = $derived(irfRetToSent.filter(d => d.impulse === 'GME Return' && d.response_var === 'WSB Sentiment'));
</script>

<Nav {activeSection} />

<!-- Section 1: Hero -->
<Section id="hero" label="Intro" onVisible={onSectionVisible}>
	<HeroSection />
</Section>

{#if !loaded}
	<div class="flex min-h-[50vh] items-center justify-center">
		<div class="text-center">
			<div class="mx-auto h-8 w-8 animate-spin rounded-full border-2 border-t-transparent" style="border-color: {VERONESE[3]}; border-top-color: transparent"></div>
			<p class="mt-4 text-sm" style="color: {COLORS.textMuted}">Loading data...</p>
		</div>
	</div>
{:else}
	<!-- Section 2: Timeline -->
	<Section id="timeline" label="Timeline" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				The Story
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Price & Sentiment Over Time</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				GME closing price overlaid with daily AFINN sentiment from r/WallStreetBets.
				Notice how sentiment spikes <em>follow</em> rather than precede price movements.
			</p>
			<TimelineChart data={tl} />
		</div>
	</Section>

	<!-- Section 3: The Null Result -->
	<Section id="null-result" label="Causality" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<NullResultCard />
			<div class="mt-12">
				<GrangerArrow data={gr} />
			</div>
		</div>
	</Section>

	<!-- Section 4: Regression -->
	<Section id="regression" label="Regression" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Predictive Power
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Regression Coefficients</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				OLS with Newey-West HAC standard errors. Lagged sentiment variables do not
				significantly predict next-day returns — confidence intervals cross zero.
			</p>

			{#if reg}
				<CoefficientPlot
					data={reg.coefficients}
					models={['AFINN Full', 'WSB Full', 'Combined']}
					height={450}
				/>

				<!-- Emoji F-test callout -->
				<div class="mt-6 rounded-lg border p-4" style="background: {COLORS.card}; border-color: {COLORS.border}">
					<div class="flex items-baseline gap-3">
						<span class="text-sm font-semibold" style="color: {VERONESE[3]}">Emoji F-test</span>
						<span class="stat-number text-lg font-bold" style="color: {VERONESE[6]}">
							p = {fmtPvalue(reg.emoji_f_test.p_value)}
						</span>
					</div>
					<p class="mt-1 text-xs" style="color: {COLORS.textMuted}">
						Adding emoji sentiment to text-only models significantly improves fit
						(F = {reg.emoji_f_test.f_statistic.toFixed(2)}, df = {reg.emoji_f_test.df1}).
					</p>
				</div>
			{/if}
		</div>
	</Section>

	<!-- Section 5: Difference-in-Differences -->
	<Section id="did" label="DiD" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Causal Impact
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Robinhood Restriction Effect</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				Difference-in-Differences comparing meme stocks (GME, AMC, BB, NOK, BBBY)
				against retail control stocks (WMT, TGT, KR, DG) around Jan 28, 2021.
			</p>

			{#if did}
				<!-- DiD stat cards -->
				<div class="mb-8 grid grid-cols-1 gap-4 md:grid-cols-3">
					{#each did.did_coefs as coef}
						<div class="rounded-lg border p-4" style="background: {COLORS.card}; border-color: {COLORS.border}">
							<p class="text-xs uppercase tracking-wider" style="color: {COLORS.textMuted}">{coef.model}</p>
							<p class="stat-number mt-1 text-2xl font-bold" style="color: {coef.p_value < 0.05 ? VERONESE[0] : COLORS.textMuted}">
								{coef.coefficient.toFixed(4)}{sigStars(coef.p_value)}
							</p>
							<p class="text-xs" style="color: {COLORS.textDim}">p = {fmtPvalue(coef.p_value)}</p>
						</div>
					{/each}
				</div>

				<div class="grid gap-8 lg:grid-cols-2">
					<div>
						<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Event Study Coefficients</h3>
						<EventStudyChart data={did.event_study} />
					</div>
					<div>
						<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Cumulative Returns</h3>
						<CumulativeReturns data={did.cumulative_returns} />
					</div>
				</div>

				<div class="mt-6 rounded-lg border p-4" style="background: {COLORS.card}; border-color: {COLORS.border}">
					<p class="text-sm" style="color: {COLORS.textMuted}">
						The Robinhood trading restriction caused meme stocks to <strong style="color: {VERONESE[0]}">underperform</strong> control stocks
						by approximately 2.8 percentage points per day (two-way FE). Pre-treatment
						coefficients near zero support the parallel trends assumption.
					</p>
				</div>
			{/if}
		</div>
	</Section>

	<!-- Section 6: Impulse Response Functions -->
	<Section id="irf" label="IRF" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Dynamic Effects
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Impulse Response Functions</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				How do shocks propagate? Sentiment shocks produce no return response (flat line),
				while return shocks trigger significant sentiment reactions.
			</p>

			<div class="grid gap-8 md:grid-cols-2">
				<IrfChart data={irfAfinnToRet} title="AFINN Sentiment → Returns" color={VERONESE[3]} />
				<IrfChart data={irfWsbToRet} title="WSB Sentiment → Returns" color={VERONESE[2]} />
				<IrfChart data={irfRetToAfinn} title="Returns → AFINN Sentiment" color={VERONESE[6]} />
				<IrfChart data={irfRetToWsb} title="Returns → WSB Sentiment" color={VERONESE[7]} />
			</div>
		</div>
	</Section>

	<!-- Section 7: Emotional Landscape -->
	<Section id="emotions" label="Emotions" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Beyond Positive & Negative
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Emotional Landscape</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				NRC emotion analysis reveals 8 dimensions of sentiment.
				Fear and anticipation spike dramatically around key events.
			</p>

			<div class="grid gap-8 lg:grid-cols-2">
				<div>
					<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Average Emotion Profile</h3>
					<EmotionRadar data={emo} />
				</div>
				<div>
					<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Emotions Over Time</h3>
					<EmotionStream data={emo} />
				</div>
			</div>
		</div>
	</Section>

	<!-- Section 8: WSB Culture -->
	<Section id="culture" label="Culture" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Community Language
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">WSB Culture & Sentiment</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				r/WallStreetBets has its own linguistic ecosystem. Rocket emojis, diamond hands,
				and context-inverted slang require custom lexicons to capture sentiment accurately.
			</p>

			<div class="grid gap-8 lg:grid-cols-2">
				<div>
					<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Top 20 Emojis</h3>
					<EmojiBar data={emj} />
				</div>
				<div>
					<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Word Contributions to Sentiment</h3>
					<WordCloud data={wc} />
				</div>
			</div>

			{#if reg}
				<div class="mt-8 rounded-lg border p-5 text-center" style="background: {COLORS.card}; border-color: {VERONESE[3]}40">
					<p class="text-xs uppercase tracking-widest" style="color: {COLORS.textMuted}">Emoji Predictive Value</p>
					<p class="stat-number mt-2 text-4xl font-bold" style="color: {VERONESE[6]}">
						p = {fmtPvalue(reg.emoji_f_test.p_value)}
					</p>
					<p class="mt-2 text-sm" style="color: {COLORS.textMuted}">
						Emoji sentiment adds significant explanatory power beyond text-only models
					</p>
				</div>
			{/if}
		</div>
	</Section>

	<!-- Section 9: Robustness -->
	<Section id="robustness" label="Robustness" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Sensitivity Analysis
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Robustness Checks</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				Six sensitivity analyses confirm the main findings. The null result persists
				across lexicons, subsamples, and estimation strategies.
			</p>

			<div class="space-y-8">
				<div>
					<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Bootstrap 95% Confidence Intervals</h3>
					<BootstrapCI data={bci} />
				</div>

				{#if rob}
					<div>
						<h3 class="mb-3 text-sm font-semibold" style="color: {COLORS.text}">Cross-Lexicon Comparison</h3>
						<LexiconGrid data={rob.coefficients} />
					</div>

					<!-- Placebo test -->
					<div class="rounded-lg border p-5" style="background: {COLORS.card}; border-color: {COLORS.border}">
						<div class="flex items-baseline gap-4">
							<span class="text-sm font-semibold" style="color: {COLORS.text}">Placebo Test (Dec 15, 2020)</span>
							<span class="stat-number text-lg font-bold" style="color: {VERONESE[6]}">
								p = {fmtPvalue(rob.placebo.p_value)}
							</span>
						</div>
						<p class="mt-2 text-xs" style="color: {COLORS.textMuted}">
							Running DiD with a fake event date produces no significant effect
							(coefficient = {rob.placebo.coefficient.toFixed(4)}), supporting the
							causal interpretation of the Jan 28 results.
						</p>
					</div>
				{/if}
			</div>
		</div>
	</Section>

	<!-- Section 10: Methodology -->
	<Section id="methodology" label="Methods" onVisible={onSectionVisible}>
		<div class="mx-auto max-w-6xl px-4">
			<div class="mb-2 text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
				Under the Hood
			</div>
			<h2 class="mb-2 text-2xl font-bold md:text-3xl">Methodology</h2>
			<p class="mb-8 max-w-2xl text-sm" style="color: {COLORS.textMuted}">
				A comprehensive empirical framework combining text mining, time series econometrics,
				and causal inference.
			</p>
			<MethodologyCards />
		</div>
	</Section>

	<!-- Footer -->
	<footer class="border-t py-12 text-center" style="border-color: {COLORS.border}">
		<p class="text-xs" style="color: {COLORS.textDim}">
			GMEToTheMoon — WSB Sentiment & GameStop Returns Analysis
		</p>
		<p class="mt-1 text-xs" style="color: {COLORS.textDim}">
			14.37M comments | 82 trading days | 6 lexicons | Dec 2020 – Mar 2021
		</p>
	</footer>
{/if}
