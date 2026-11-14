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
const remoteDump = '/data/local/tmp/cashpilot_final_cleanup.xml';
const projectId = 'cashpilot-ai-a6b49';
const adapter = createProductionAdapter();

function adb(args, { capture = false } = {}) {
  const executable = path.join(
    process.env.LOCALAPPDATA,
    'Android',
    'Sdk',
    'platform-tools',
    'adb.exe',
  );
  return execFileSync(executable, ['-s', deviceId, ...args], {
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
  if (typeof xml !== 'string' || xml.length < 100) {
    throw new Error('snapshot_invalid');
  }
  return nodes(xml);
}

function point(node) {
  const match = node?.bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
  if (!match) throw new Error('bounds_missing');
  return {
    x: Math.floor((Number(match[1]) + Number(match[3])) / 2),
    y: Math.floor((Number(match[2]) + Number(match[4])) / 2),
  };
}

function tap(node) {
  const target = point(node);
  adb(['shell', 'input', 'tap', String(target.x), String(target.y)]);
}

function marker(name, fields = {}) {
  const values = Object.entries(fields).map(([key, value]) => `${key}=${value}`);
  process.stdout.write(`FINAL_SYNTHETIC_CLEANUP_${name} ${values.join(' ')}\n`);
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

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitFor(predicate, code, timeoutMs = 45_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    const current = snapshot();
    const value = predicate(current);
    if (value) return value;
    await wait(500);
  }
  throw new Error(code);
}

function descriptionStarts(node, value) {
  return (node['content-desc'] || '').startsWith(value);
}

async function openSettingsAccountSection() {
  const settings = await waitFor(
    (current) =>
      current.find(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          descriptionStarts(node, 'الإعدادات') ||
          descriptionStarts(node, 'Settings'),
      ),
    'settings_nav_missing',
  );
  tap(settings);
  await wait(600);
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const current = snapshot();
    const deleteAccount = current.find(
      (node) =>
        node.clickable === 'true' &&
        (descriptionStarts(node, 'حذف الحساب') ||
          descriptionStarts(node, 'Delete account')),
    );
    if (deleteAccount) return { current, deleteAccount };
    adb(['shell', 'input', 'swipe', '540', '1750', '540', '1050', '350']);
    await wait(300);
  }
  throw new Error('delete_account_control_missing');
}

function syntheticEmailFrom(current) {
  const emailPattern = /^cp-[0-9a-f]{16}@example\.com$/;
  for (const node of current) {
    for (const value of [node.text, node['content-desc']]) {
      if (typeof value !== 'string') continue;
      const match = value.match(/cp-[0-9a-f]{16}@example\.com/);
      if (match && emailPattern.test(match[0])) return match[0];
    }
  }
  throw new Error('synthetic_email_missing');
}

async function resetSyntheticPassword(email, password) {
  const cloud = await adapter.loadCloudCredentials();
  const headers = {
    Authorization: `Bearer ${cloud.accessToken}`,
    'Content-Type': 'application/json',
  };
  const query = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:query`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({ expression: [{ email }], limit: '1' }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  const body = await query.json().catch(() => null);
  const user = body?.userInfo?.[0];
  if (
    !query.ok ||
    !user ||
    !/^cp-restart-[0-9a-f]{16}$/.test(user.localId) ||
    user.email !== email
  ) {
    throw new Error('synthetic_scope_invalid');
  }
  const update = await fetch(
    'https://identitytoolkit.googleapis.com/v1/accounts:update',
    {
      method: 'POST',
      headers,
      body: JSON.stringify({
        localId: user.localId,
        password,
        targetProjectId: projectId,
      }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!update.ok) throw new Error('synthetic_password_reset_failed');
}

async function signOutFromSettings(current) {
  const logout = current.find(
    (node) =>
      node.clickable === 'true' &&
      (descriptionStarts(node, 'تسجيل الخروج') ||
        descriptionStarts(node, 'Logout')),
  );
  if (!logout) throw new Error('logout_missing');
  tap(logout);
  await waitFor(
    (state) =>
      state.find(
        (node) =>
          node.clickable === 'true' &&
          (node['content-desc'] === 'تسجيل الدخول' ||
            node['content-desc'] === 'Login'),
      ),
    'welcome_login_missing',
  );
}

async function login(email, password) {
  let current = snapshot();
  let fields = current.filter((node) => node.class === 'android.widget.EditText');
  if (fields.length < 2) {
    const welcomeLogin = current.find(
      (node) =>
        node.clickable === 'true' &&
        (node['content-desc'] === 'تسجيل الدخول' ||
          node['content-desc'] === 'Login'),
    );
    if (!welcomeLogin) throw new Error('welcome_login_missing');
    tap(welcomeLogin);
    fields = await waitFor(
      (state) => {
        const inputs = state.filter(
          (node) => node.class === 'android.widget.EditText',
        );
        return inputs.length >= 2 ? inputs : null;
      },
      'login_fields_missing',
    );
  }
  tap(fields[0]);
  clearFocused();
  inputEmail(email);
  tap(fields[1]);
  clearFocused();
  adb(['shell', 'input', 'text', password]);
  await wait(300);
  current = snapshot();
  const submit = current.find(
    (node) =>
      node.clickable === 'true' &&
      node.enabled === 'true' &&
      (node['content-desc'] === 'تسجيل الدخول' ||
        node['content-desc'] === 'Login'),
  );
  if (!submit) throw new Error('login_submit_missing');
  tap(submit);
  await waitFor(
    (state) => {
      const hasInputs = state.some(
        (node) => node.class === 'android.widget.EditText',
      );
      const shell = state.some(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          descriptionStarts(node, 'الرئيسية') ||
          descriptionStarts(node, 'Home'),
      );
      return !hasInputs && shell;
    },
    'fresh_login_failed',
    75_000,
  );
}

async function deleteCurrentAccount(password) {
  const { deleteAccount } = await openSettingsAccountSection();
  tap(deleteAccount);
  const fields = await waitFor(
    (state) => {
      const inputs = state.filter(
        (node) => node.class === 'android.widget.EditText',
      );
      return inputs.length >= 2 ? inputs : null;
    },
    'deletion_fields_missing',
  );
  const passwordField = fields.find((node) => node.password === 'true');
  if (!passwordField) throw new Error('deletion_password_missing');
  tap(passwordField);
  clearFocused();
  adb(['shell', 'input', 'text', password]);
  await wait(300);
  let current = snapshot();
  const checkbox = current.find(
    (node) => node.class === 'android.widget.CheckBox',
  );
  if (!checkbox) throw new Error('deletion_confirmation_missing');
  tap(checkbox);
  await wait(300);
  current = snapshot();
  const checked = current.some(
    (node) =>
      node.class === 'android.widget.CheckBox' && node.checked === 'true',
  );
  if (!checked) throw new Error('deletion_confirmation_failed');
  const submit = current.find(
    (node) =>
      node.class === 'android.widget.Button' &&
      node.clickable === 'true' &&
      node.enabled === 'true' &&
      (node['content-desc'] === 'حذف' || node['content-desc'] === 'Delete'),
  );
  if (!submit) throw new Error('deletion_submit_missing');
  tap(submit);
  await waitFor(
    (state) => {
      const signedOut = state.some(
        (node) =>
          node.clickable === 'true' &&
          (node['content-desc'] === 'تسجيل الدخول' ||
            node['content-desc'] === 'Login'),
      );
      const syntheticIdentity = state.some((node) =>
        /cp-[0-9a-f]{16}@example\.com/.test(
          `${node.text || ''} ${node['content-desc'] || ''}`,
        ),
      );
      return signedOut && !syntheticIdentity;
    },
    'in_app_deletion_incomplete',
    120_000,
  );
}

async function main() {
  const accountSection = await openSettingsAccountSection();
  const email = syntheticEmailFrom(accountSection.current);
  const password = `cp9${crypto.randomBytes(8).toString('hex')}`;
  await resetSyntheticPassword(email, password);
  marker('PASSWORD_RESET', { scoped: true });
  await signOutFromSettings(accountSection.current);
  await login(email, password);
  marker('FRESH_SESSION', { authenticated: true });
  await deleteCurrentAccount(password);
  marker('IN_APP_DELETION', { complete: true });
  adb(['shell', 'rm', '-f', remoteDump]);
}

main().catch((error) => {
  const allowed = new Set([
    'snapshot_invalid',
    'bounds_missing',
    'settings_nav_missing',
    'delete_account_control_missing',
    'synthetic_email_missing',
    'synthetic_scope_invalid',
    'synthetic_password_reset_failed',
    'logout_missing',
    'welcome_login_missing',
    'login_fields_missing',
    'login_submit_missing',
    'fresh_login_failed',
    'deletion_fields_missing',
    'deletion_password_missing',
    'deletion_confirmation_missing',
    'deletion_confirmation_failed',
    'deletion_submit_missing',
    'in_app_deletion_incomplete',
  ]);
  marker('FAILURE', {
    code: allowed.has(error?.message) ? error.message : 'cleanup_failed',
  });
  process.exitCode = 1;
});
