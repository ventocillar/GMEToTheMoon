<script lang="ts">
	import { VERONESE } from '$lib/utils/colors';

	let {
		activeSection = 'hero'
	}: {
		activeSection?: string;
	} = $props();

	const sections = [
		{ id: 'hero', label: 'Intro', short: '01' },
		{ id: 'timeline', label: 'Timeline', short: '02' },
		{ id: 'null-result', label: 'Causality', short: '03' },
		{ id: 'regression', label: 'Regression', short: '04' },
		{ id: 'did', label: 'DiD', short: '05' },
		{ id: 'irf', label: 'IRF', short: '06' },
		{ id: 'emotions', label: 'Emotions', short: '07' },
		{ id: 'culture', label: 'Culture', short: '08' },
		{ id: 'robustness', label: 'Robustness', short: '09' },
		{ id: 'methodology', label: 'Methods', short: '10' }
	];
</script>

<nav class="fixed right-4 top-1/2 z-50 -translate-y-1/2 hidden lg:flex flex-col items-end gap-2">
	{#each sections as sec}
		<a
			href="#{sec.id}"
			class="group flex items-center gap-2 transition-all"
			title={sec.label}
		>
			<span
				class="text-[10px] tracking-wider uppercase opacity-0 group-hover:opacity-100 transition-opacity {activeSection === sec.id ? '!opacity-100 text-[#C38F16]' : 'text-[#a1a1aa]'}"
			>
				{sec.label}
			</span>
			<span
				class="block rounded-full transition-all {activeSection === sec.id
					? 'w-3 h-3 bg-[#C38F16]'
					: 'w-2 h-2 bg-[#3f3f50] group-hover:bg-[#a1a1aa]'}"
			></span>
		</a>
	{/each}
</nav>
