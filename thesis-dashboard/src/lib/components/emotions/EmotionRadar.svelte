<script lang="ts">
	import { onMount } from 'svelte';
	import * as d3 from 'd3';
	import { COLORS, EMOTION_COLORS, VERONESE } from '$lib/utils/colors';
	import type { EmotionRow } from '$lib/types';

	let { data }: { data: EmotionRow[] } = $props();

	let container: HTMLDivElement;

	function draw() {
		if (!container || !data.length) return;
		d3.select(container).selectAll('*').remove();

		const width = Math.min(container.clientWidth, 500);
		const height = width;
		const radius = width / 2 - 60;

		const svg = d3.select(container)
			.append('svg')
			.attr('width', width)
			.attr('height', height);

		const g = svg.append('g')
			.attr('transform', `translate(${width / 2},${height / 2})`);

		const emotions = [...new Set(data.map(d => d.emotion))];
		const avgByEmotion = emotions.map(e => {
			const vals = data.filter(d => d.emotion === e).map(d => d.normalized);
			return {
				emotion: e,
				avg: vals.reduce((a, b) => a + b, 0) / vals.length
			};
		});

		const maxVal = d3.max(avgByEmotion, d => d.avg) ?? 1;
		const angleSlice = (Math.PI * 2) / emotions.length;

		// Concentric rings
		const levels = 5;
		for (let i = 1; i <= levels; i++) {
			const r = (radius / levels) * i;
			g.append('circle')
				.attr('cx', 0).attr('cy', 0).attr('r', r)
				.attr('fill', 'none')
				.attr('stroke', COLORS.grid)
				.attr('stroke-opacity', 0.4);
		}

		// Axis lines and labels
		for (let i = 0; i < emotions.length; i++) {
			const angle = angleSlice * i - Math.PI / 2;
			const lineX = Math.cos(angle) * radius;
			const lineY = Math.sin(angle) * radius;

			g.append('line')
				.attr('x1', 0).attr('y1', 0)
				.attr('x2', lineX).attr('y2', lineY)
				.attr('stroke', COLORS.grid)
				.attr('stroke-opacity', 0.4);

			const labelR = radius + 20;
			g.append('text')
				.attr('x', Math.cos(angle) * labelR)
				.attr('y', Math.sin(angle) * labelR)
				.attr('text-anchor', 'middle')
				.attr('dy', '0.35em')
				.attr('fill', EMOTION_COLORS[emotions[i]] || COLORS.textMuted)
				.style('font-size', '11px')
				.style('font-weight', '600')
				.text(emotions[i]);
		}

		// Data polygon
		const points = avgByEmotion.map((d, i) => {
			const angle = angleSlice * i - Math.PI / 2;
			const r = (d.avg / maxVal) * radius;
			return [Math.cos(angle) * r, Math.sin(angle) * r];
		});

		const lineGen = d3.lineRadial<{ avg: number }>()
			.angle((_, i) => angleSlice * i)
			.radius(d => (d.avg / maxVal) * radius)
			.curve(d3.curveLinearClosed);

		g.append('path')
			.datum(avgByEmotion)
			.attr('d', lineGen)
			.attr('fill', VERONESE[6])
			.attr('fill-opacity', 0.2)
			.attr('stroke', VERONESE[6])
			.attr('stroke-width', 2);

		// Data points
		for (let i = 0; i < avgByEmotion.length; i++) {
			const angle = angleSlice * i - Math.PI / 2;
			const r = (avgByEmotion[i].avg / maxVal) * radius;
			g.append('circle')
				.attr('cx', Math.cos(angle) * r)
				.attr('cy', Math.sin(angle) * r)
				.attr('r', 4)
				.attr('fill', EMOTION_COLORS[emotions[i]] || VERONESE[6])
				.attr('stroke', '#0a0a0f')
				.attr('stroke-width', 2);
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

<div class="flex justify-center">
	<div bind:this={container} class="w-full max-w-[500px]" style="height: 500px"></div>
</div>
