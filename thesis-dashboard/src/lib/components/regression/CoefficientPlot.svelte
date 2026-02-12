<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import type { RegressionCoef } from '$lib/types';

	let {
		data,
		models = ['AFINN Full', 'WSB Full', 'Combined'],
		height = 400
	}: {
		data: RegressionCoef[];
		models?: string[];
		height?: number;
	} = $props();

	let container: HTMLDivElement;
	let activeModels = $state<string[]>([...models]);

	const MODEL_COLORS: Record<string, string> = {
		'AFINN Contemporaneous': VERONESE[3],
		'AFINN Lagged': VERONESE[5],
		'AFINN Full': VERONESE[6],
		'WSB Lagged': VERONESE[2],
		'WSB Full': VERONESE[0],
		'Text Only': VERONESE[4],
		'Emoji Only': VERONESE[3],
		'Combined': VERONESE[7]
	};

	function toggleModel(model: string) {
		if (activeModels.includes(model)) {
			if (activeModels.length > 1) {
				activeModels = activeModels.filter(m => m !== model);
			}
		} else {
			activeModels = [...activeModels, model];
		}
	}

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const filtered = data.filter(d =>
			activeModels.includes(d.model) && d.variable !== '(Intercept)'
		);
		if (!filtered.length) return;

		const margin = { top: 10, right: 30, bottom: 30, left: 140 };
		const width = container.clientWidth;
		const innerW = width - margin.left - margin.right;
		const innerH = height - margin.top - margin.bottom;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${margin.left},${margin.top})`);

		const variables = [...new Set(filtered.map(d => d.variable))];
		const shownModels = [...new Set(filtered.map(d => d.model))];

		const yOuter = d3.scaleBand()
			.domain(variables)
			.range([0, innerH])
			.padding(0.3);

		const yInner = d3.scaleBand()
			.domain(shownModels)
			.range([0, yOuter.bandwidth()])
			.padding(0.15);

		const xMin = d3.min(filtered, d => d.ci_lower) ?? 0;
		const xMax = d3.max(filtered, d => d.ci_upper) ?? 0;
		const xPad = Math.max((xMax - xMin) * 0.15, 0.0001);
		const x = d3.scaleLinear()
			.domain([Math.min(xMin - xPad, -xPad), xMax + xPad])
			.range([0, innerW]);

		// Zero line
		g.append('line')
			.attr('x1', x(0)).attr('x2', x(0))
			.attr('y1', 0).attr('y2', innerH)
			.attr('stroke', COLORS.textMuted)
			.attr('stroke-dasharray', '4,3')
			.attr('stroke-width', 1);

		for (const variable of variables) {
			const varData = filtered.filter(d => d.variable === variable);
			const yBase = yOuter(variable)!;

			for (const d of varData) {
				const yPos = yBase + (yInner(d.model) ?? 0) + yInner.bandwidth() / 2;
				const color = MODEL_COLORS[d.model] || COLORS.textMuted;
				const significant = d.p_value < 0.05;

				// CI whisker
				g.append('line')
					.attr('x1', x(d.ci_lower)).attr('x2', x(d.ci_upper))
					.attr('y1', yPos).attr('y2', yPos)
					.attr('stroke', color).attr('stroke-width', 1.5);

				// CI caps
				for (const val of [d.ci_lower, d.ci_upper]) {
					g.append('line')
						.attr('x1', x(val)).attr('x2', x(val))
						.attr('y1', yPos - 4).attr('y2', yPos + 4)
						.attr('stroke', color).attr('stroke-width', 1.5);
				}

				// Point estimate
				g.append('circle')
					.attr('cx', x(d.estimate)).attr('cy', yPos)
					.attr('r', 5)
					.attr('fill', significant ? color : 'none')
					.attr('stroke', color).attr('stroke-width', 2);
			}
		}

		// Y axis
		g.append('g')
			.call(d3.axisLeft(yOuter).tickSize(0))
			.selectAll('text')
			.attr('fill', COLORS.text).style('font-size', '11px');

		// X axis
		g.append('g')
			.attr('transform', `translate(0,${innerH})`)
			.call(d3.axisBottom(x).ticks(6))
			.selectAll('text')
			.attr('fill', COLORS.textMuted).style('font-size', '11px');

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
		if (data && activeModels) draw();
	});
</script>

<div>
	<!-- Model pills -->
	<div class="mb-4 flex flex-wrap gap-2">
		{#each models as model}
			<button
				onclick={() => toggleModel(model)}
				class="rounded-full px-3 py-1 text-xs font-medium transition-all"
				style="
					background: {activeModels.includes(model) ? MODEL_COLORS[model] + '30' : '#1e1e2e'};
					border: 1px solid {activeModels.includes(model) ? MODEL_COLORS[model] : '#2a2a3e'};
					color: {activeModels.includes(model) ? MODEL_COLORS[model] : COLORS.textMuted};
				"
			>
				{model}
			</button>
		{/each}
	</div>
	<div bind:this={container} class="w-full" style="height:{height}px"></div>
	<p class="mt-2 text-[10px]" style="color: {COLORS.textDim}">
		Filled = significant (p&lt;0.05); hollow = not significant. Whiskers = 95% CI.
	</p>
</div>
