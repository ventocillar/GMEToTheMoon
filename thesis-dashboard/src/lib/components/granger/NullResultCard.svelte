<script lang="ts">
	import { VERONESE, COLORS } from '$lib/utils/colors';
</script>

<div class="mx-auto max-w-2xl text-center">
	<p class="text-sm uppercase tracking-[0.25em] font-semibold" style="color: {VERONESE[3]}">
		The Key Finding
	</p>
	<h2 class="mt-4 text-3xl font-bold md:text-5xl" style="color: {COLORS.text}">
		Sentiment did <span style="color: {VERONESE[0]}">NOT</span> cause returns
	</h2>
	<p class="mx-auto mt-6 max-w-lg text-base leading-relaxed" style="color: {COLORS.textMuted}">
		Granger causality tests reveal that returns drive sentiment, but not the other way
		around. Retail traders on r/WallStreetBets <strong style="color: {COLORS.text}">reacted</strong> to
		price moves rather than causing them.
	</p>
</div>
