#!/usr/bin/env node

'use strict';

const crypto = require('node:crypto');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const {
  createProductionAdapter,
} = require('./android_cashpilot_acceptance_support.cjs');

const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const projectId = 'cashpilot-ai-a6b49';
const remoteDump = '/data/local/tmp/cashpilot_provider_cleanup.xml';
const adapter = createProductionAdapter();
const adbExecutable = path.join(
  process.env.LOCALAPPDATA,
  'Android',
  'Sdk',
  'platform-tools',
  'adb.exe',
);

let cloud;
let candidates = [];

function marker(name, fields = {}) {
  const values = Object.entries(fields).map(([key, value]) => `${key}=${value}`);
  process.stdout.write(`ACCOUNT_DELETION_PROVIDER_${name} ${values.join(' ')}\n`);
}

function adb(args, { capture = false } = {}) {
  return execFileSync(adbExecutable, ['-s', deviceId, ...args], {
    encoding: capture ? 'utf8' : undefined,
    stdio: capture ? ['ignore', 'pipe', 'ignore'] : 'ignore',
  });
}

function attributes(tag) {
  return Object.fromEntries(
    [...tag.matchAll(/([A-Za-z0-9_-]+)="([^"]*)"/g)].map((match) => [
      match[1],
      match[2],
    ]),
  );
}

function nodes(xml) {
  return [...xml.matchAll(/<node\b[^>]*>/g)].map((match) =>
    attributes(match[0]),
  );
}

function snapshot() {
  adb(['shell', 'uiautomator', 'dump', remoteDump]);
  const xml = adb(['exec-out', 'cat', remoteDump], { capture: true });
  if (typeof xml !== 'string' || xml.length < 100 || xml.length > 1024 * 1024) {
    throw new Error('ui_snapshot_invalid');
  }
  return nodes(xml);
}

function point(node) {
  const match = node?.bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
  if (!match) throw new Error('ui_bounds_invalid');
  return {
    x: Math.floor((Number(match[1]) + Number(match[3])) / 2),
    y: Math.floor((Number(match[2]) + Number(match[4])) / 2),
  };
}

function tap(node) {
  const target = point(node);
  adb(['shell', 'input', 'tap', String(target.x), String(target.y)]);
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitFor(predicate, safeCode, timeoutMs = 90_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    const value = predicate(snapshot());
    if (value) return value;
    await wait(500);
  }
  throw new Error(safeCode);
}

function description(node) {
  return node?.['content-desc'] || '';
}

function descriptionIs(node, values) {
  return values.includes(description(node));
}

