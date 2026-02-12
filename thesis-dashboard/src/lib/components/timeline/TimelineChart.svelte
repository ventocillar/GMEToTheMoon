<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import { fmtDate, fmtComma, fmtPct, parseDate } from '$lib/utils/formats';
	import type { TimelineRow } from '$lib/types';

	let { data }: { data: TimelineRow[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const margin = { top: 30, right: 70, bottom: 40, left: 70 };
		const width = container.clientWidth;
		const height = 450;
		const innerW = width - margin.left - margin.right;
		const innerH = height - margin.top - margin.bottom;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const dates = data.map(d => parseDate(d.date));
		const prices = data.map(d => d.gme_close);
		const sentiment = data.map(d => d.afinn_score);

		const x = d3.scaleTime()
			.domain(d3.extent(dates) as [Date, Date])
			.range([0, innerW]);

		const yPrice = d3.scaleLinear()
			.domain([0, (d3.max(prices) ?? 100) * 1.1])
			.range([innerH, 0]);

		const ySent = d3.scaleLinear()
			.domain(d3.extent(sentiment) as [number, number])
			.nice()
			.range([innerH, 0]);

		// Grid
		g.append('g')
			.call(d3.axisLeft(yPrice).tickSize(-innerW).tickFormat(() => ''))
			.selectAll('line').attr('stroke', COLORS.grid).attr('stroke-opacity', 0.4);
		g.selectAll('.domain').remove();

		// Sentiment area
		const area = d3.area<number>()
			.x((_, i) => x(dates[i]))
			.y0(innerH)
			.y1((d) => ySent(d))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(sentiment)
			.attr('d', area)
			.attr('fill', VERONESE[3])
			.attr('opacity', 0.15);

		// Sentiment line
		const sentLine = d3.line<number>()
			.x((_, i) => x(dates[i]))
			.y(d => ySent(d))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(sentiment)
			.attr('d', sentLine)
			.attr('fill', 'none')
			.attr('stroke', VERONESE[3])
			.attr('stroke-width', 1.5)
			.attr('opacity', 0.7);

		// Price line
		const priceLine = d3.line<number>()
			.x((_, i) => x(dates[i]))
			.y(d => yPrice(d))
			.curve(d3.curveMonotoneX);

		g.append('path')
			.datum(prices)
			.attr('d', priceLine)
			.attr('fill', 'none')
			.attr('stroke', VERONESE[6])
			.attr('stroke-width', 2.5);

		// Event lines
		const events = [
			{ date: new Date('2021-01-22'), label: 'First surge' },
			{ date: new Date('2021-01-27'), label: 'Peak' },
			{ date: new Date('2021-01-28'), label: 'RH restriction' }
		];

		for (const evt of events) {
			const ex = x(evt.date);
			g.append('line')
				.attr('x1', ex).attr('x2', ex)
				.attr('y1', 0).attr('y2', innerH)
				.attr('stroke', VERONESE[0])
				.attr('stroke-dasharray', '4,3')
				.attr('stroke-opacity', 0.6);

			g.append('text')
				.attr('x', ex + 4).attr('y', 12)
				.attr('fill', VERONESE[0])
				.style('font-size', '10px')
				.text(evt.label);
		}

		// Axes
		g.append('g')
			.attr('transform', `translate(0,${innerH})`)
			.call(d3.axisBottom(x).ticks(8).tickFormat(d3.timeFormat('%b %d') as any))
			.selectAll('text').attr('fill', COLORS.textMuted).style('font-size', '11px');

		g.append('g')
			.call(d3.axisLeft(yPrice).ticks(6).tickFormat(d => `$${d}`))
			.selectAll('text').attr('fill', VERONESE[6]).style('font-size', '11px');

		g.append('g')
			.attr('transform', `translate(${innerW},0)`)
			.call(d3.axisRight(ySent).ticks(6).tickFormat(d3.format('.0s') as any))
			.selectAll('text').attr('fill', VERONESE[3]).style('font-size', '11px');

		// Axis labels
		g.append('text')
			.attr('transform', 'rotate(-90)')
			.attr('y', -50).attr('x', -innerH / 2)
			.attr('text-anchor', 'middle')
			.attr('fill', VERONESE[6]).style('font-size', '12px')
			.text('GME Price (USD)');

		g.append('text')
			.attr('transform', 'rotate(90)')
			.attr('y', -innerW - 50).attr('x', innerH / 2)
			.attr('text-anchor', 'middle')
			.attr('fill', VERONESE[3]).style('font-size', '12px')
			.text('AFINN Sentiment Score');

		// Tooltip
		const tooltip = d3.select(container)
			.append('div')
			.style('position', 'absolute')
			.style('display', 'none')
			.style('background', COLORS.tooltipBg)
			.style('border', `1px solid ${COLORS.border}`)
			.style('border-radius', '8px')
			.style('padding', '10px 14px')
			.style('font-size', '12px')
			.style('color', COLORS.text)
			.style('pointer-events', 'none')
			.style('z-index', '10');

		const bisect = d3.bisector((d: TimelineRow) => parseDate(d.date)).left;

		svg.append('rect')
			.attr('width', width).attr('height', height)
			.attr('fill', 'transparent')
			.on('mousemove', function (event) {
				const [mx] = d3.pointer(event);
				const dateAtMouse = x.invert(mx - margin.left);
				const i = Math.min(bisect(data, dateAtMouse), data.length - 1);
				const d = data[i];
				if (!d) return;

				tooltip
					.html(`
						<strong>${fmtDate(parseDate(d.date))}</strong><br/>
						<span style="color:${VERONESE[6]}">Price: $${d.gme_close.toFixed(2)}</span><br/>
						<span style="color:${VERONESE[3]}">AFINN: ${fmtComma(Math.round(d.afinn_score))}</span><br/>
						<span style="color:${COLORS.textMuted}">Volume: ${fmtComma(d.gme_volume)}</span><br/>
						<span style="color:${COLORS.textMuted}">Comments: ${fmtComma(d.n_comments)}</span>
					`)
					.style('display', 'block')
					.style('left', `${event.offsetX + 15}px`)
					.style('top', `${event.offsetY - 10}px`);
			})
			.on('mouseleave', () => tooltip.style('display', 'none'));

		g.selectAll('.tick line').attr('stroke', COLORS.axis);
		g.selectAll('.domain').attr('stroke', COLORS.axis);
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

<div class="relative">
	<div class="mb-4 flex flex-wrap items-center gap-4 text-xs">
		<span class="flex items-center gap-1.5">
			<span class="inline-block h-0.5 w-5 rounded" style="background: {VERONESE[6]}"></span>
			GME Price
		</span>
		<span class="flex items-center gap-1.5">
			<span class="inline-block h-3 w-5 rounded opacity-30" style="background: {VERONESE[3]}"></span>
			AFINN Sentiment
		</span>
	</div>
	<div bind:this={container} class="relative w-full" style="height: 450px"></div>
</div>
