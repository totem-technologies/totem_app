#!/usr/bin/env node

import { createSign } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const oauthTokenUrl = 'https://oauth2.googleapis.com/token';
const publisherBaseUrl = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const publisherUploadBaseUrl = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3';
const androidPublisherScope = 'https://www.googleapis.com/auth/androidpublisher';
const releaseStatuses = new Set(['completed', 'draft', 'halted', 'inProgress']);

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

export function createServiceAccountJwt(credentials, now = Math.floor(Date.now() / 1000)) {
  if (!credentials?.client_email || !credentials?.private_key) {
    throw new Error('Service-account JSON must contain client_email and private_key.');
  }

  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: androidPublisherScope,
    aud: oauthTokenUrl,
    iat: now,
    exp: now + 3600,
  }));
  const unsignedJwt = `${header}.${claims}`;
  const signature = createSign('RSA-SHA256').update(unsignedJwt).end().sign(credentials.private_key);
  return `${unsignedJwt}.${signature.toString('base64url')}`;
}

export function createTrackPayload(track, versionCode, status) {
  if (!track) throw new Error('Google Play track must not be empty.');
  if (!releaseStatuses.has(status)) {
    throw new Error(`Invalid Google Play release status "${status}". Expected one of: ${[...releaseStatuses].join(', ')}.`);
  }
  if (!Number.isInteger(versionCode) || versionCode <= 0) {
    throw new Error('Google Play returned an invalid versionCode.');
  }

  return {
    track,
    releases: [{ status, versionCodes: [String(versionCode)] }],
  };
}

function parseArguments(args) {
  const values = {};
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index];
    const value = args[index + 1];
    if (!key?.startsWith('--') || value === undefined) {
      throw new Error('Usage: google-play-upload.mjs --aab <path> --package-name <id> --track <track> --status <status>');
    }
    values[key.slice(2)] = value;
  }

  for (const key of ['aab', 'package-name', 'track', 'status']) {
    if (!values[key]) throw new Error(`Missing required argument --${key}.`);
  }
  return values;
}

async function readJsonResponse(response, operation) {
  const text = await response.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { rawResponse: text };
  }
  if (!response.ok) {
    const detail = body?.error?.message ?? body?.error_description ?? body?.rawResponse ?? 'No response body';
    throw new Error(`${operation} failed (${response.status}): ${detail}`);
  }
  return body;
}

async function requestAccessToken(credentials, fetchImpl) {
  const response = await fetchImpl(oauthTokenUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: createServiceAccountJwt(credentials),
    }),
  });
  const body = await readJsonResponse(response, 'Google OAuth token exchange');
  if (!body.access_token) throw new Error('Google OAuth response did not contain an access token.');
  return body.access_token;
}

async function apiRequest(fetchImpl, accessToken, url, operation, options = {}) {
  const response = await fetchImpl(url, {
    ...options,
    headers: {
      authorization: `Bearer ${accessToken}`,
      ...options.headers,
    },
  });
  return readJsonResponse(response, operation);
}

export async function uploadToGooglePlay({ aabPath, packageName, track, status, credentials, fetchImpl = fetch }) {
  createTrackPayload(track, 1, status);
  const encodedPackage = encodeURIComponent(packageName);
  const accessToken = await requestAccessToken(credentials, fetchImpl);
  let editId;
  let committed = false;

  try {
    const edit = await apiRequest(
      fetchImpl,
      accessToken,
      `${publisherBaseUrl}/applications/${encodedPackage}/edits`,
      'Create Google Play edit',
      { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' },
    );
    editId = edit.id;
    if (!editId) throw new Error('Google Play did not return an edit ID.');

    const bundle = await apiRequest(
      fetchImpl,
      accessToken,
      `${publisherUploadBaseUrl}/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}/bundles?uploadType=media`,
      'Upload Android App Bundle',
      { method: 'POST', headers: { 'content-type': 'application/octet-stream' }, body: await readFile(aabPath) },
    );
    const versionCode = Number(bundle.versionCode);

    // Google Play releases are transactional: assign the uploaded bundle inside
    // the edit, then commit that edit to make the track change visible.
    await apiRequest(
      fetchImpl,
      accessToken,
      `${publisherBaseUrl}/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}/tracks/${encodeURIComponent(track)}`,
      'Update Google Play track',
      {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(createTrackPayload(track, versionCode, status)),
      },
    );

    await apiRequest(
      fetchImpl,
      accessToken,
      `${publisherBaseUrl}/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}:commit`,
      'Commit Google Play edit',
      { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' },
    );
    committed = true;
    console.log(`Uploaded versionCode ${versionCode} for ${packageName} to track "${track}" with status "${status}".`);
  } finally {
    if (editId && !committed) {
      try {
        await apiRequest(
          fetchImpl,
          accessToken,
          `${publisherBaseUrl}/applications/${encodedPackage}/edits/${encodeURIComponent(editId)}`,
          'Delete abandoned Google Play edit',
          { method: 'DELETE' },
        );
      } catch (cleanupError) {
        console.error(`Warning: ${cleanupError.message}`);
      }
    }
  }
}

async function main() {
  const args = parseArguments(process.argv.slice(2));
  const rawCredentials = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!rawCredentials) throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not set.');

  let credentials;
  try {
    credentials = JSON.parse(rawCredentials);
  } catch {
    throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not valid JSON.');
  }

  await uploadToGooglePlay({
    aabPath: args.aab,
    packageName: args['package-name'],
    track: args.track,
    status: args.status,
    credentials,
  });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`Google Play upload failed: ${error.message}`);
    process.exitCode = 1;
  });
}
