import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';
import { releaseDownload, verifyArchive } from '../scripts/sync-release.mjs';
const zip = Buffer.from('504b03040000', 'hex');
const release = { tag_name: 'v0.6.42', draft: false, prerelease: false, assets: [{ name: 'CoderBar-macos.zip', state: 'uploaded', size: zip.length, browser_download_url: 'https://github.com/monomadic/CoderBar/releases/download/v0.6.42/CoderBar-macos.zip', digest: `sha256:${createHash('sha256').update(zip).digest('hex')}` }] };
test('version, immutable download URL, and size come from the same release asset', () => {
  const metadata = releaseDownload(release);
  assert.equal(metadata.version, '0.6.42');
  assert.equal(metadata.bytes, zip.length);
  assert.equal(metadata.label, '0.0 MB');
  verifyArchive(zip, metadata);
});
test('rejects incomplete, prerelease, or corrupt downloads before publishing', () => {
  assert.throws(() => releaseDownload({ ...release, prerelease: true }));
  assert.throws(() => releaseDownload({ ...release, assets: [] }));
  assert.throws(() => verifyArchive(zip.subarray(0, 4), releaseDownload(release)));
  assert.throws(() => verifyArchive(Buffer.from('504b03040101', 'hex'), releaseDownload(release)));
});
