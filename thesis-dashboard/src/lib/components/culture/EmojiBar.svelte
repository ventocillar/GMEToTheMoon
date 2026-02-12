<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import { fmtComma } from '$lib/utils/formats';
	import type { EmojiTopRow } from '$lib/types';

	let { data }: { data: EmojiTopRow[] } = $props();

	let container: HTMLDivElement;

	function sentimentColor(val: number | null): string {
		if (val == null) return COLORS.textMuted;
		if (val >= 2) return VERONESE[6];
		if (val >= 1) return VERONESE[5];
		if (val === 0) return VERONESE[4];
		if (val >= -1) return VERONESE[2];
		return VERONESE[0];
	}

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const margin = { top: 10, right: 30, bottom: 30, left: 50 };
		const barHeight = 28;
		const gap = 4;
		const height = data.length * (barHeight + gap) + margin.top + margin.bottom;
		const width = container.clientWidth;
		const innerW = width - margin.left - margin.right;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const sorted = [...data].sort((a, b) => b.count - a.count);

		const x = d3.scaleLinear()
			.domain([0, (d3.max(sorted, d => d.count) ?? 1) * 1.1])
			.range([0, innerW]);

		// Bars
		sorted.forEach((d, i) => {
			const y = i * (barHeight + gap);
			const color = sentimentColor(d.sentiment_value);

			g.append('rect')
				.attr('x', 0).attr('y', y)
				.attr('width', x(d.count))
				.attr('height', barHeight)
				.attr('fill', color)
				.attr('opacity', 0.7)
				.attr('rx', 4);

			// Emoji label
			g.append('text')
				.attr('x', -8).attr('y', y + barHeight / 2)
				.attr('dy', '0.35em').attr('text-anchor', 'end')
				.style('font-size', '18px')
				.text(d.emoji);

			// Count label
			g.append('text')
				.attr('x', x(d.count) + 6).attr('y', y + barHeight / 2)
				.attr('dy', '0.35em')
				.attr('fill', COLORS.textMuted).style('font-size', '11px')
				.text(fmtComma(d.count));
		});

		// X axis
		g.append('g')
			.attr('transform', `translate(0,${sorted.length * (barHeight + gap)})`)
			.call(d3.axisBottom(x).ticks(5).tickFormat(d3.format('.2s') as any))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		g.selectAll('.domain').attr('stroke', COLORS.axis);
		g.selectAll('.tick line').attr('stroke', COLORS.axis);
	}

	onMount(() => {
		draw();
		const ro = new ResizeObserver(() => draw());
		ro.observe(container);
		return () => ro.disconnect();
	});

	$effect(() => {
		if (data) draw();
	});
</script>

<div>
	<div bind:this={container} class="w-full"></div>
</div>
