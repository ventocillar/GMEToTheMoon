<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import { fmtDate, fmtPct, parseDate } from '$lib/utils/formats';
	import type { CumulativeReturn } from '$lib/types';

	let { data }: { data: CumulativeReturn[] } = $props();

	let container: HTMLDivElement;

	const GROUP_COLORS: Record<string, string> = {
		'Meme Stocks': VERONESE[7],
		'Control Stocks': VERONESE[4]
	};

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const margin = { top: 20, right: 20, bottom: 40, left: 60 };
		const width = container.clientWidth;
		const height = 350;
		const innerW = width - margin.left - margin.right;
		const innerH = height - margin.top - margin.bottom;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const dates = data.map(d => parseDate(d.date));
		const groups = [...new Set(data.map(d => d.group))];

		const x = d3.scaleTime()
			.domain(d3.extent(dates) as [Date, Date])
			.range([0, innerW]);

		const y = d3.scaleLinear()
			.domain(d3.extent(data, d => d.cumulative_return) as [number, number])
			.nice()
			.range([innerH, 0]);

		// Grid
		g.append('g')
			.call(d3.axisLeft(y).tickSize(-innerW).tickFormat(() => ''))
			.selectAll('line').attr('stroke', COLORS.grid).attr('stroke-opacity', 0.3);
		g.selectAll('.grid .domain').remove();

		// Event line
		const eventX = x(new Date('2021-01-28'));
		g.append('line')
			.attr('x1', eventX).attr('x2', eventX)
			.attr('y1', 0).attr('y2', innerH)
			.attr('stroke', VERONESE[0]).attr('stroke-dasharray', '4,3').attr('stroke-opacity', 0.7);

		g.append('text')
			.attr('x', eventX + 4).attr('y', 14)
			.attr('fill', VERONESE[0]).style('font-size', '10px')
			.text('RH Restriction');

		// Lines
		for (const group of groups) {
			const groupData = data
				.filter(d => d.group === group)
				.sort((a, b) => a.date.localeCompare(b.date));

			const line = d3.line<CumulativeReturn>()
				.x(d => x(parseDate(d.date)))
				.y(d => y(d.cumulative_return))
				.defined(d => d.cumulative_return != null);

			g.append('path')
				.datum(groupData)
				.attr('d', line)
				.attr('fill', 'none')
				.attr('stroke', GROUP_COLORS[group] || COLORS.textMuted)
				.attr('stroke-width', 2);
		}

		// Axes
		g.append('g')
			.attr('transform', `translate(0,${innerH})`)
			.call(d3.axisBottom(x).ticks(6).tickFormat(d3.timeFormat('%b %d') as any))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		g.append('g')
			.call(d3.axisLeft(y).ticks(6).tickFormat(d3.format('.0%') as any))
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
	<div class="mb-3 flex gap-4 text-xs">
		<span class="flex items-center gap-1.5">
			<span class="inline-block h-0.5 w-5" style="background: {VERONESE[7]}"></span>
			Meme Stocks
		</span>
		<span class="flex items-center gap-1.5">
			<span class="inline-block h-0.5 w-5" style="background: {VERONESE[4]}"></span>
			Control Stocks
		</span>
	</div>
	<div bind:this={container} class="w-full" style="height: 350px"></div>
</div>
