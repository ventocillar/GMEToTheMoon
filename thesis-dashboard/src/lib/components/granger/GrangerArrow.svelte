<script lang="ts">
	import { onMount } from 'svelte';
	import { VERONESE, COLORS } from '$lib/utils/colors';
	import { fmtPvalue } from '$lib/utils/formats';
	import type { GrangerRow } from '$lib/types';

	let { data }: { data: GrangerRow[] } = $props();

	let visible = $state(false);

	onMount(() => {
		setTimeout(() => { visible = true; }, 300);
	});

	let afinnToReturn = $derived(data.find(d => d.direction === 'AFINN -> Returns'));
	let returnToAfinn = $derived(data.find(d => d.direction === 'Returns -> AFINN'));
	let wsbToReturn = $derived(data.find(d => d.direction === 'WSB -> Returns'));
	let returnToWsb = $derived(data.find(d => d.direction === 'Returns -> WSB'));
</script>

<div class="mx-auto max-w-2xl space-y-8">
	<!-- Sentiment -> Returns (FAILED) -->
	<div
		class="rounded-xl border p-6 transition-all duration-700 {visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}"
		style="background: #12121a; border-color: {VERONESE[0]}40"
	>
		<div class="flex items-center gap-4">
			<div class="text-right flex-1">
				<p class="text-lg font-bold" style="color: {VERONESE[3]}">Sentiment</p>
				<p class="text-xs" style="color: {COLORS.textMuted}">AFINN & WSB</p>
			</div>

			<!-- Crossed out arrow -->
			<div class="relative flex items-center">
				<svg width="80" height="40" viewBox="0 0 80 40">
					<defs>
						<marker id="arrowhead-red" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
							<path d="M0,0 L8,3 L0,6" fill="{VERONESE[0]}" opacity="0.4" />
						</marker>
					</defs>
					<line x1="5" y1="20" x2="68" y2="20" stroke="{VERONESE[0]}" stroke-width="2" opacity="0.4"
						marker-end="url(#arrowhead-red)" />
					<!-- X mark -->
					<line x1="25" y1="8" x2="55" y2="32" stroke="{VERONESE[0]}" stroke-width="3" />
					<line x1="55" y1="8" x2="25" y2="32" stroke="{VERONESE[0]}" stroke-width="3" />
				</svg>
			</div>

			<div class="flex-1">
				<p class="text-lg font-bold" style="color: {VERONESE[6]}">Returns</p>
				<p class="text-xs" style="color: {COLORS.textMuted}">GME daily</p>
			</div>
		</div>

		<div class="mt-4 flex justify-center gap-6 text-xs">
			{#if afinnToReturn}
				<span style="color: {COLORS.textMuted}">
					AFINN: F = {afinnToReturn.f_statistic.toFixed(2)},
					<span style="color: {VERONESE[0]}">p = {fmtPvalue(afinnToReturn.p_value)}</span>
				</span>
			{/if}
			{#if wsbToReturn}
				<span style="color: {COLORS.textMuted}">
					WSB: F = {wsbToReturn.f_statistic.toFixed(2)},
					<span style="color: {VERONESE[0]}">p = {fmtPvalue(wsbToReturn.p_value)}</span>
				</span>
			{/if}
		</div>
	</div>

	<!-- Returns -> Sentiment (SIGNIFICANT) -->
	<div
		class="rounded-xl border p-6 transition-all duration-700 delay-300 {visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}"
		style="background: #12121a; border-color: {VERONESE[6]}40"
	>
		<div class="flex items-center gap-4">
			<div class="text-right flex-1">
				<p class="text-lg font-bold" style="color: {VERONESE[6]}">Returns</p>
				<p class="text-xs" style="color: {COLORS.textMuted}">GME daily</p>
			</div>

			<!-- Bold arrow -->
			<div class="relative flex items-center">
				<svg width="80" height="40" viewBox="0 0 80 40">
					<defs>
						<marker id="arrowhead-green" markerWidth="10" markerHeight="8" refX="10" refY="4" orient="auto">
							<path d="M0,0 L10,4 L0,8" fill="{VERONESE[6]}" />
						</marker>
					</defs>
					<line x1="5" y1="20" x2="62" y2="20" stroke="{VERONESE[6]}" stroke-width="3"
						marker-end="url(#arrowhead-green)" />
				</svg>
			</div>

			<div class="flex-1">
				<p class="text-lg font-bold" style="color: {VERONESE[3]}">Sentiment</p>
				<p class="text-xs" style="color: {COLORS.textMuted}">AFINN & WSB</p>
			</div>
		</div>

		<div class="mt-4 flex justify-center gap-6 text-xs">
			{#if returnToAfinn}
				<span style="color: {COLORS.textMuted}">
					AFINN: F = {returnToAfinn.f_statistic.toFixed(2)},
					<span style="color: {VERONESE[6]}">p {fmtPvalue(returnToAfinn.p_value)}</span>
				</span>
			{/if}
			{#if returnToWsb}
				<span style="color: {COLORS.textMuted}">
					WSB: F = {returnToWsb.f_statistic.toFixed(2)},
					<span style="color: {VERONESE[6]}">p {fmtPvalue(returnToWsb.p_value)}</span>
				</span>
			{/if}
		</div>
	</div>
</div>
