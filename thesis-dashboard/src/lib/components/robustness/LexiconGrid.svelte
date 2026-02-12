<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import { fmtPvalue, sigStars } from '$lib/utils/formats';
	import type { RobustnessCoef } from '$lib/types';

	let { data }: { data: RobustnessCoef[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		// Filter out intercepts
		const filtered = data.filter(d => d.variable !== '(Intercept)');
		const models = [...new Set(filtered.map(d => d.model))];
		const variables = [...new Set(filtered.map(d => d.variable))];

		const margin = { top: 50, right: 20, bottom: 20, left: 140 };
		const cellW = 100;
		const cellH = 50;
		const width = Math.max(margin.left + margin.right + models.length * cellW, container.clientWidth);
		const height = margin.top + margin.bottom + variables.length * cellH;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		// Color by p-value
		const pColor = (p: number) => {
			if (p < 0.01) return VERONESE[6];
			if (p < 0.05) return VERONESE[5];
			if (p < 0.1) return VERONESE[3];
			return '#1e1e2e';
		};

		// Column headers
		models.forEach((model, j) => {
			g.append('text')
				.attr('x', j * cellW + cellW / 2)
				.attr('y', -12)
				.attr('text-anchor', 'middle')
				.attr('fill', COLORS.text)
				.style('font-size', '11px').style('font-weight', '600')
				.text(model);
		});

		// Row headers
		variables.forEach((v, i) => {
			g.append('text')
				.attr('x', -8)
				.attr('y', i * cellH + cellH / 2)
				.attr('dy', '0.35em').attr('text-anchor', 'end')
				.attr('fill', COLORS.text).style('font-size', '11px')
				.text(v);
		});

		// Cells
		for (let i = 0; i < variables.length; i++) {
			for (let j = 0; j < models.length; j++) {
				const entry = filtered.find(d => d.variable === variables[i] && d.model === models[j]);

				g.append('rect')
					.attr('x', j * cellW + 2).attr('y', i * cellH + 2)
					.attr('width', cellW - 4).attr('height', cellH - 4)
					.attr('fill', entry ? pColor(entry.p_value) : '#0a0a0f')
					.attr('opacity', entry ? 0.3 : 0.1)
					.attr('rx', 4);

				if (entry) {
					g.append('text')
						.attr('x', j * cellW + cellW / 2)
						.attr('y', i * cellH + cellH / 2 - 6)
						.attr('text-anchor', 'middle')
						.attr('fill', COLORS.text).style('font-size', '11px')
						.text(entry.estimate.toExponential(2));

					g.append('text')
						.attr('x', j * cellW + cellW / 2)
						.attr('y', i * cellH + cellH / 2 + 10)
						.attr('text-anchor', 'middle')
						.attr('fill', entry.p_value < 0.05 ? VERONESE[6] : COLORS.textDim)
						.style('font-size', '10px')
						.text(`p=${fmtPvalue(entry.p_value)}${sigStars(entry.p_value)}`);
				}
			}
		}
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
	<div bind:this={container} class="w-full overflow-x-auto" style="min-height: 300px"></div>
</div>
