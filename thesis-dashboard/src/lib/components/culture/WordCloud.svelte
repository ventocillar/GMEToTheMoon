<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, VERONESE } from '$lib/utils/colors';
	import { fmtComma } from '$lib/utils/formats';
	import type { WordContribRow } from '$lib/types';

	let { data }: { data: WordContribRow[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const positive = data.filter(d => d.sentiment === 'positive').sort((a, b) => b.count - a.count).slice(0, 20);
		const negative = data.filter(d => d.sentiment === 'negative').sort((a, b) => b.count - a.count).slice(0, 20);

		const allWords = [...positive, ...negative];
		const maxCount = d3.max(allWords, d => d.count) ?? 1;

		const margin = { top: 30, right: 20, bottom: 30, left: 80 };
		const barH = 20;
		const gap = 3;
		const panelH = Math.max(positive.length, negative.length) * (barH + gap);
		const height = panelH + margin.top + margin.bottom;
		const width = container.clientWidth;
		const innerW = (width - margin.left - margin.right) / 2 - 10;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		// Panel labels
		svg.append('text')
			.attr('x', margin.left + innerW / 2)
			.attr('y', 18)
			.attr('text-anchor', 'middle')
			.attr('fill', VERONESE[6]).style('font-size', '12px').style('font-weight', '600')
			.text('Positive');

		svg.append('text')
			.attr('x', margin.left + innerW + 20 + innerW / 2)
			.attr('y', 18)
			.attr('text-anchor', 'middle')
			.attr('fill', VERONESE[0]).style('font-size', '12px').style('font-weight', '600')
			.text('Negative');

		const drawPanel = (words: WordContribRow[], offsetX: number, color: string) => {
			const g = svg.append('g')
				.attr('transform', `translate(${margin.left + offsetX},${margin.top})`);

			const x = d3.scaleLinear().domain([0, maxCount]).range([0, innerW]);

			words.forEach((d, i) => {
				const y = i * (barH + gap);

				g.append('rect')
					.attr('x', 0).attr('y', y)
					.attr('width', x(d.count))
					.attr('height', barH)
					.attr('fill', color)
					.attr('opacity', 0.6)
					.attr('rx', 3);

				g.append('text')
					.attr('x', -6).attr('y', y + barH / 2)
					.attr('dy', '0.35em').attr('text-anchor', 'end')
					.attr('fill', COLORS.text).style('font-size', '11px')
					.text(d.word);

				g.append('text')
					.attr('x', x(d.count) + 4).attr('y', y + barH / 2)
					.attr('dy', '0.35em')
					.attr('fill', COLORS.textDim).style('font-size', '10px')
					.text(fmtComma(d.count));
			});
		};

		drawPanel(positive, 0, VERONESE[6]);
		drawPanel(negative, innerW + 20, VERONESE[0]);
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
	<div bind:this={container} class="w-full" style="min-height: 500px"></div>
</div>