function clearFocused() {
  adb([
    'shell',
    'input',
    'keycombination',
    'KEYCODE_CTRL_LEFT',
    'KEYCODE_A',
  ]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_DEL']);
}

function inputEmail(value) {
  let segment = '';
  const flush = () => {
    if (segment === '') return;
    adb(['shell', 'input', 'text', segment]);
    segment = '';
  };
  for (const character of value) {
    if (character === '@' || character === '.') {
      flush();
      adb([
        'shell',
        'input',
        'keyevent',
        character === '@' ? 'KEYCODE_AT' : 'KEYCODE_PERIOD',
      ]);
    } else {
      segment += character;
    }
  }
  flush();
}

async function queryExactCandidates() {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:query`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        expression: [{ displayName: 'CashPilot Restart Acceptance' }],
        limit: '100',
      }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  const body = await response.json().catch(() => null);
  if (!response.ok || !Array.isArray(body?.userInfo)) {
    throw new Error('synthetic_query_failed');
  }
  return body.userInfo
    .filter(
      (user) =>
        /^cp-restart-[0-9a-f]{16}$/.test(user?.localId || '') &&
        /^cp-[0-9a-f]{16}@example\.com$/.test(user?.email || '') &&
        user?.displayName === 'CashPilot Restart Acceptance',
    )
    .map((user) => ({
      localId: user.localId,
      email: user.email,
      password: `cp9${crypto.randomBytes(8).toString('hex')}`,
    }));
}

async function resetCandidatePassword(candidate) {
  const response = await fetch(
    'https://identitytoolkit.googleapis.com/v1/accounts:update',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        localId: candidate.localId,
        password: candidate.password,
        targetProjectId: projectId,
      }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!response.ok) throw new Error('synthetic_password_reset_failed');
}

function candidateForEmail(email) {
  return candidates.find((candidate) => candidate.email === email);
}

async function openDeletionDialogFromContinuation() {
  const action = await waitFor(
    (state) =>
      state.find(
        (node) =>
          node.class === 'android.widget.Button' &&
          descriptionIs(node, ['Delete account?', 'حذف الحساب']),
      ),
    'continuation_action_missing',
  );
  tap(action);
  return waitFor(
    (state) => {
      const fields = state.filter(
        (node) => node.class === 'android.widget.EditText',
      );
      const checkbox = state.find(
        (node) => node.class === 'android.widget.CheckBox',
      );
      return fields.length >= 2 && checkbox ? { fields, checkbox } : null;
    },
    'continuation_dialog_missing',
  );
}

async function submitDeletionDialog(dialog, expectedCandidate) {
  const emailField = dialog.fields.find((node) => node.password !== 'true');
  const passwordField = dialog.fields.find((node) => node.password === 'true');
  const dialogEmail = emailField?.text || '';
  if (
    !emailField ||
    !passwordField ||
    candidateForEmail(dialogEmail) !== expectedCandidate
  ) {
    throw new Error('dialog_target_mismatch');
  }
  tap(passwordField);
  clearFocused();
  adb(['shell', 'input', 'text', expectedCandidate.password]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  await wait(300);
  let state = snapshot();
  const checkbox = state.find(
    (node) => node.class === 'android.widget.CheckBox',
  );
  if (!checkbox) throw new Error('deletion_confirmation_missing');
  tap(checkbox);
  await wait(300);
  state = snapshot();
  const checked = state.some(
    (node) =>
      node.class === 'android.widget.CheckBox' && node.checked === 'true',
  );
  const submit = state.find(
    (node) =>
      node.class === 'android.widget.Button' &&
      node.clickable === 'true' &&
      node.enabled === 'true' &&
      descriptionIs(node, ['Delete', 'حذف']),
  );
  if (!checked || !submit) throw new Error('deletion_submit_missing');
  tap(submit);
  await waitFor(
    (current) => {
      const signedOut = current.some(
        (node) =>
          node.clickable === 'true' &&
          descriptionIs(node, ['Login', 'تسجيل الدخول']),
      );
      const financialShell = current.some(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          descriptionIs(node, ['Home', 'الرئيسية']),
      );
      return signedOut && !financialShell;
    },
    'authoritative_deletion_incomplete',
    150_000,
  );
}

async function reachLoginScreen() {
  return waitFor(
    (state) => {
      const fields = state.filter(
        (node) => node.class === 'android.widget.EditText',
      );
      if (fields.length >= 2) return fields;
      const login = state.find(
        (node) =>
          node.clickable === 'true' &&
          descriptionIs(node, ['Login', 'تسجيل الدخول']),
      );
      if (login) tap(login);
      return null;
    },
    'login_fields_missing',
  );
}

async function login(candidate) {
  const fields = await reachLoginScreen();
  tap(fields[0]);
  clearFocused();
  inputEmail(candidate.email);
  tap(fields[1]);
  clearFocused();
  adb(['shell', 'input', 'text', candidate.password]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  await wait(300);
  const submit = snapshot().find(
    (node) =>
      node.clickable === 'true' &&
      node.enabled === 'true' &&
      descriptionIs(node, ['Login', 'تسجيل الدخول']),
  );
  if (!submit) throw new Error('login_submit_missing');
  tap(submit);
  await waitFor(
    (state) =>
      state.find(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          descriptionIs(node, ['Settings', 'الإعدادات']),
      ),
    'authenticated_shell_missing',
    120_000,
  );
}

async function openDeletionDialogFromSettings() {
  const settings = await waitFor(
    (state) =>
      state.find(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          descriptionIs(node, ['Settings', 'الإعدادات']),
      ),
    'settings_nav_missing',
  );
  tap(settings);
  await wait(500);
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const state = snapshot();
    const action = state.find(
      (node) =>
        node.clickable === 'true' &&
        (description(node).startsWith('Delete account') ||
          description(node).startsWith('حذف الحساب')),
    );
    if (action) {
      tap(action);
      return waitFor(
        (current) => {
          const fields = current.filter(
            (node) => node.class === 'android.widget.EditText',
          );
          const checkbox = current.find(
            (node) => node.class === 'android.widget.CheckBox',
          );
          return fields.length >= 2 && checkbox ? { fields, checkbox } : null;
        },
        'settings_deletion_dialog_missing',
      );
    }
    adb(['shell', 'input', 'swipe', '540', '1800', '540', '900', '350']);
    await wait(300);
  }
  throw new Error('settings_delete_action_missing');
}

function currentDeletionDialog() {
  const state = snapshot();
  const fields = state.filter(
    (node) => node.class === 'android.widget.EditText',
  );
  const checkbox = state.find(
    (node) => node.class === 'android.widget.CheckBox',
  );
  return fields.length >= 2 && checkbox ? { fields, checkbox } : null;
}

async function authAbsent(candidate) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:query`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        expression: [{ userId: candidate.localId }],
        limit: '1',
      }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  const body = await response.json().catch(() => null);
  return response.ok && (!Array.isArray(body?.userInfo) || body.userInfo.length === 0);
}

