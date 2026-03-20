# Support Addon for MOTA with AI

Support addon for MOTA: adds an AI-backed support component and optional ticket-by-email. Configurable via `modules.support` in `vite.config.ts` (merged on install). Uses [typesafe-i18n](https://github.com/ivanhofer/typesafe-i18n) for translations (en, sk, ru, es, ja, pt-br, th, zh-cn).

## Requirements

- SvelteKit project using the **MOTA addon CLI** (e.g. from [dapp-starter](https://github.com/bchainhub/dapp-starter)).
- `src/i18n/<lang>/index.ts` (e.g. typesafe-i18n) for translation merge.
- Optional: `$lib/helpers/siteConfig.ts` and `$lib/server/apiHandler` / `$lib/server/apiError` (or adapt the generated files to your helpers).
- For AI: `AI_API_KEY` and `AI_API_URL` in env; support config in `vite.config.ts` (see [Configuration](#configuration)).

## Install

From your project root:

```bash
npx addon bchainhub/mota-addon-support support install
```

### What gets added

- **Component** — `src/lib/components/support/Support.svelte` and `src/lib/components/support/index.ts` (exports `Support`).
- **API route** — `src/routes/api/[version]/support/ai/+server.ts` (POST handler for the AI chat).
- **Config** — Merged into the `modules` block in `vite.config.ts` under `support` (see [Configuration](#configuration)).
- **Translations** — Merged into `src/i18n/<locale>/index.ts` for en, sk, ru, es, ja, pt-br, th, zh-cn under `modules.support` (only locales that exist in your project are updated).

After install, run your i18n step if needed (e.g. `npx typesafe-i18n --no-watch`).

### Using the component in a route

The addon does **not** add a page or modify your `$components` barrel. To use `<Support />` in a route:

```svelte
<script lang="ts">
  import { Support } from '$components/support';
</script>

<Support />
```

### Example: support page with optional type (ai / ticket) and config gate

Route: `src/routes/[[lang]]/support/[[type]]/+page.svelte` — URL `/support`, `/support/ai`, or `/support/ticket` sets the initial mode.

```svelte
<script lang="ts">
  import { Support } from '$components/support';
  import { page } from '$app/stores';
  import { getSiteConfig } from '$lib/helpers/siteConfig';

  const __cfg = getSiteConfig();
  $: type = $page.params.type || 'ai';
  $: initialMode = (type === 'ticket' ? 'ticket' : 'ai') as 'ai' | 'ticket';
</script>

{#if (__cfg?.modules as { support?: { enabled?: boolean } } | undefined)?.support?.enabled}
  <Support mode={initialMode} />
{/if}
```

You can place `<Support />` on a dedicated support page or inside a layout. The component supports `mode="ai"` (default) and `mode="ticket"`.

## Configuration

Configuration is merged into **`vite.config.ts`** under the **`modules`** block (see MOTA addon docs). The addon expects a `modules.support` object. Your project must expose this to the app (e.g. via `getSiteConfig()` reading from the same config).

Example shape (the addon install merges something like this; you can edit it after install):

```ts
// In vite.config.ts (modules block) or equivalent config your app reads
modules: {
  support: {
    enabled: true,
    email: process.env.PUBLIC_SUPPORT_EMAIL,  // Email used for "send ticket by email"
    requireCoreId: false,
    ai: {
      enabled: true,
      model: 'gpt-4o-mini',
      systemMessage: 'You are a helpful support assistant. …',
      subjects: ['general', 'account', 'technical', 'other'],
      temperature: 0.4,
      maxTokens: 150
    }
  }
}
```

| Option | Type | Description |
| --- | --- | --- |
| `support.enabled` | `boolean` | Master switch for the support feature. |
| `support.email` | `string` | Email used for “send ticket by email”; can come from env (e.g. `PUBLIC_SUPPORT_EMAIL`). |
| `support.requireCoreId` | `boolean` | When `true`, the form shows and requires a valid Core ID (ICAN). |
| `support.ai.enabled` | `boolean` | When `true`, “Ask AI” mode and the `/api/…/support/ai` endpoint are used. |
| `support.ai.model` | `string` | Model name for the AI provider (e.g. `gpt-4o-mini`). |
| `support.ai.systemMessage` | `string` | System prompt for the AI. |
| `support.ai.subjects` | `string[]` | Subject options in the form (e.g. `['general', 'account', 'technical', 'other']`). |
| `support.ai.temperature` | `number` | Sampling temperature. |
| `support.ai.maxTokens` | `number` | Max tokens per response. |

Secrets (e.g. `AI_API_KEY`, `AI_API_URL`) must **not** be in `vite.config.ts`; use SvelteKit `$env/dynamic/private` (or similar) in the API route.

## Uninstall

From your project root:

```bash
npx addon bchainhub/mota-addon-support support uninstall
```

### What gets removed

- The `support` block from `modules` in `vite.config.ts`.
- The `support` translation block from `src/i18n/<locale>/index.ts` for en, sk, ru, es, ja, pt-br, th, zh-cn (matching files present in the project).
- The support component files and the support API route (see addon’s `support/uninstall/_scripts.sh` for exact paths).

After uninstall, remove any manual exports (e.g. `export { Support } from './support';`) from `src/lib/components/index.ts` if you had added them.

Optional flags:

```bash
npx addon bchainhub/mota-addon-support support uninstall --dry-run
npx addon bchainhub/mota-addon-support support uninstall --no-translations
npx addon bchainhub/mota-addon-support support uninstall --no-scripts
npx addon bchainhub/mota-addon-support support uninstall --no-config
```

## Addon options

| Flag | Short | Description |
| --- | --- | --- |
| `--cache` | `-c` | Use cache dir for repo (faster re-runs). |
| `--dry-run` | `-d` | No writes; scripts, config, and _lang steps are skipped. |
| `--no-translations` | `-nt` | Skip _lang processing. |
| `--no-scripts` | `-ns` | Skip _scripts execution. |
| `--no-config` | `-nc` | Skip _config merge. |

## Pinning a version

Append `#<ref>` to the repo to use a tag, branch, or commit:

```bash
npx addon bchainhub/mota-addon-support#v1.0.0 support install
npx addon bchainhub/mota-addon-support#main support uninstall
```

## License

Licensed under the MIT License.
