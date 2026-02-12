<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import type { IrfRow } from '$lib/types';

	let {
		data,
		title = '',
		color = VERONESE[6]
	}: {
		data: IrfRow[];
		title?: string;
		color?: string;
	} = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const margin = { top: 20, right: 20, bottom: 40, left: 50 };
		const width = container.clientWidth;
		const height = 280;
		const innerW = width - margin.left - margin.right;
		const innerH = height - margin.top - margin.bottom;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const sorted = [...data].sort((a, b) => a.horizon - b.horizon);

		const x = d3.scaleLinear()
			.domain([0, d3.max(sorted, d => d.horizon) ?? 10])
			.range([0, innerW]);

		const allY = sorted.flatMap(d => [d.lower, d.upper, d.response]);
		const y = d3.scaleLinear()
			.domain(d3.extent(allY) as [number, number])
			.nice()
			.range([innerH, 0]);

		// Zero line
		g.append('line')
			.attr('x1', 0).attr('x2', innerW)
			.attr('y1', y(0)).attr('y2', y(0))
			.attr('stroke', COLORS.textMuted)
			.attr('stroke-dasharray', '4,3');

		// CI band
		const area = d3.area<IrfRow>()
			.x(d => x(d.horizon))
			.y0(d => y(d.lower))
			.y1(d => y(d.upper))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(sorted)
			.attr('d', area)
			.attr('fill', color)
			.attr('opacity', 0.15);

		// Response line
		const line = d3.line<IrfRow>()
			.x(d => x(d.horizon))
			.y(d => y(d.response))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(sorted)
			.attr('d', line)
			.attr('fill', 'none')
			.attr('stroke', color)
			.attr('stroke-width', 2);

		// Points
		g.selectAll('.point')
			.data(sorted)
			.join('circle')
			.attr('cx', d => x(d.horizon))
			.attr('cy', d => y(d.response))
			.attr('r', 3)
			.attr('fill', color);

		// Axes
		g.append('g')
			.attr('transform', `translate(0,${innerH})`)
			.call(d3.axisBottom(x).ticks(10).tickFormat(d3.format('d') as any))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		g.append('g')
			.call(d3.axisLeft(y).ticks(5))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		g.append('text')
			.attr('x', innerW / 2).attr('y', innerH + 35)
			.attr('text-anchor', 'middle')
			.attr('fill', COLORS.textMuted).style('font-size', '11px')
			.text('Horizon (trading days)');

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
	{#if title}
		<h4 class="mb-2 text-sm font-medium" style="color: {COLORS.text}">{title}</h4>
	{/if}
	<div bind:this={container} class="w-full" style="height: 280px"></div>
	<p class="mt-1 text-[10px]" style="color: {COLORS.textDim}">
		Shaded area = 95% bootstrap CI ({data[0]?.impulse} shock)
	</p>
</div>