async function cloudTreeEmpty(candidate) {
  const base =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/users/${encodeURIComponent(candidate.localId)}`;
  const headers = { Authorization: `Bearer ${cloud.accessToken}` };
  const [root, collections] = await Promise.all([
    fetch(base, {
      method: 'GET',
      headers,
      signal: AbortSignal.timeout(15_000),
    }),
    fetch(`${base}:listCollectionIds`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ pageSize: 100 }),
      signal: AbortSignal.timeout(15_000),
    }),
  ]);
  const collectionBody = await collections.json().catch(() => null);
  return (
    root.status === 404 &&
    collections.ok &&
    (!Array.isArray(collectionBody?.collectionIds) ||
      collectionBody.collectionIds.length === 0) &&
    !collectionBody?.nextPageToken
  );
}

async function permanentLockPresent(candidate) {
  const lockId = crypto
    .createHash('sha256')
    .update(candidate.localId, 'utf8')
    .digest('hex')
    .toUpperCase();
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/accountDeletionLocks/${lockId}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${cloud.accessToken}` },
    signal: AbortSignal.timeout(15_000),
  });
  return response.ok;
}

async function verifyDeleted(candidate, label) {
  const [auth, tree, lock] = await Promise.all([
    authAbsent(candidate),
    cloudTreeEmpty(candidate),
    permanentLockPresent(candidate),
  ]);
  marker('ZERO_VERIFICATION', {
    target: label,
    authAbsent: auth,
    cloudTreeEmpty: tree,
    permanentFencePresent: lock,
  });
  if (!auth || !tree || !lock) throw new Error('zero_verification_failed');
}

async function main() {
  try {
    cloud = await adapter.loadCloudCredentials();
    candidates = await queryExactCandidates();
    if (candidates.length !== 1 && candidates.length !== 2) {
      throw new Error('synthetic_scope_invalid');
    }
    marker('DISCOVERY', {
      exactSyntheticAccounts: candidates.length,
      quarantinedOperationsFromPriorEvidence: candidates.length === 2 ? 1 : 0,
      untouchedControlsFromPriorEvidence: 1,
    });
    await Promise.all(candidates.map(resetCandidatePassword));
    marker('PASSWORD_RECOVERY', { scopedAccounts: candidates.length });

    if (candidates.length === 1) {
      const control = candidates[0];
      const controlDialog = currentDeletionDialog();
      if (!controlDialog) throw new Error('settings_deletion_dialog_missing');
      await submitDeletionDialog(controlDialog, control);
      await verifyDeleted(control, 'priorControl');
      marker('PRIOR_CONTROL_COMPLETION', { complete: true });
      marker('RESULT', { complete: true, syntheticAccountsRemaining: 0 });
      return;
    }

    const continuationDialog = await openDeletionDialogFromContinuation();
    const activeEmail =
      continuationDialog.fields.find((node) => node.password !== 'true')?.text ||
      '';
    const quarantined = candidateForEmail(activeEmail);
    if (!quarantined) throw new Error('continuation_target_not_synthetic');
    await submitDeletionDialog(continuationDialog, quarantined);
    await verifyDeleted(quarantined, 'quarantined');
    marker('QUARANTINED_COMPLETION', { complete: true });

    const control = candidates.find((candidate) => candidate !== quarantined);
    if (!control) throw new Error('control_target_missing');
    await login(control);
    const controlDialog = await openDeletionDialogFromSettings();
    await submitDeletionDialog(controlDialog, control);
    await verifyDeleted(control, 'priorControl');
    marker('PRIOR_CONTROL_COMPLETION', { complete: true });
    marker('RESULT', { complete: true, syntheticAccountsRemaining: 0 });
  } finally {
    try {
      adb(['shell', 'rm', '-f', remoteDump]);
    } catch {
      // Best-effort removal of a credential-bearing UI snapshot.
    }
    for (const candidate of candidates) {
      candidate.email = undefined;
      candidate.password = undefined;
      candidate.localId = undefined;
    }
    candidates = [];
    if (cloud) cloud.accessToken = undefined;
    cloud = undefined;
  }
}

const allowedErrors = new Set([
  'ui_snapshot_invalid',
  'ui_bounds_invalid',
  'synthetic_query_failed',
  'synthetic_scope_invalid',
  'synthetic_password_reset_failed',
  'continuation_action_missing',
  'continuation_dialog_missing',
  'continuation_target_not_synthetic',
  'dialog_target_mismatch',
  'deletion_confirmation_missing',
  'deletion_submit_missing',
  'authoritative_deletion_incomplete',
  'login_fields_missing',
  'login_submit_missing',
  'authenticated_shell_missing',
  'settings_nav_missing',
  'settings_deletion_dialog_missing',
  'settings_delete_action_missing',
  'control_target_missing',
  'zero_verification_failed',
]);

main().catch((error) => {
  marker('FAILURE', {
    code: allowedErrors.has(error?.message) ? error.message : 'cleanup_failed',
  });
  process.exitCode = 1;
});
