# CoderBar website

The product site for CoderBar. It uses vinext and produces a Cloudflare Worker-compatible build.

## Local development

```bash
npm install
npm run dev
npm run build
npm test
```

Node.js 22.13 or newer is required.

Product content lives in `app/page.tsx`, visual tokens and responsive layouts live in `app/globals.css`, and downloadable product assets live in `public/`.

## Current design

Uses the Space Chocolate / Classic Red CoderBar artwork from
`Resources/IconConcepts/14-space-chocolate-coderbar.png` in the parent repository.
The hero, navigation icon, and social artwork share that branding. The actual
installed-app screenshot is `public/product/coderbar-current-expanded.png`;
the minimized panel is a labeled illustration built in HTML/CSS.

Product copy follows the root README: notch-aware layout, stable project colors,
configurable timings, local integrations, and bounded discovery caches.
Release and source links point to `monomadic/CoderBar`.

The existing Sites identity is retained in `.openai/hosting.json`. Publishing
requires editor access to that project; GitHub source pushes alone do not
publish a Sites deployment.

## GitHub Pages

The public site is deployed to https://monomadic.github.io/CoderBar/ by
`.github/workflows/pages.yml` when website changes land on `main`.
Run `npm run build:pages` to build and validate the static output in `pages-dist/`.
The exporter renders the same production page, removes unnecessary hydration
scripts, and prefixes local assets for the repository path. Ordinary anchors
and release links work without JavaScript.
