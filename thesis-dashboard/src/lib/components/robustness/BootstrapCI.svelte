<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import type { BootstrapCIRow } from '$lib/types';

	let { data }: { data: BootstrapCIRow[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const filtered = data.filter(d => d.coefficient !== '(Intercept)');
		if (!filtered.length) return;

		const margin = { top: 20, right: 30, bottom: 30, left: 120 };
		const rowH = 60;
		const height = filtered.length * rowH + margin.top + margin.bottom;
		const width = container.clientWidth;
		const innerW = width - margin.left - margin.right;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const allX = filtered.flatMap(d => [d.ci_lower, d.ci_upper, d.mean_est]);
		const xPad = Math.max((d3.max(allX)! - d3.min(allX)!) * 0.2, 0.00001);
		const x = d3.scaleLinear()
			.domain([d3.min(allX)! - xPad, d3.max(allX)! + xPad])
			.range([0, innerW]);

		// Zero line
		g.append('line')
			.attr('x1', x(0)).attr('x2', x(0))
			.attr('y1', 0).attr('y2', filtered.length * rowH)
			.attr('stroke', COLORS.textMuted)
			.attr('stroke-dasharray', '4,3');

		filtered.forEach((d, i) => {
			const y = i * rowH + rowH / 2;
			const crossesZero = d.ci_lower <= 0 && d.ci_upper >= 0;
			const color = crossesZero ? VERONESE[4] : VERONESE[6];

			// CI bar
			g.append('rect')
				.attr('x', x(d.ci_lower))
				.attr('y', y - 10)
				.attr('width', x(d.ci_upper) - x(d.ci_lower))
				.attr('height', 20)
				.attr('fill', color)
				.attr('opacity', 0.2)
				.attr('rx', 4);

			// CI edges
			g.append('line')
				.attr('x1', x(d.ci_lower)).attr('x2', x(d.ci_lower))
				.attr('y1', y - 12).attr('y2', y + 12)
				.attr('stroke', color).attr('stroke-width', 2);

			g.append('line')
				.attr('x1', x(d.ci_upper)).attr('x2', x(d.ci_upper))
				.attr('y1', y - 12).attr('y2', y + 12)
				.attr('stroke', color).attr('stroke-width', 2);

			// Mean line
			g.append('line')
				.attr('x1', x(d.ci_lower)).attr('x2', x(d.ci_upper))
				.attr('y1', y).attr('y2', y)
				.attr('stroke', color).attr('stroke-width', 1.5);

			// Point estimate
			g.append('circle')
				.attr('cx', x(d.mean_est)).attr('cy', y)
				.attr('r', 5)
				.attr('fill', color)
				.attr('stroke', '#0a0a0f')
				.attr('stroke-width', 2);

			// Label
			g.append('text')
				.attr('x', -8).attr('y', y)
				.attr('dy', '0.35em').attr('text-anchor', 'end')
				.attr('fill', COLORS.text).style('font-size', '12px')
				.text(d.coefficient);

			// Note: crosses zero?
			g.append('text')
				.attr('x', x(d.ci_upper) + 8).attr('y', y)
				.attr('dy', '0.35em')
				.attr('fill', crossesZero ? VERONESE[4] : VERONESE[6])
				.style('font-size', '10px')
				.text(crossesZero ? 'Includes 0' : 'Sig.');
		});

		// X axis
		g.append('g')
			.attr('transform', `translate(0,${filtered.length * rowH})`)
			.call(d3.axisBottom(x).ticks(6))
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
	<div bind:this={container} class="w-full" style="min-height: 200px"></div>
	<p class="mt-2 text-[10px]" style="color: {COLORS.textDim}">
		1,000 bootstrap replications. CIs crossing zero indicate no significant effect.
	</p>
</div>
