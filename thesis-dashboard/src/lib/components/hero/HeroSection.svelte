<script lang="ts">
	import { onMount } from 'svelte';
	import { VERONESE } from '$lib/utils/colors';

	let price = $state(16);
	let phase = $state(0); // 0=rising, 1=peak, 2=crash
	let mounted = $state(false);

	const phases = [
		{ target: 483, label: 'Jan 28 Peak', duration: 3000 },
		{ target: 483, label: 'Robinhood Restricts', duration: 1500 },
		{ target: 40, label: 'Mar 31 Close', duration: 2000 }
	];

	onMount(() => {
		mounted = true;
		animatePrice();
	});

	function animatePrice() {
		const steps = [
			{ from: 16, to: 483, ms: 3000 },
			{ from: 483, to: 40, ms: 2000, delay: 1500 }
		];

		let start = performance.now();
		const step1End = 3000;
		const pauseEnd = step1End + 1500;
		const step2End = pauseEnd + 2000;

		function tick(now: number) {
			const elapsed = now - start;

			if (elapsed < step1End) {
				const t = elapsed / step1End;
				const eased = 1 - Math.pow(1 - t, 3);
				price = Math.round(16 + (483 - 16) * eased);
				phase = 0;
			} else if (elapsed < pauseEnd) {
				price = 483;
				phase = 1;
			} else if (elapsed < step2End) {
				const t = (elapsed - pauseEnd) / 2000;
				const eased = t * t;
				price = Math.round(483 + (40 - 483) * eased);
				phase = 2;
			} else {
				price = 40;
				phase = 2;
				// Restart after a pause
				setTimeout(() => {
					price = 16;
					phase = 0;
					start = performance.now();
					requestAnimationFrame(tick);
				}, 3000);
				return;
			}
			requestAnimationFrame(tick);
		}

		requestAnimationFrame(tick);
	}
</script>

<div class="relative flex min-h-screen flex-col items-center justify-center px-4 text-center">
	<!-- Background gradient -->
	<div class="pointer-events-none absolute inset-0 overflow-hidden">
		<div
			class="absolute top-1/4 left-1/2 -translate-x-1/2 w-[800px] h-[800px] rounded-full opacity-[0.07]"
			style="background: radial-gradient(circle, {VERONESE[3]} 0%, transparent 70%)"
		></div>
	</div>

	<div class="relative z-10 max-w-3xl">
		<p class="mb-4 text-sm tracking-[0.3em] uppercase" style="color: {VERONESE[3]}">
			Interactive Research Dashboard
		</p>

		<h1 class="text-5xl font-bold tracking-tight md:text-7xl">
			<span style="color: {VERONESE[3]}">GME</span>ToThe<span style="color: {VERONESE[6]}">Moon</span>
		</h1>

		<p class="mx-auto mt-6 max-w-xl text-lg" style="color: #a1a1aa">
			Does WallStreetBets sentiment drive meme stock returns?
			A quantitative analysis of 14.37 million Reddit comments.
		</p>

		<!-- Animated price ticker -->
		<div class="mt-12 flex items-baseline justify-center gap-3">
			<span class="text-sm uppercase tracking-widest" style="color: #71717a">GME</span>
			<span
				class="stat-number text-6xl font-bold transition-colors duration-300 md:text-8xl"
				style="color: {phase === 0 ? VERONESE[6] : phase === 1 ? VERONESE[3] : VERONESE[0]}"
			>
				${price}
			</span>
		</div>

		<p class="mt-3 text-xs" style="color: #71717a">
			{#if phase === 0}
				Dec 2020 — Jan 28, 2021
			{:else if phase === 1}
				Robinhood restricts trading
			{:else}
				Post-restriction decline
			{/if}
		</p>

		<!-- Key finding teaser -->
		<div
			class="mx-auto mt-16 max-w-md rounded-lg border p-4 text-left"
			style="background: #12121a; border-color: #1e1e2e"
		>
			<p class="text-xs font-semibold uppercase tracking-wider" style="color: {VERONESE[3]}">
				Key Finding
			</p>
			<p class="mt-1 text-sm" style="color: #e4e4e7">
				Sentiment does <strong>not</strong> Granger-cause returns. Instead,
				returns drive sentiment — retail traders <em>reacted</em> to price moves rather
				than driving them.
			</p>
		</div>

		<!-- Scroll indicator -->
		<div class="mt-20 animate-bounce">
			<svg class="mx-auto h-6 w-6" style="color: #71717a" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
			</svg>
		</div>
	</div>
</div>
