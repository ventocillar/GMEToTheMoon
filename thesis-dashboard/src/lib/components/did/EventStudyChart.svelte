<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import type { EventStudyCoef } from '$lib/types';

	let { data }: { data: EventStudyCoef[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const margin = { top: 20, right: 20, bottom: 40, left: 60 };
		const width = container.clientWidth;
		const height = 400;
		const innerW = width - margin.left - margin.right;
		const innerH = height - margin.top - margin.bottom;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const sorted = [...data].sort((a, b) => a.period - b.period);

		const x = d3.scaleLinear()
			.domain(d3.extent(sorted, d => d.period) as [number, number])
			.range([0, innerW]);

		const allY = sorted.flatMap(d => [d['conf.low'], d['conf.high'], d.estimate]);
		const y = d3.scaleLinear()
			.domain(d3.extent(allY) as [number, number])
			.nice()
			.range([innerH, 0]);

		// Treatment shading
		const treatX = x(0);
		g.append('rect')
			.attr('x', treatX)
			.attr('y', 0)
			.attr('width', innerW - treatX)
			.attr('height', innerH)
			.attr('fill', VERONESE[0])
			.attr('opacity', 0.06);

		// Zero line
		g.append('line')
			.attr('x1', 0).attr('x2', innerW)
			.attr('y1', y(0)).attr('y2', y(0))
			.attr('stroke', COLORS.textMuted)
			.attr('stroke-dasharray', '4,3');

		// Event line
		g.append('line')
			.attr('x1', treatX).attr('x2', treatX)
			.attr('y1', 0).attr('y2', innerH)
			.attr('stroke', VERONESE[0])
			.attr('stroke-dasharray', '4,3')
			.attr('stroke-opacity', 0.7);

		g.append('text')
			.attr('x', treatX + 4).attr('y', 14)
			.attr('fill', VERONESE[0])
			.style('font-size', '10px')
			.text('RH Restriction');

		// CI band
		const area = d3.area<EventStudyCoef>()
			.x(d => x(d.period))
			.y0(d => y(d['conf.low']))
			.y1(d => y(d['conf.high']))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(sorted)
			.attr('d', area)
			.attr('fill', VERONESE[7])
			.attr('opacity', 0.2);

		// Line
		const line = d3.line<EventStudyCoef>()
			.x(d => x(d.period))
			.y(d => y(d.estimate))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(sorted)
			.attr('d', line)
			.attr('fill', 'none')
			.attr('stroke', VERONESE[7])
			.attr('stroke-width', 2);

		// Points
		g.selectAll('.point')
			.data(sorted)
			.join('circle')
			.attr('cx', d => x(d.period))
			.attr('cy', d => y(d.estimate))
			.attr('r', 4)
			.attr('fill', d => d['p.value'] < 0.05 ? VERONESE[7] : 'none')
			.attr('stroke', VERONESE[7])
			.attr('stroke-width', 2);

		// Axes
		g.append('g')
			.attr('transform', `translate(0,${innerH})`)
			.call(d3.axisBottom(x).ticks(10))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		g.append('g')
			.call(d3.axisLeft(y).ticks(6))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		// Axis labels
		g.append('text')
			.attr('x', innerW / 2).attr('y', innerH + 35)
			.attr('text-anchor', 'middle')
			.attr('fill', COLORS.textMuted).style('font-size', '12px')
			.text('Days Relative to Event (Jan 28, 2021)');

		g.append('text')
			.attr('transform', 'rotate(-90)')
			.attr('y', -45).attr('x', -innerH / 2)
			.attr('text-anchor', 'middle')
			.attr('fill', COLORS.textMuted).style('font-size', '12px')
			.text('Treatment Effect');

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
	<div bind:this={container} class="w-full" style="height: 400px"></div>
</div>
