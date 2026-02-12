<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, EMOTION_COLORS, VERONESE } from '$lib/utils/colors';
	import { parseDate, fmtDate } from '$lib/utils/formats';
	import type { EmotionRow } from '$lib/types';

	let { data }: { data: EmotionRow[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const margin = { top: 20, right: 20, bottom: 40, left: 50 };
		const width = container.clientWidth;
		const height = 380;
		const innerW = width - margin.left - margin.right;
		const innerH = height - margin.top - margin.bottom;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const emotions = [...new Set(data.map(d => d.emotion))];
		const dates = [...new Set(data.map(d => d.date))].sort();

		// Pivot to wide format
		const wide = dates.map(date => {
			const row: Record<string, any> = { date: parseDate(date) };
			for (const em of emotions) {
				const match = data.find(d => d.date === date && d.emotion === em);
				row[em] = match?.normalized ?? 0;
			}
			return row;
		});

		const stack = d3.stack<Record<string, any>>()
			.keys(emotions)
			.order(d3.stackOrderNone)
			.offset(d3.stackOffsetWiggle);

		const series = stack(wide);

		const x = d3.scaleTime()
			.domain(d3.extent(wide, d => d.date) as [Date, Date])
			.range([0, innerW]);

		const y = d3.scaleLinear()
			.domain([
				d3.min(series, s => d3.min(s, d => d[0])) ?? 0,
				d3.max(series, s => d3.max(s, d => d[1])) ?? 1
			])
			.range([innerH, 0]);

		const area = d3.area<d3.SeriesPoint<Record<string, any>>>()
			.x(d => x(d.data.date))
			.y0(d => y(d[0]))
			.y1(d => y(d[1]))
			.curve(d3.curveBasis);

		// Draw areas
		g.selectAll('.emotion-area')
			.data(series)
			.join('path')
			.attr('d', area)
			.attr('fill', (_, i) => EMOTION_COLORS[emotions[i]] || VERONESE[i % 10])
			.attr('opacity', 0.7);

		// Event line
		const eventX = x(new Date('2021-01-28'));
		g.append('line')
			.attr('x1', eventX).attr('x2', eventX)
			.attr('y1', 0).attr('y2', innerH)
			.attr('stroke', '#fff').attr('stroke-dasharray', '4,3').attr('stroke-opacity', 0.5);

		// X axis
		g.append('g')
			.attr('transform', `translate(0,${innerH})`)
			.call(d3.axisBottom(x).ticks(8).tickFormat(d3.timeFormat('%b %d') as any))
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
	<div class="mb-3 flex flex-wrap gap-3 text-xs">
		{#each Object.entries(EMOTION_COLORS) as [emotion, color]}
			<span class="flex items-center gap-1">
				<span class="inline-block h-2.5 w-4 rounded-sm" style="background: {color}; opacity: 0.7"></span>
				{emotion}
			</span>
		{/each}
	</div>
	<div bind:this={container} class="w-full" style="height: 380px"></div>
</div>
