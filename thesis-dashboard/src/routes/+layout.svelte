<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { loadAllData } from '$lib/stores/data.svelte';
	import ScrollProgress from '$lib/components/layout/ScrollProgress.svelte';

	let { children } = $props();

	onMount(() => {
		loadAllData();
	});
</script>

<ScrollProgress />
<div class="min-h-screen">
	{@render children()}
</div>
