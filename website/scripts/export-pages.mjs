import assert from 'node:assert/strict';
import { cp, mkdir, readFile, rm, writeFile, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import worker from '../dist/server/index.js';

// This landing page has no client-side interactions beyond ordinary links.
// Render the production page once so Pages needs neither a Worker nor hydration.
const base = process.env.PAGES_BASE_PATH ?? '/CoderBar';
assert.match(base, /^\/[A-Za-z0-9_-]+$/);
const origin = process.env.PAGES_ORIGIN ?? 'https://monomadic.github.io';
const output = new URL('../pages-dist/', import.meta.url);
const response = await worker.fetch(new Request(`${origin}/`, {
  headers: { accept: 'text/html', 'x-forwarded-host': new URL(origin).host, 'x-forwarded-proto': 'https' },
}), { ASSETS: { fetch: async () => new Response('Not found', { status: 404 }) } }, {
  waitUntil() {}, passThroughOnException() {},
});
assert.equal(response.status, 200);
let html = await response.text();
html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
  .replace(/<link\b[^>]*rel="(?:modulepreload|preload)"[^>]*>/gi, '')
  .replace(/\b(href|src)="\/(?!\/)([^"]*)"/g, `$1="${base}/$2"`)
  .replaceAll(`${origin}/og.png`, `${origin}${base}/og.png`);
assert.match(html, /Your agents, a glance away/);
assert.doesNotMatch(html, /<script\b/i);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await cp(new URL('../dist/client/', import.meta.url), output, { recursive: true });
await writeFile(new URL('index.html', output), html);
await writeFile(new URL('.nojekyll', output), '');
// Validate local assets before upload, including the stylesheet and screenshots.
for (const [, target] of html.matchAll(/(?:src|href)="([^"#]+)"/g)) {
  if (!target.startsWith(`${base}/`)) continue;
  await access(new URL(target.slice(base.length + 1).split('?')[0], output));
}
const styles = [...html.matchAll(/<link[^>]*href="([^"]+\.css)"/g)];
assert.ok(styles.length, 'Static export must include the compiled stylesheet');
for (const [, target] of styles) {
  assert.ok((await readFile(new URL(target.slice(base.length + 1), output))).length);
}
console.log(`Validated GitHub Pages export: ${fileURLToPath(output)}`);
