import { generateKeyPairSync, verify } from 'node:crypto';
import test from 'node:test';
import assert from 'node:assert/strict';

import { createServiceAccountJwt, createTrackPayload } from './google-play-upload.mjs';

test('createServiceAccountJwt creates a signed one-hour Android Publisher assertion', () => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const now = 1_700_000_000;
  const jwt = createServiceAccountJwt({
    client_email: 'play-uploader@example.iam.gserviceaccount.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  }, now);
  const [encodedHeader, encodedClaims, encodedSignature] = jwt.split('.');

  assert.deepEqual(JSON.parse(Buffer.from(encodedHeader, 'base64url')), { alg: 'RS256', typ: 'JWT' });
  assert.deepEqual(JSON.parse(Buffer.from(encodedClaims, 'base64url')), {
    iss: 'play-uploader@example.iam.gserviceaccount.com',
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  assert.equal(
    verify('RSA-SHA256', Buffer.from(`${encodedHeader}.${encodedClaims}`), publicKey, Buffer.from(encodedSignature, 'base64url')),
    true,
  );
});

test('createTrackPayload formats the immutable versionCode for the configured track', () => {
  assert.deepEqual(createTrackPayload('qa', 80, 'completed'), {
    track: 'qa',
    releases: [{ status: 'completed', versionCodes: ['80'] }],
  });
});

test('createTrackPayload rejects missing tracks and unsupported statuses', () => {
  assert.throws(() => createTrackPayload('', 80, 'completed'), /track must not be empty/);
  assert.throws(() => createTrackPayload('qa', 80, 'published'), /Invalid Google Play release status/);
});
