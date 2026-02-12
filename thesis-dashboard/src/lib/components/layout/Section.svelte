<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		id,
		label,
		onVisible,
		children
	}: {
		id: string;
		label: string;
		onVisible?: (id: string) => void;
		children: Snippet;
	} = $props();

	let el: HTMLElement;

	$effect(() => {
		if (!el || !onVisible) return;
		const observer = new IntersectionObserver(
			([entry]) => {
				if (entry.isIntersecting) onVisible(id);
			},
			{ rootMargin: '-40% 0px -40% 0px' }
		);
		observer.observe(el);
		return () => observer.disconnect();
	});
</script>

<section bind:this={el} {id} class="scroll-mt-16 py-16 md:py-24">
	{@render children()}
</section>
