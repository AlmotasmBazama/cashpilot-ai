#!/usr/bin/env node

'use strict';

const path = require('node:path');
const { execFileSync } = require('node:child_process');
const {
  createProductionAdapter,
} = require('./android_cashpilot_acceptance_support.cjs');

const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const projectId = 'cashpilot-ai-a6b49';
const adbExecutable = path.join(
  process.env.LOCALAPPDATA,
  'Android',
  'Sdk',
  'platform-tools',
  'adb.exe',
);
const adapter = createProductionAdapter();

function adb(args, capture = false) {
  return execFileSync(adbExecutable, ['-s', deviceId, ...args], {
    encoding: capture ? 'utf8' : undefined,
    stdio: capture ? ['ignore', 'pipe', 'ignore'] : 'ignore',
  });
}

async function main() {
  let raw;
  let uid;
  let email;
  let cloud;
  try {
    const preferenceFiles = adb(
      ['shell', 'run-as', packageName, 'ls', '-1', 'shared_prefs'],
      true,
    )
      .trim()
      .split(/\r?\n/);
    const authStores = preferenceFiles.filter((name) =>
      /^com\.google\.firebase\.auth\.api\.Store\.[A-Za-z0-9+=_-]+\.xml$/.test(
        name,
      ),
    );
    if (authStores.length !== 1) {
      throw new Error('stale_session_shape_invalid');
    }
    raw = adb(
      ['shell', 'run-as', packageName, 'cat', `shared_prefs/${authStores[0]}`],
      true,
    );
    const uids = [...new Set(raw.match(/cp-restart-[0-9a-f]{16}/g) || [])];
    if (uids.length !== 1) {
      throw new Error('stale_session_shape_invalid');
    }
    uid = uids[0];
    email = `cp-${uid.slice('cp-restart-'.length)}@example.com`;
    cloud = await adapter.loadCloudCredentials();
    const query = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:query`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${cloud.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expression: [{ userId: uid }], limit: '1' }),
        signal: AbortSignal.timeout(15_000),
      },
    );
    const queryBody = await query.json().catch(() => null);
    if (!query.ok || (queryBody?.userInfo || []).length !== 0) {
      throw new Error('stale_session_auth_not_absent');
    }
    const now = new Date().toISOString();
    const profileUrl =
      `https://firestore.googleapis.com/v1/projects/${projectId}` +
      `/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
    const create = await fetch(`${profileUrl}?currentDocument.exists=false`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        fields: {
          uid: { stringValue: uid },
          name: { stringValue: 'CashPilot Restart Acceptance' },
          email: { stringValue: email },
          currency: { stringValue: 'LYD' },
          language: { stringValue: 'en' },
          country: { stringValue: 'LY' },
          timezone: { stringValue: 'Africa/Tripoli' },
          createdAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
          lastLogin: { timestampValue: now },
        },
      }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!create.ok) throw new Error('stale_session_profile_create_failed');
    adb(['shell', 'am', 'force-stop', packageName]);
    await adapter.launchFromLauncher(deviceId);
    await new Promise((resolve) => setTimeout(resolve, 8_000));
    const signedOut = await adapter.logout(deviceId);
    if (!signedOut) throw new Error('stale_session_logout_failed');
    process.stdout.write('STALE_SESSION_RECOVERY complete=true dataCleared=false\n');
  } finally {
    if (cloud && uid) {
      await adapter.deleteSyntheticProfile(cloud, { localId: uid }).catch(
        () => false,
      );
    }
    raw = undefined;
    uid = undefined;
    email = undefined;
    if (cloud) cloud.accessToken = undefined;
    cloud = undefined;
  }
}

main().catch((error) => {
  const allowed = new Set([
    'stale_session_shape_invalid',
    'stale_session_identity_mismatch',
    'stale_session_auth_not_absent',
    'stale_session_profile_create_failed',
    'stale_session_logout_failed',
  ]);
  process.stdout.write(
    `STALE_SESSION_RECOVERY complete=false code=${
      allowed.has(error?.message) ? error.message : 'recovery_failed'
    }\n`,
  );
  process.exitCode = 1;
});
