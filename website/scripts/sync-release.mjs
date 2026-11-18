import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const repo = 'monomadic/CoderBar';
export function releaseDownload(release) {
  assert.ok(!release.draft && !release.prerelease, 'Only stable published releases are downloads');
  assert.match(release.tag_name, /^v?\d+\.\d+\.\d+$/);
  const asset = release.assets.find(asset => asset.name === 'CoderBar-macos.zip');
  assert.ok(asset?.size > 0 && asset.state === 'uploaded', 'Release must contain a complete CoderBar-macos.zip');
  const url = `https://github.com/${repo}/releases/download/${release.tag_name}/CoderBar-macos.zip`;
  assert.equal(asset.browser_download_url, url);
  return { version: release.tag_name.replace(/^v/, ''), bytes: asset.size,
    label: `${(asset.size / 1_000_000).toFixed(1)} MB`, url,
    ...(asset.digest ? { digest: asset.digest } : {}) };
}
export function verifyArchive(bytes, metadata) {
  assert.equal(bytes.length, metadata.bytes, 'Release archive size mismatch');
  assert.equal(bytes.subarray(0, 4).toString('hex'), '504b0304', 'Expected a ZIP archive');
  if (metadata.digest) assert.equal(`sha256:${createHash('sha256').update(bytes).digest('hex')}`, metadata.digest, 'Release archive digest mismatch');
}
async function sync() {
  const headers = { Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
  if (process.env.GH_TOKEN) headers.Authorization = `Bearer ${process.env.GH_TOKEN}`;
  const response = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, { headers, signal: AbortSignal.timeout(30_000) });
  const metadataPath = new URL('../app/download.json', import.meta.url);
  const archivePath = new URL('../public/downloads/CoderBar-macos.zip', import.meta.url);
  if (response.status === 404) {
    // Bootstrap only: keep the verified bundled app until the first release exists.
    const metadata = JSON.parse(await readFile(metadataPath, 'utf8'));
    verifyArchive(await readFile(archivePath), metadata);
    console.log(`No published release yet; retaining bundled v${metadata.version} (${metadata.label}).`);
    return;
  }
  assert.ok(response.ok, `GitHub release lookup failed: ${response.status}`);
  const metadata = releaseDownload(await response.json());
  const archive = await fetch(metadata.url, { signal: AbortSignal.timeout(120_000) });
  assert.ok(archive.ok, `Release download failed: ${archive.status}`);
  const bytes = Buffer.from(await archive.arrayBuffer());
  verifyArchive(bytes, metadata);
  // Build runs only after both writes succeed. Publish the ZIP and its metadata together.
  await writeFile(archivePath, bytes);
  await writeFile(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`);
  console.log(`Website download: v${metadata.version}, ${metadata.label} (${metadata.bytes} bytes)`);
}
if (process.argv[1] === fileURLToPath(import.meta.url)) await sync();
