# GMEToTheMoon Dashboard Guide

A comprehensive reference covering the analytical methodology behind the thesis and the technical implementation of the interactive SvelteKit + D3 scrollytelling dashboard.

**Thesis**: *Retail Investor Sentiment and Meme Stock Returns: Evidence from r/WallStreetBets During the GameStop Short Squeeze*

---

## Table of Contents

### Part 1: Methodology Thought Process
1. [Research Design Rationale](#1-research-design-rationale)
2. [Data Strategy](#2-data-strategy)
3. [The Null Result](#3-the-null-result)
4. [Difference-in-Differences Design](#4-difference-in-differences-design)
5. [The Emoji Insight](#5-the-emoji-insight)
6. [Robustness Strategy](#6-robustness-strategy)

### Part 2: Step-by-Step Dashboard Build Guide
7. [Project Setup](#7-project-setup)
8. [Architecture Decisions](#8-architecture-decisions)
9. [Dark Theme Design System](#9-dark-theme-design-system)
10. [The D3 Chart Pattern](#10-the-d3-chart-pattern)
11. [Component-by-Component Guide](#11-component-by-component-guide)
12. [Data Flow: R to JSON to Dashboard](#12-data-flow-r-to-json-to-dashboard)
13. [Key Technical Gotchas](#13-key-technical-gotchas)
14. [Directory Structure](#14-directory-structure)

---

# PART 1: Methodology Thought Process

This section maps the complete analytical reasoning behind the GMEToTheMoon project. The research question is deceptively simple: *Did r/WallStreetBets sentiment cause GameStop's stock returns?* The answer requires a carefully layered empirical strategy because **correlation is not causation**, and in financial markets the two are easily confused.

## 1. Research Design Rationale

### Why Not Just Correlation?

The naive approach would be to plot sentiment and returns on the same chart, observe that they move together, and claim a relationship. This is exactly what most media coverage of the GameStop episode did. The problem is **simultaneity**: sentiment and returns are both endogenous variables. Price moves generate news, news generates discussion, discussion contains sentiment, and sentiment may (or may not) influence subsequent prices.

To untangle this, the thesis deploys four distinct techniques, each addressing a different aspect of the causal question:

| Technique | What It Tests | Why It Is Needed |
|-----------|--------------|------------------|
| **OLS + HAC** | Does lagged sentiment predict next-day returns? | Establishes whether there is even a statistical association after controlling for autocorrelation |
| **Granger Causality** | Does past sentiment improve forecasts of returns beyond what returns alone predict? | Tests temporal precedence -- a necessary (but not sufficient) condition for causality |
| **Difference-in-Differences** | Did meme stocks experience abnormal returns after an exogenous shock? | Exploits the Robinhood restriction as a quasi-natural experiment for causal identification |
| **Event Study** | How did treatment effects evolve day-by-day around the event? | Validates the parallel trends assumption and visualizes dynamic treatment effects |

The logic flows as a funnel:

1. **OLS**: Is there any signal at all? (Predictive association)
2. **Granger**: Which direction does the signal flow? (Temporal ordering)
3. **DiD**: Can we isolate a causal effect from an exogenous shock? (Causal identification)
4. **Robustness**: Does the finding survive every alternative specification? (Credibility)

### Why HAC Standard Errors?

Daily financial returns exhibit both heteroskedasticity (volatility clustering) and autocorrelation (momentum/mean-reversion). Ordinary standard errors would be biased downward, inflating t-statistics and producing false positives. Newey-West HAC standard errors with 5 lags correct for both problems. The choice of 5 lags follows the common heuristic of `floor(0.75 * T^(1/3))` for a sample of approximately 82 trading days.

### Why Vector Autoregression for Granger Tests?

A bivariate VAR models the mutual dependence between returns and sentiment as a system of simultaneous equations. Each variable is regressed on its own lags and the other variable's lags. Granger causality then tests whether adding the other variable's lags significantly improves the forecast. This is strictly a test of predictive precedence, not structural causality, but it provides strong evidence about the direction of information flow.

The key prerequisites, all verified in the pipeline:
- **Stationarity**: ADF tests confirm both series are I(0), so the VAR estimates are valid.
- **Lag selection**: AIC minimization selects the optimal number of lags, avoiding both under-fitting (omitted dynamics) and over-fitting (noise).

## 2. Data Strategy

### 14.37 Million Reddit Comments

The dataset covers **all** r/WallStreetBets comments from December 1, 2020 through March 31, 2021, collected via the Arctic Shift API (a community-maintained Pushshift mirror). This window was chosen to capture the full arc of the GameStop episode:

| Sub-Period | Dates | Purpose |
|-----------|-------|---------|
| Pre-attention baseline | Dec 1 -- Jan 10 | Establishes normal sentiment levels before the event |
| Buildup | Jan 11 -- Jan 21 | Ryan Cohen joins the board; WSB attention accelerates |
| Squeeze | Jan 22 -- Jan 29 | Price explosion, peak, and Robinhood restriction |
| Aftermath | Jan 30 -- Mar 31 | Post-restriction decline and normalization |

The four-month window is deliberate. A shorter window would not provide enough pre-event data for the parallel trends test in the DiD design. A longer window would dilute the analysis with periods where GME was not the dominant topic on WSB.

### Why 6 Sentiment Lexicons?

Each lexicon captures different aspects of the text:

| Lexicon | Strength | Weakness |
|---------|----------|----------|
| **AFINN** | Numeric scores (-5 to +5) capture intensity | Designed for general English; misses WSB slang |
| **BING** | Simple binary (positive/negative) classification | No intensity; no WSB coverage |
| **NRC** | 8 emotion categories beyond positive/negative | Broad categories may not capture financial sentiment |
| **Loughran-McDonald** | Designed for financial text | Not designed for informal social media language |
| **WSB Custom** | 58 hand-coded WSB slang terms | Small vocabulary; requires manual curation |
| **Emoji** | 30 emojis with WSB-specific sentiment values | Limited to emoji-using comments |

Using multiple lexicons serves two purposes:
1. **Triangulation**: If a finding is robust across lexicons, it is more credible.
2. **Domain adaptation**: The WSB custom and emoji lexicons address the known failure of standard NLP tools on Reddit-specific language, where "retard" is a term of endearment and a rocket emoji is the strongest possible buy signal.

### Treatment and Control Groups for DiD

The DiD design requires a treatment group (affected by the shock) and a control group (not affected). The groups were chosen based on clear, observable criteria:

**Treatment (meme stocks)**: GME, AMC, BB, NOK, BBBY
- All five were restricted by Robinhood on January 28, 2021
- All five were heavily discussed on r/WallStreetBets during the study period
- The restriction was the exogenous shock: traders could sell but not buy

**Control (retail stocks)**: WMT, TGT, KR, DG
- Same broad sector (retail/consumer discretionary)
- Comparable market capitalization range
- No significant WSB attention during the study period
- Not restricted by Robinhood

The control group selection is critical. Using tech stocks or indices would introduce sector-level confounders. Using other meme-adjacent stocks (e.g., PLTR, TSLA) would contaminate the control group with partial treatment spillovers.

## 3. The Null Result

This is the central finding of the thesis, and it runs counter to the popular narrative.

### Granger Causality Results

| Direction | F-Statistic | p-value | Significant? |
|-----------|------------|---------|-------------|
| AFINN Sentiment --> Returns | 0.05 | **0.82** | No |
| WSB Sentiment --> Returns | 2.82 | **0.097** | No (marginal) |
| Returns --> AFINN Sentiment | 34.2 | **4.7e-8** | Yes |
| Returns --> WSB Sentiment | 21.1 | **2.4e-5** | Yes |

The asymmetry is stark. Sentiment does **not** Granger-cause returns in either lexicon. But returns Granger-cause sentiment with overwhelming significance (p-values in the 10^-5 to 10^-8 range).

### What This Means

Retail traders on r/WallStreetBets **reacted** to price movements rather than driving them. When GME went up, WSB became euphoric. When it crashed, sentiment turned negative. The information flow was from the market to the forum, not the other way around.

This does not mean that WSB had zero influence on the squeeze. It means that daily sentiment aggregates, as measured by lexicon-based NLP, do not predict next-day returns. The causal mechanism, if it exists, may operate at a higher frequency (intraday) or through coordination channels not captured by sentiment scores (e.g., explicit calls to action, position screenshots, options flow).

### Why the OLS Confirms This

The regression models tell the same story. Lagged sentiment coefficients are statistically insignificant in every specification:

- Contemporaneous models show association (sentiment and returns move together on the same day)
- Lagged models show nothing (yesterday's sentiment does not predict today's returns)
- Full models with controls (volume, comment count) show nothing

The confidence intervals for lagged sentiment coefficients cross zero in every model, which is the visual signature of the null result in the coefficient plot.

### Impulse Response Functions

The IRFs from the VAR provide a dynamic picture. A one-standard-deviation shock to sentiment produces **no significant response** in returns at any horizon from 1 to 10 days. The response line is flat and the confidence interval always contains zero.

Conversely, a one-standard-deviation shock to returns produces a significant positive response in sentiment that peaks at day 1 and decays over approximately 3-4 days. This is the "price drives discussion" channel in action.

## 4. Difference-in-Differences Design

### The Quasi-Natural Experiment

Robinhood's decision to restrict buying of meme stocks on January 28, 2021 provides a quasi-natural experiment. The restriction was:
- **Exogenous** to individual stock fundamentals (it was a platform-level decision driven by clearing house margin requirements)
- **Sharp** in timing (announced before market open on Jan 28)
- **Selective** in scope (only affected the 5 meme stocks, not control stocks)

This makes it ideal for a DiD design. The identifying assumption is that, absent the restriction, meme stocks and control stocks would have followed parallel trends.

### The Estimating Equation

```
return_{i,t} = alpha_i + gamma_t + beta * (treated_i x post_t) + epsilon_{i,t}
```

- `alpha_i` = stock fixed effects (absorb time-invariant differences between stocks)
- `gamma_t` = date fixed effects (absorb market-wide shocks on any given day)
- `beta` = the DiD estimator: the average treatment effect on the treated

### Results

| Specification | DiD Estimate | p-value |
|--------------|-------------|---------|
| Basic (no FE) | -0.028 | < 0.01 |
| Stock FE | -0.028 | < 0.01 |
| Two-way FE (stock + date) | -0.028 | < 0.01 |

The estimate is remarkably stable across specifications: meme stocks underperformed control stocks by approximately **2.8 percentage points per day** after the Robinhood restriction. The negative sign confirms that the restriction hurt meme stock prices.

### Validation

Two tests confirm the credibility of the DiD:

**Parallel trends test**: The event study specification estimates separate treatment effects for each day relative to the event. Pre-treatment coefficients (days -10 through -1) are all statistically insignificant and close to zero. This means meme stocks and control stocks were tracking each other before the restriction, which is the key identifying assumption.

**Placebo test**: Running the same DiD with a fake event date of December 15, 2020 produces a coefficient of approximately zero with **p = 0.59**. The model correctly fails to find an effect where none should exist, ruling out false positives from model misspecification.

## 5. The Emoji Insight

### Why Emojis Matter

Standard NLP tools strip non-ASCII characters during tokenization. This means that `unnest_tokens()` in R (and most Python tokenizers) will silently discard all emoji content. On WSB, this is a significant loss of information because emojis carry strong and specific sentiment signals.

The top 5 WSB emojis by frequency and their assigned sentiment values:

| Emoji | Description | Sentiment | WSB Meaning |
|-------|------------|-----------|-------------|
| Rocket | Rocket | +3 | "To the moon" -- strong buy signal |
| Diamond | Gem Stone | +2 | "Diamond hands" -- hold through volatility |
| Raised Hands | Raising Hands | +2 | Used with diamond for "diamond hands" |
| Gorilla | Gorilla | +1 | "Apes together strong" -- community solidarity |
| New Moon | Crescent Moon | +2 | Destination of the rocket -- bullish target |

### The F-Test

To formally test whether emoji sentiment adds predictive power, the thesis compares a text-only model against a combined text + emoji model using an F-test (nested model comparison):

- **F-statistic**: significant
- **p-value**: 0.0009

This means emoji sentiment contains information that text-only sentiment scores do not capture. The practical implication is that any NLP analysis of social media financial data that strips emojis is throwing away a statistically significant predictor.

### Implementation Note

The emoji extraction must happen **before** tokenization. The R pipeline uses `stringi::stri_extract_all_regex()` with a Unicode emoji pattern to pull emojis from the raw comment text, then tokenizes the remaining text separately. Emoji counts and text sentiment are aggregated independently and merged at the daily level.

## 6. Robustness Strategy

Each robustness check addresses a specific threat to the validity of the main findings:

| Check | Threat Addressed | Result |
|-------|-----------------|--------|
| **Alternative lexicons** (BING, NRC, Loughran-McDonald, combined) | Main result depends on a single lexicon | Null result persists across all lexicons |
| **Score-weighted vs. unweighted** | Popular comments may carry different sentiment than unpopular ones | No qualitative difference |
| **High-engagement subsample** (score > 10) | Low-quality comments add noise | Results unchanged |
| **Placebo DiD** (Dec 15, 2020) | DiD model may produce false positives | p = 0.59 (correctly finds nothing) |
| **Bootstrap CIs** (1,000 replications) | Parametric CIs may be unreliable in small samples | Bootstrap CIs also cross zero for sentiment coefficients |
| **Manual validation** (200 comments) | Lexicon-based sentiment may be inaccurate | Provides inter-rater reliability check |

The robustness battery is designed so that each check is independent and addresses a distinct concern. The key finding -- sentiment does not predict returns -- survives all six checks, substantially increasing confidence in the null result.

### Why Bootstrap?

With only 82 trading days, asymptotic properties of OLS estimators may not hold perfectly. The bootstrap generates 1,000 replications of the regression by resampling with replacement, producing an empirical distribution of each coefficient. If the 95% bootstrap confidence interval for a sentiment coefficient contains zero, the null result holds without relying on asymptotic normality.

---

# PART 2: Step-by-Step Dashboard Build Guide

This section provides a practical technical guide for the SvelteKit + D3 scrollytelling dashboard. It is written at a level of detail sufficient for someone with intermediate web development experience to reproduce the build from scratch or extend it.

## 7. Project Setup

### Initialize the SvelteKit Project

```bash
npx sv create thesis-dashboard
cd thesis-dashboard
```

Select the following options during setup:
- Template: Skeleton project
- TypeScript: Yes
- ESLint: No (optional)
- Prettier: No (optional)

### Install Dependencies

```bash
npm install d3 tailwindcss @tailwindcss/vite @types/d3
npm install -D @sveltejs/adapter-static
```

The full `package.json` dependencies:

```json
{
  "devDependencies": {
    "@sveltejs/adapter-static": "^3.0.0",
    "@sveltejs/kit": "^2.50.2",
    "@sveltejs/vite-plugin-svelte": "^5.0.0",
    "svelte": "^5.49.2",
    "svelte-check": "^4.3.6",
    "typescript": "^5.9.3",
    "vite": "^6.3.0"
  },
  "dependencies": {
    "@tailwindcss/vite": "^4.1.18",
    "@types/d3": "^7.4.3",
    "d3": "^7.9.0",
    "tailwindcss": "^4.1.18"
  }
}
```

### Configure adapter-static

Replace the default adapter in `svelte.config.js`:

```js
import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      fallback: 'index.html'
    })
  }
};

export default config;
```

### Configure Vite with Tailwind v4

Tailwind CSS v4 uses a Vite plugin instead of PostCSS. Configure `vite.config.ts`:

```ts
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [tailwindcss(), sveltekit()]
});
```

### Configure TypeScript

In `tsconfig.json`, the critical setting is `noImplicitAny: false`. This is required because D3's callback signatures use `any` types in many places (e.g., `tickFormat`, `on` event handlers), and strict `noImplicitAny` would flag every D3 accessor function:

```json
{
  "extends": "./.svelte-kit/tsconfig.json",
  "compilerOptions": {
    "rewriteRelativeImportExtensions": true,
    "allowJs": true,
    "checkJs": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "strict": true,
    "noImplicitAny": false,
    "moduleResolution": "bundler"
  }
}
```

### Set Up SPA Mode

In `src/routes/+layout.ts`, disable SSR and enable prerendering for static site generation:

```ts
export const prerender = true;
export const ssr = false;
```

This tells SvelteKit to render everything client-side. The `ssr = false` flag is necessary because D3 manipulates the DOM directly and requires `window` and `document` objects that are not available during server-side rendering.

## 8. Architecture Decisions

### Svelte 5 Runes (NOT Legacy Reactive Syntax)

This project uses **Svelte 5 runes** throughout. This is the modern reactive API and differs substantially from Svelte 4:

| Concept | Svelte 4 (legacy) | Svelte 5 (runes) |
|---------|-------------------|-------------------|
| Reactive state | `let x = 0;` (auto-reactive) | `let x = $state(0);` |
| Derived values | `$: doubled = x * 2;` | `let doubled = $derived(x * 2);` |
| Side effects | `$: { console.log(x); }` | `$effect(() => { console.log(x); });` |
| Component props | `export let data;` | `let { data } = $props();` |
| Slot content | `<slot />` | `{@render children()}` |
| Store subscription | `$storeName` auto-subscription | `$derived($storeName)` in components |

Every component in the dashboard uses the runes syntax. If you see `$:` in Svelte tutorials online, that is the legacy syntax and should not be mixed with runes.

### Data Loading Architecture

Data is loaded via `fetch` in `onMount` using writable Svelte stores rather than SvelteKit's `load` function. This decision was made because:

1. With `ssr = false`, there is no server-side `load` function.
2. All 11 JSON files are fetched in parallel via `Promise.all`, minimizing load time.
3. Stores provide a single source of truth that any component can subscribe to.

The flow:

```
+layout.svelte onMount()
  --> loadAllData()
    --> Promise.all([11 fetch() calls])
    --> Each store.set(data)
    --> dataLoaded.set(true)

+page.svelte
  --> $derived($storeName) to access data
  --> {#if loaded} to gate rendering
  --> Components receive data via $props()
```

### Why Writable Stores Instead of Runes for Global State?

Svelte 5 runes (`$state`) are scoped to a single component or module. For global state shared across the layout and page, writable stores from `svelte/store` remain the standard approach. The stores are defined in `data.svelte.ts` (the `.svelte.ts` extension enables runes in non-component files) and subscribed to in components using the `$derived($storeName)` pattern.

### IntersectionObserver for Section Tracking

Each dashboard section is wrapped in a `<Section>` component that uses `IntersectionObserver` to detect when it enters the viewport. The observer uses `rootMargin: '-40% 0px -40% 0px'`, meaning a section is considered "active" when it occupies the middle 20% of the viewport. This creates smooth transitions as the user scrolls.

The `Section` component:

```svelte
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
```

Note the use of `Snippet` type for children (Svelte 5 pattern), `$effect` for lifecycle management, and the cleanup function returning `observer.disconnect()`.

### ResizeObserver on Every Chart

Every D3 chart attaches a `ResizeObserver` to its container element. When the container resizes (window resize, sidebar toggle, etc.), the chart is completely redrawn. This is more reliable than trying to update SVG dimensions incrementally:

```ts
onMount(() => {
  draw();
  const ro = new ResizeObserver(() => draw());
  ro.observe(container);
  return () => ro.disconnect();
});
```

The `draw()` function always starts by clearing the container (`d3.select(container).selectAll('*').remove()`) and measuring the current dimensions from `container.clientWidth`. This "clear and redraw" pattern is simple and avoids stale state.

## 9. Dark Theme Design System

### Color Palette

The design uses a near-black background with a MetBrewer Veronese palette for data colors. The Veronese palette is a 10-color scheme inspired by the paintings of Paolo Veronese, ranging from warm burgundy through amber to cool teal and navy.

#### Background and Surface Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-bg` | `#0a0a0f` | Page background (near-black with slight blue tint) |
| `--color-bg-card` | `#12121a` | Card/panel backgrounds |
| `--color-border` | `#1e1e2e` | Default borders |
| `borderLight` | `#2a2a3e` | Hover/active borders |
| `tooltipBg` | `#1a1a28` | Tooltip backgrounds |

#### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--color-text` | `#e4e4e7` | Primary text (zinc-200) |
| `--color-text-muted` | `#a1a1aa` | Secondary text (zinc-400) |
| `--color-text-dim` | `#71717a` | Tertiary/disabled text (zinc-500) |

#### MetBrewer Veronese Palette

| Index | Hex | Semantic Role |
|-------|-----|--------------|
| 0 | `#67322E` | Negative / bearish / danger |
| 1 | `#885116` | Secondary negative |
| 2 | `#A7700E` | Caution / amber |
| 3 | `#C38F16` | Gold / highlight / accent |
| 4 | `#8A9264` | Olive / transition / neutral |
| 5 | `#58867F` | Teal / neutral-positive |
| 6 | `#2C6B67` | Dark teal / positive / significant |
| 7 | `#1E5B53` | Deep teal / meme stocks |
| 8 | `#154647` | Dark cyan / control stocks |
| 9 | `#122C43` | Navy / background accent |

The palette is stored in `src/lib/utils/colors.ts` and exported as both an indexed array (`VERONESE`) and a semantic object (`COLORS`).

#### NRC Emotion Colors

For the emotion radar and stream charts, a separate set of saturated colors is used:

| Emotion | Hex |
|---------|-----|
| anger | `#E74C3C` |
| anticipation | `#F39C12` |
| disgust | `#8E44AD` |
| fear | `#2C3E50` |
| joy | `#F1C40F` |
| sadness | `#3498DB` |
| surprise | `#E67E22` |
| trust | `#27AE60` |

### CSS Architecture

The global styles are defined in `src/app.css` using Tailwind v4 syntax:

```css
@import 'tailwindcss';

@theme {
  --color-bg: #0a0a0f;
  --color-bg-card: #12121a;
  --color-border: #1e1e2e;
  --color-text: #e4e4e7;
  --color-text-muted: #a1a1aa;
  --color-text-dim: #71717a;
}
```

Note: Tailwind v4 uses `@import 'tailwindcss'` instead of the v3 directives `@tailwind base; @tailwind components; @tailwind utilities;`. The `@theme` block registers custom CSS properties that Tailwind can reference.

Additional global styles include:
- `scroll-behavior: smooth` for anchor link navigation
- Custom scrollbar styling (6px width, matching dark theme)
- `.stat-number` class with `font-variant-numeric: tabular-nums` for aligned numerical displays

## 10. The D3 Chart Pattern

Every chart in the dashboard follows the same structural pattern. Understanding this pattern once means you understand all 15+ charts.

### The Complete Pattern

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import * as d3 from 'd3';
  import { COLORS, VERONESE } from '$lib/utils/colors';
  import type { SomeDataType } from '$lib/types';

  // 1. Receive data via $props()
  let { data }: { data: SomeDataType[] } = $props();

  // 2. Bind to a container element
  let container: HTMLDivElement;

  // 3. The draw function: clear, measure, render
  function draw() {
    if (!container || !data.length) return;

    // Clear previous render
    d3.select(container).selectAll('*').remove();

    // Measure container
    const margin = { top: 20, right: 20, bottom: 40, left: 60 };
    const width = container.clientWidth;
    const height = 400;
    const innerW = width - margin.left - margin.right;
    const innerH = height - margin.top - margin.bottom;

    // Create SVG
    const svg = d3.select(container)
      .append('svg')
      .attr('width', width)
      .attr('height', height);

    // Create inner group with margin transform
    const g = svg.append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`);

    // Build scales
    const x = d3.scaleTime()
      .domain(/* ... */)
      .range([0, innerW]);

    const y = d3.scaleLinear()
      .domain(/* ... */)
      .range([innerH, 0]);

    // Render data elements (lines, areas, circles, etc.)
    // ...

    // Render axes with dark theme styling
    g.append('g')
      .attr('transform', `translate(0,${innerH})`)
      .call(d3.axisBottom(x))
      .selectAll('text')
      .attr('fill', COLORS.textMuted)
      .style('font-size', '11px');

    g.selectAll('.domain').attr('stroke', COLORS.axis);
    g.selectAll('.tick line').attr('stroke', COLORS.axis);
  }

  // 4. Mount: initial draw + ResizeObserver
  onMount(() => {
    draw();
    const ro = new ResizeObserver(() => draw());
    ro.observe(container);
    return () => ro.disconnect();
  });

  // 5. Reactive redraw when data changes
  $effect(() => {
    if (data) draw();
  });
</script>

<!-- 6. Container element with fixed height -->
<div bind:this={container} class="w-full" style="height: 400px"></div>
```

### Key Aspects of the Pattern

**Guard clause**: `if (!container || !data.length) return;` prevents rendering before the DOM is ready or when data has not loaded yet.

**Clear-and-redraw**: `d3.select(container).selectAll('*').remove();` ensures no stale elements from previous renders. This is simpler than D3's enter/update/exit pattern and performs well for the data sizes in this dashboard.

**Container measurement**: `container.clientWidth` is read at render time, not stored in state. This means the chart always fits its container.

**Dark theme axis styling**: After calling `d3.axisBottom()` or `d3.axisLeft()`, the text fill, domain stroke, and tick line stroke are explicitly set to dark-theme colors. D3's defaults assume a white background.

**Dual reactivity**: Both `onMount` (initial render) and `$effect` (data changes) trigger `draw()`. The `ResizeObserver` in `onMount` handles window resizes.

## 11. Component-by-Component Guide

### Section 1: Hero (`HeroSection.svelte`)

**Purpose**: Full-screen landing section with animated GME price counter and key finding teaser.

**Key technique**: The price animation uses `requestAnimationFrame` to smoothly interpolate the displayed price through three phases:

1. **Rising** ($16 to $483, 3 seconds, ease-out cubic): Simulates the squeeze
2. **Pause** (1.5 seconds at $483): "Robinhood restricts trading"
3. **Crash** ($483 to $40, 2 seconds, ease-in quadratic): Post-restriction collapse

The animation loops with a 3-second pause between cycles. Phase tracking via `$state(0)` drives both the displayed label and the color (teal during rise, gold at peak, burgundy during crash).

The hero also features:
- A radial gradient background glow (VERONESE gold, 7% opacity)
- A "Key Finding" callout card
- An animated bounce scroll indicator

**No data dependency**: This component does not consume any store data, so it renders immediately while the data loads.

### Section 2: Timeline (`TimelineChart.svelte`)

**Purpose**: Dual-axis chart showing GME closing price and AFINN sentiment over time.

**Key techniques**:

- **Dual Y-axes**: Left axis (teal) for price, right axis (gold) for sentiment. Two independent `scaleLinear` instances share the same x-axis.
- **Area + line for sentiment**: The sentiment is rendered as both a filled area (15% opacity gold) and a line (70% opacity), creating a "glow" effect.
- **Event markers**: Three vertical dashed lines mark the first surge (Jan 22), peak (Jan 27), and Robinhood restriction (Jan 28).
- **Bisector tooltip**: A transparent overlay rectangle captures `mousemove` events. `d3.bisector` finds the nearest data point by date, and an HTML tooltip (not SVG `<title>`) displays price, sentiment, volume, and comment count.

**Data**: Receives `TimelineRow[]` with `date`, `gme_close`, `afinn_score`, `gme_volume`, `n_comments`.

### Section 3: The Null Result (`NullResultCard.svelte` + `GrangerArrow.svelte`)

**Purpose**: Communicate the key finding with visual impact.

**NullResultCard**: A simple text component with no D3. Uses styled HTML to display "Sentiment did NOT cause returns" with the word "NOT" highlighted in burgundy.

**GrangerArrow**: An SVG-based visualization showing two cards:

1. **Sentiment --> Returns (FAILED)**: Arrow with an X mark drawn over it. Uses VERONESE burgundy (`#67322E`) with 40% opacity border. Shows F-statistics and p-values for both AFINN and WSB directions.

2. **Returns --> Sentiment (SIGNIFICANT)**: Bold arrow without X mark. Uses VERONESE teal (`#2C6B67`) with 40% opacity border. Shows significant p-values.

The component uses `$derived` to filter the Granger results array by direction string, and a fade-in animation (`translate-y-4` to `translate-y-0`) triggered by a `visible` state flag set 300ms after mount.

### Section 4: Regression (`CoefficientPlot.svelte`)

**Purpose**: Forest plot showing regression coefficients with confidence intervals across multiple model specifications.

**Key techniques**:

- **Nested band scales**: `d3.scaleBand()` creates an outer scale for variables and an inner scale for models within each variable. This allows multiple model estimates to be displayed side-by-side for each predictor.
- **Toggle pills**: Interactive buttons filter which models are displayed. Clicking a pill toggles it in the `activeModels` array, which triggers a reactive redraw via `$effect`.
- **Significance encoding**: Filled circles indicate significant coefficients (p < 0.05); hollow circles indicate non-significant ones.
- **Zero line**: A dashed vertical line at x = 0 provides the visual reference for the null hypothesis.
- **CI whiskers**: Each coefficient has horizontal lines from `ci_lower` to `ci_upper` with small vertical caps at each end.

**Model color mapping**: Each model name maps to a specific palette color, defined in a `MODEL_COLORS` record.

**Data**: Receives `RegressionCoef[]` with `variable`, `estimate`, `std_error`, `p_value`, `ci_lower`, `ci_upper`, `model`.

### Section 5: Difference-in-Differences (`EventStudyChart.svelte` + `CumulativeReturns.svelte`)

**Purpose**: Two complementary views of the DiD analysis.

**EventStudyChart**:

- Plots treatment effect coefficients by relative time period (days before/after Jan 28)
- Uses a monotone-interpolated `d3.area` for the confidence band (20% opacity deep teal)
- Treatment shading: A rectangular overlay with 6% opacity burgundy fills the post-treatment region
- Event line: Dashed vertical line at period = 0 labeled "RH Restriction"
- Point encoding: Same filled/hollow convention as the coefficient plot
- The x-axis label explicitly states "Days Relative to Event (Jan 28, 2021)"

The key visual insight: pre-treatment coefficients cluster around zero (parallel trends hold), while post-treatment coefficients drop sharply below zero (the restriction hurt meme stocks).

**CumulativeReturns**:

- Plots cumulative returns for meme stocks (deep teal) vs. control stocks (olive)
- Uses `d3.scaleTime` for the x-axis with parsed date strings
- Event line at January 28 separates pre and post periods
- Group colors are defined in a `GROUP_COLORS` record
- Legend rendered as colored inline spans above the chart

### Section 6: Impulse Response Functions (`IrfChart.svelte`)

**Purpose**: Reusable chart component instantiated 4 times in a 2x2 grid to show all directional IRF combinations.

**Props**: `data` (IrfRow[]), `title` (string), `color` (string). The color prop allows each panel to use a different palette color.

The four panels:
1. AFINN Sentiment --> Returns (gold, VERONESE[3])
2. WSB Sentiment --> Returns (amber, VERONESE[2])
3. Returns --> AFINN Sentiment (teal, VERONESE[6])
4. Returns --> WSB Sentiment (deep teal, VERONESE[7])

**Key technique**: The parent `+page.svelte` pre-filters the IRF data into four subsets using `$derived`:

```ts
let irfAfinnToRet = $derived(irfSentToReturn.filter(
  d => d.impulse === 'AFINN Sentiment'
));
```

Each chart renders:
- A CI band (`d3.area` with `y0` = lower bound, `y1` = upper bound)
- A response line
- Individual data points
- A zero reference line
- Horizon labels in trading days

### Section 7: Emotions (`EmotionRadar.svelte` + `EmotionStream.svelte`)

**EmotionRadar** (Spider/Radar chart):

- Computes average normalized value per emotion across all dates
- Uses `d3.lineRadial()` with `d3.curveLinearClosed` to draw the data polygon
- Renders 5 concentric reference circles and 8 axis lines (one per emotion)
- Labels each axis with the emotion name, colored according to `EMOTION_COLORS`
- Data points are small colored circles at each vertex

**Key math**: The angle for each emotion axis is `(Math.PI * 2 / numEmotions) * index - Math.PI / 2` (the `-Math.PI/2` offset rotates the chart so the first axis points up).

**EmotionStream** (Stacked area chart):

- Pivots the long-format emotion data into wide format (one column per emotion)
- Uses `d3.stack()` with `d3.stackOffsetWiggle` for the streamgraph layout. The wiggle offset minimizes weighted change in slope, producing the characteristic organic shape
- Uses `d3.curveBasis` for smooth interpolation
- Event line at January 28 shows the structural break
- Legend shows all 8 emotion colors

### Section 8: WSB Culture (`EmojiBar.svelte` + `WordCloud.svelte`)

**EmojiBar**:

- Horizontal bar chart for top 20 emojis, sorted by frequency
- Bar color encodes the emoji's sentiment value via a `sentimentColor()` function:
  - sentiment >= 2: teal (bullish)
  - sentiment >= 1: neutral-teal
  - sentiment === 0: olive (neutral)
  - sentiment >= -1: amber (mildly bearish)
  - sentiment < -1: burgundy (bearish)
- Emoji characters rendered as SVG `<text>` elements at 18px font size to the left of each bar
- Count labels displayed to the right of each bar
- Bar height is dynamic (28px per bar + 4px gap), so SVG height scales with data

**WordCloud** (actually a dual-panel horizontal bar chart):

- Splits words into positive and negative by the `sentiment` field
- Takes top 20 of each
- Renders two side-by-side panels:
  - Left panel: positive words (teal bars)
  - Right panel: negative words (burgundy bars)
- Uses a shared x-scale so bar lengths are comparable across panels
- Word labels to the left of each bar, count labels to the right
- Panel headers ("Positive", "Negative") rendered as SVG text above each panel

### Section 9: Robustness (`BootstrapCI.svelte` + `LexiconGrid.svelte`)

**BootstrapCI**:

- Horizontal interval chart showing bootstrap 95% confidence intervals
- Filters out the intercept coefficient
- For each coefficient:
  - A semi-transparent colored rectangle spans from `ci_lower` to `ci_upper`
  - Vertical edge markers at each CI bound
  - A horizontal line connecting the bounds
  - A filled circle at the mean estimate
  - Text annotation: "Includes 0" (olive) if CI crosses zero, "Sig." (teal) if not
- Zero reference line shows the null hypothesis

**LexiconGrid** (Heatmap):

- Matrix layout with models as columns and variables as rows
- Each cell is a rounded rectangle colored by p-value:
  - p < 0.01: teal (highly significant)
  - p < 0.05: neutral-teal
  - p < 0.10: gold (marginally significant)
  - p >= 0.10: dark background (not significant)
- Each cell displays the coefficient in scientific notation and the p-value with significance stars
- Scrollable horizontally if the number of models exceeds the viewport width

### Section 10: Methodology (`MethodologyCards.svelte`)

**Purpose**: Collapsible accordion cards summarizing each analytical step, plus a visual pipeline diagram.

**No D3**: This component uses pure Svelte markup. An array of card objects defines:
- `id`, `title`, `icon` (emoji), `summary` (visible when collapsed), `detail` (visible when expanded)

The four cards cover: Data Collection, Sentiment Lexicons, Statistical Models, and Robustness Checks.

**Accordion behavior**: A single `openCard` state variable (initialized to `null`) tracks which card is expanded. Clicking a card toggles it:

```ts
let openCard = $state<string | null>(null);

function toggle(id: string) {
  openCard = openCard === id ? null : id;
}
```

**Pipeline diagram**: A horizontal flow diagram using styled `<span>` elements connected by arrow characters. Each step uses a different palette color with 12% opacity background and 25% opacity border:

```
Reddit API --> SQLite DB --> Tokenize --> Sentiment --> Merge -->
Regression --> Granger --> DiD --> Robustness
```

### Layout Components

**Nav.svelte**: Fixed-position dot navigation on the right side of the viewport (hidden on screens narrower than `lg` breakpoint). 10 dots, one per section. The active section's dot is larger (3x3 vs 2x2) and gold-colored. Labels appear on hover with a tracking uppercase style.

**ScrollProgress.svelte**: A 3px-tall progress bar fixed at the top of the viewport. Uses a scroll event listener to compute `progress = scrollTop / scrollHeight`. The bar uses a CSS gradient transitioning through burgundy, gold, and teal (the palette's three anchor colors).

**Section.svelte**: Wrapper component described in the Architecture section above. Provides consistent padding (`py-16 md:py-24`), scroll margin (`scroll-mt-16`), and IntersectionObserver integration.

## 12. Data Flow: R to JSON to Dashboard

### The Export Script

The R script `11_export_dashboard.R` runs as the final step of the analysis pipeline. It takes in-memory R objects produced by scripts 01-10 and exports them as JSON files to `thesis-dashboard/static/data/`.

All exports use:
```r
jsonlite::write_json(data, path, pretty = TRUE, auto_unbox = TRUE, na = "null")
```

- `pretty = TRUE`: Human-readable formatting (useful for debugging)
- `auto_unbox = TRUE`: Scalars are written as values, not single-element arrays
- `na = "null"`: R's `NA` becomes JSON `null` (maps to TypeScript `null`)

### The 11 JSON Files

| File | R Source | TypeScript Type | Records |
|------|---------|-----------------|---------|
| `timeline.json` | `master_trading` | `TimelineRow[]` | ~82 rows (one per trading day) |
| `summary_stats.json` | Summary statistics table | `SummaryStatRow[]` | ~10-15 rows |
| `granger.json` | `granger_results` | `GrangerRow[]` | 4 rows (2 directions x 2 lexicons) |
| `regression_coefs.json` | Multiple model objects | `RegressionData` | Nested: coefficients[] + emoji_f_test |
| `did_results.json` | DiD model objects | `DidData` | Nested: event_study[] + did_coefs[] + cumulative_returns[] |
| `irf.json` | IRF objects from VAR | `IrfRow[]` | 44 rows (4 panels x 11 horizons) |
| `emotions.json` | NRC daily sentiment | `EmotionRow[]` | ~960 rows (8 emotions x ~120 days) |
| `emoji_top.json` | `emoji_freq` | `EmojiTopRow[]` | 20 rows |
| `word_contributions.json` | BING word contribution | `WordContribRow[]` | ~40 rows (top 20 positive + top 20 negative) |
| `bootstrap_ci.json` | `bootstrap_ci.csv` | `BootstrapCIRow[]` | ~5-8 rows (one per coefficient) |
| `robustness.json` | Robustness models | `RobustnessData` | Nested: coefficients[] + placebo |

### TypeScript Interface Design

All interfaces are defined in `src/lib/types/index.ts`. Key design decisions:

**R's `broom::tidy()` output uses dot notation** for column names (e.g., `conf.low`, `p.value`, `std.error`). These are valid JSON keys but require special handling in TypeScript:

```ts
export interface EventStudyCoef {
  period: number;
  estimate: number;
  'std.error': number;    // Quoted key
  'conf.low': number;     // Quoted key
  'conf.high': number;    // Quoted key
  'p.value': number;      // Quoted key
  pre_treatment: boolean;
}
```

In D3 accessor functions, these must be accessed with bracket notation:

```ts
// Correct
.y0(d => y(d['conf.low']))

// Wrong -- TypeScript error
.y0(d => y(d.conf.low))
```

**Nested structures** (RegressionData, DidData, RobustnessData) are typed as objects containing arrays, matching the nested JSON structure from R's `list()` output.

### Data Loading

The `data.svelte.ts` store module defines a `loadAllData()` function that fetches all 11 files in parallel:

```ts
export async function loadAllData() {
  const [
    timelineRaw, summaryRaw, grangerRaw, regRaw,
    didRaw, irfRaw, emotionsRaw, emojiRaw,
    wordRaw, bootstrapRaw, robustnessRaw
  ] = await Promise.all([
    loadJSON<TimelineRow[]>('/data/timeline.json'),
    loadJSON<SummaryStatRow[]>('/data/summary_stats.json'),
    loadJSON<GrangerRow[]>('/data/granger.json'),
    loadJSON<RegressionData>('/data/regression_coefs.json'),
    loadJSON<DidData>('/data/did_results.json'),
    loadJSON<IrfRow[]>('/data/irf.json'),
    loadJSON<EmotionRow[]>('/data/emotions.json'),
    loadJSON<EmojiTopRow[]>('/data/emoji_top.json'),
    loadJSON<WordContribRow[]>('/data/word_contributions.json'),
    loadJSON<BootstrapCIRow[]>('/data/bootstrap_ci.json'),
    loadJSON<RobustnessData>('/data/robustness.json')
  ]);

  // Set all stores
  timeline.set(timelineRaw);
  summaryStats.set(summaryRaw);
  granger.set(grangerRaw);
  // ... etc.
  dataLoaded.set(true);
}
```

The `loadJSON` helper is a thin wrapper around `fetch`:

```ts
async function loadJSON<T>(path: string): Promise<T> {
  const res = await fetch(path);
  return res.json();
}
```

### Component Data Access

In `+page.svelte`, stores are unwrapped into local reactive variables:

```ts
let loaded = $derived($dataLoaded);
let tl = $derived($timeline);
let gr = $derived($granger);
let reg = $derived($regressionData);
// ...
```

These are passed to child components via props:

```svelte
<TimelineChart data={tl} />
<GrangerArrow data={gr} />
```

Components receive data using Svelte 5's `$props()`:

```ts
let { data }: { data: TimelineRow[] } = $props();
```

### Formatting Utilities

The `src/lib/utils/formats.ts` module provides D3-based formatters used across all components:

| Function | Format | Example Output |
|----------|--------|----------------|
| `fmtDate` | `d3.timeFormat('%b %d')` | "Jan 28" |
| `fmtDateFull` | `d3.timeFormat('%b %d, %Y')` | "Jan 28, 2021" |
| `fmtComma` | `d3.format(',')` | "14,370,000" |
| `fmtPct` | `d3.format('.1%')` | "2.8%" |
| `fmtPct2` | `d3.format('.2%')` | "2.80%" |
| `fmtSi` | `d3.format('.2s')` | "14M" |
| `fmtDec2` | `d3.format('.2f')` | "0.03" |
| `fmtDec4` | `d3.format('.4f')` | "0.0280" |
| `fmtPvalue` | Custom | "< 0.001" or "0.82" |
| `sigStars` | Custom | "***", "**", "*", or "" |
| `fmtLargeNumber` | Custom | "14.4M" |
| `parseDate` | Custom | Adds "T00:00:00" to avoid timezone issues |

The `parseDate` function appends `T00:00:00` to date strings to force parsing in the local timezone rather than UTC, avoiding the common off-by-one-day bug with `new Date('2021-01-28')`.

## 13. Key Technical Gotchas

### 1. R's broom::tidy() Dot Notation

R's `broom` package produces column names with dots (`conf.low`, `p.value`, `std.error`). These become quoted keys in JSON and require bracket notation in TypeScript:

```ts
// In the type definition
export interface EventStudyCoef {
  'conf.low': number;
  'conf.high': number;
  'p.value': number;
}

// In D3 accessor
const area = d3.area<EventStudyCoef>()
  .y0(d => y(d['conf.low']))
  .y1(d => y(d['conf.high']));

// Point significance check
.attr('fill', d => d['p.value'] < 0.05 ? color : 'none')
```

### 2. Tailwind CSS v4 Import Syntax

Tailwind v4 replaces the three directives with a single import:

```css
/* Tailwind v3 (old) */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Tailwind v4 (new) */
@import 'tailwindcss';
```

Custom theme values use `@theme` instead of `tailwind.config.js`:

```css
@theme {
  --color-bg: #0a0a0f;
}
```

### 3. Svelte 5 Slot Replacement

Svelte 5 replaces `<slot />` with the `{@render children()}` syntax. The children prop must be typed as `Snippet`:

```svelte
<script lang="ts">
  import type { Snippet } from 'svelte';
  let { children }: { children: Snippet } = $props();
</script>

{@render children()}
```

### 4. Page State Import

In Svelte 5, `page` state comes from `$app/state`, not `$app/stores`:

```ts
// Svelte 5
import { page } from '$app/state';

// Svelte 4 (legacy)
import { page } from '$app/stores';
```

### 5. D3 Type Callbacks and noImplicitAny

Many D3 functions accept callbacks with loosely typed parameters. For example, `d3.axisBottom(x).tickFormat()` expects a function that takes `(d: d3.NumberValue, i: number) => string`, but when used with `d3.timeFormat()`, a type cast is needed:

```ts
.call(d3.axisBottom(x).tickFormat(d3.timeFormat('%b %d') as any))
```

Setting `noImplicitAny: false` in `tsconfig.json` prevents these from becoming hard errors while keeping the rest of strict mode active.

### 6. Date Parsing Timezone Bug

`new Date('2021-01-28')` is parsed as UTC midnight, which in negative-UTC timezones becomes the previous day. The fix:

```ts
export function parseDate(s: string): Date {
  return new Date(s + 'T00:00:00');
}
```

Adding `T00:00:00` forces parsing as local time.

### 7. D3 in Svelte: DOM Ownership

D3 and Svelte both want to own the DOM. The solution used throughout this dashboard is to give D3 full control of a container `<div>`, and never use Svelte template syntax inside it. The `bind:this={container}` pattern creates a clean boundary: Svelte manages the container element, D3 manages everything inside it.

### 8. Static Data Path Prefix

JSON files in `static/data/` are served at `/data/` in both development and production. The fetch paths use absolute paths:

```ts
loadJSON<TimelineRow[]>('/data/timeline.json')
```

Do not use relative paths like `./data/timeline.json` because they break when the page URL has nested segments.

## 14. Directory Structure

```
thesis-dashboard/
├── src/
│   ├── app.html                              # HTML shell with emoji favicon
│   ├── app.css                               # Tailwind v4 import + dark theme vars
│   │
│   ├── lib/
│   │   ├── components/
│   │   │   ├── hero/
│   │   │   │   └── HeroSection.svelte        # Animated price counter
│   │   │   ├── timeline/
│   │   │   │   └── TimelineChart.svelte       # Dual-axis price + sentiment
│   │   │   ├── granger/
│   │   │   │   ├── GrangerArrow.svelte        # Causality direction diagram
│   │   │   │   └── NullResultCard.svelte      # Key finding headline
│   │   │   ├── regression/
│   │   │   │   └── CoefficientPlot.svelte     # Forest plot with toggle pills
│   │   │   ├── did/
│   │   │   │   ├── EventStudyChart.svelte     # Period-by-period treatment effects
│   │   │   │   └── CumulativeReturns.svelte   # Meme vs control returns
│   │   │   ├── irf/
│   │   │   │   └── IrfChart.svelte            # Reusable IRF panel (x4)
│   │   │   ├── emotions/
│   │   │   │   ├── EmotionRadar.svelte        # Spider chart (d3.lineRadial)
│   │   │   │   └── EmotionStream.svelte       # Stacked area (d3.stack)
│   │   │   ├── culture/
│   │   │   │   ├── EmojiBar.svelte            # Horizontal emoji bar chart
│   │   │   │   └── WordCloud.svelte           # Dual-panel word contributions
│   │   │   ├── robustness/
│   │   │   │   ├── BootstrapCI.svelte         # CI interval visualization
│   │   │   │   └── LexiconGrid.svelte         # p-value colored heatmap
│   │   │   ├── methodology/
│   │   │   │   └── MethodologyCards.svelte     # Accordion + pipeline diagram
│   │   │   └── layout/
│   │   │       ├── Nav.svelte                 # Fixed dot navigation
│   │   │       ├── ScrollProgress.svelte      # Top progress bar
│   │   │       └── Section.svelte             # IntersectionObserver wrapper
│   │   │
│   │   ├── stores/
│   │   │   └── data.svelte.ts                 # 11 writable stores + loadAllData()
│   │   │
│   │   ├── types/
│   │   │   └── index.ts                       # All TypeScript interfaces
│   │   │
│   │   └── utils/
│   │       ├── colors.ts                      # VERONESE palette + COLORS map
│   │       └── formats.ts                     # D3 formatters + parseDate
│   │
│   └── routes/
│       ├── +layout.ts                         # prerender=true, ssr=false
│       ├── +layout.svelte                     # Data loading + ScrollProgress
│       └── +page.svelte                       # All 10 sections composed
│
├── static/
│   └── data/                                  # 11 JSON files from R pipeline
│       ├── timeline.json
│       ├── summary_stats.json
│       ├── granger.json
│       ├── regression_coefs.json
│       ├── did_results.json
│       ├── irf.json
│       ├── emotions.json
│       ├── emoji_top.json
│       ├── word_contributions.json
│       ├── bootstrap_ci.json
│       └── robustness.json
│
├── build/                                     # Static output (after npm run build)
├── package.json
├── package-lock.json
├── svelte.config.js                           # adapter-static configuration
├── vite.config.ts                             # Tailwind v4 + SvelteKit plugins
├── tsconfig.json                              # noImplicitAny: false
└── GUIDE.md                                   # This file
```

---

## Quick Reference

### Running the Dashboard

```bash
cd thesis-dashboard
npm install          # Install dependencies
npm run dev          # Start dev server at http://localhost:5173
npm run build        # Build static site to build/
npm run preview      # Preview the built site
```

### Regenerating Data

From the project root (not `thesis-dashboard/`):

```bash
# Step 1: Collect Reddit data (if not already done)
python src/python/scrape_pushshift.py

# Step 2: Run the full R pipeline
Rscript -e 'source("src/R/run_all.R")'

# The pipeline's final step (11_export_dashboard.R) writes
# all JSON files to thesis-dashboard/static/data/
```

### Adding a New Chart

1. Create a new `.svelte` file in the appropriate `src/lib/components/` subdirectory
2. Follow the D3 chart pattern from Section 10
3. Define a TypeScript interface in `src/lib/types/index.ts`
4. Add a writable store in `src/lib/stores/data.svelte.ts`
5. Add the JSON fetch to `loadAllData()`
6. Import and render the component in `+page.svelte` inside a `<Section>` wrapper
7. Add the section to the `sections` array in `Nav.svelte`

### Key File Paths

| What | Where |
|------|-------|
| Color palette | `src/lib/utils/colors.ts` |
| Number formatters | `src/lib/utils/formats.ts` |
| TypeScript types | `src/lib/types/index.ts` |
| Data stores | `src/lib/stores/data.svelte.ts` |
| Global CSS | `src/app.css` |
| Page composition | `src/routes/+page.svelte` |
| Static data | `static/data/*.json` |
