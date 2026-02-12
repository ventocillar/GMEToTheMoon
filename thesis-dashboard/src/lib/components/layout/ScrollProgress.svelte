<script lang="ts">
	import { VERONESE } from '$lib/utils/colors';

	let progress = $state(0);

	function onScroll() {
		const scrollTop = document.documentElement.scrollTop;
		const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
		progress = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
	}

	$effect(() => {
		window.addEventListener('scroll', onScroll, { passive: true });
		return () => window.removeEventListener('scroll', onScroll);
	});
</script>

<div class="fixed top-0 left-0 z-[100] h-[3px] w-full">
	<div
		class="h-full transition-[width] duration-75"
		style="width: {progress * 100}%; background: linear-gradient(90deg, {VERONESE[0]}, {VERONESE[3]}, {VERONESE[6]})"
	></div>
</div>
