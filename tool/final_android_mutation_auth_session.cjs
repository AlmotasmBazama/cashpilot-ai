#!/usr/bin/env node

'use strict';

const readline = require('node:readline');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const {
  createProductionAdapter,
} = require('./android_cashpilot_acceptance_support.cjs');
const {
  safeCodeFor,
} = require('./android_safe_output_primitives.cjs');

const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
const adapter = createProductionAdapter();
const packageName = 'com.example.cashpilot_ai';
const remoteUiDump = '/data/local/tmp/cashpilot_final_mutation_ui.xml';

let cloud;
let userA;
let userB;
let closed = false;

function marker(name, fields = {}) {
  const values = Object.entries(fields).map(([key, value]) => `${key}=${value}`);
  process.stdout.write(`FINAL_MUTATION_AUTH_${name} ${values.join(' ')}\n`);
}

async function cleanupUser(user) {
  if (!user || !cloud) return true;
  const profile = await adapter.deleteSyntheticProfile(cloud, user).catch(
    () => false,
  );
  const auth = await adapter.deleteSyntheticUser(cloud, user).catch(() => false);
  return profile && auth;
}

async function cleanup() {
  if (closed) return true;
  closed = true;
  const [a, b] = await Promise.all([cleanupUser(userA), cleanupUser(userB)]);
  userA = undefined;
  userB = undefined;
  cloud = undefined;
  marker('CLEANUP', { userA: a, userB: b });
  return a && b;
}

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
  adb(['shell', 'uiautomator', 'dump', remoteUiDump]);
  const xml = adb(['exec-out', 'cat', remoteUiDump], { capture: true });
  if (typeof xml !== 'string' || xml.length < 100 || xml.length > 1024 * 1024) {
    throw new Error('ui_snapshot_invalid');
  }
  return xml;
}

function point(bounds) {
  const match = bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
  if (!match) throw new Error('ui_bounds_invalid');
  return {
    x: Math.floor((Number(match[1]) + Number(match[3])) / 2),
    y: Math.floor((Number(match[2]) + Number(match[4])) / 2),
  };
}

function tap(node) {
  const target = point(node.bounds);
  adb(['shell', 'input', 'tap', String(target.x), String(target.y)]);
}

function clearFocusedCredential() {
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

async function wait(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function manualReachLogin() {
  const deadline = Date.now() + 45_000;
  while (Date.now() <= deadline) {
    const current = nodes(snapshot());
    if (current.filter((node) => node.class === 'android.widget.EditText').length >= 2) {
      return;
    }
    const loginControl = current.find(
      (node) =>
        node.clickable === 'true' &&
        (node['content-desc'] === 'تسجيل الدخول' ||
          node['content-desc'] === 'Login'),
    );
    if (loginControl) tap(loginControl);
    await wait(400);
  }
  throw new Error('ui_login_screen_timed_out');
}

async function manualLogin(user) {
  await manualReachLogin();
  let current = nodes(snapshot());
  const fields = current.filter(
    (node) => node.class === 'android.widget.EditText',
  );
  if (fields.length < 2) throw new Error('ui_login_fields_missing');
  tap(fields[0]);
  clearFocusedCredential();
  inputEmail(user.email);
  tap(fields[1]);
  clearFocusedCredential();
  adb(['shell', 'input', 'text', user.password]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  await wait(300);
  current = nodes(snapshot());
  const submit = current.find(
    (node) =>
      node.clickable === 'true' &&
      (node['content-desc'] === 'تسجيل الدخول' ||
        node['content-desc'] === 'Login'),
  );
  if (!submit) throw new Error('ui_login_submit_missing');
  tap(submit);

  const deadline = Date.now() + 90_000;
  while (Date.now() <= deadline) {
    current = nodes(snapshot());
    const editFields = current.filter(
      (node) => node.class === 'android.widget.EditText',
    );
    const shellVisible = current.some((node) =>
      [
        'الرئيسية',
        'لوحة التحكم',
        'الحسابات',
        'المعاملات',
        'الإعدادات',
        'Home',
        'Accounts',
        'Transactions',
        'Settings',
      ].includes(node['content-desc']),
    );
    if (editFields.length === 0 && shellVisible) return;
    await wait(500);
  }
  throw new Error('ui_authenticated_shell_timed_out');
}

async function login(user, label) {
  try {
    await adapter.reachLoginScreen(deviceId);
    await adapter.login(deviceId, user);
  } catch {
    await manualLogin(user);
  }
  marker('LOGIN', { user: label, authenticated: true });
}

async function command(value) {
  switch (value.trim().toLowerCase()) {
    case 'login_a':
      await login(userA, 'A');
      return;
    case 'login_b':
      await login(userB, 'B');
      return;
    case 'logout': {
      const signedOut = await adapter.logout(deviceId);
      marker('LOGOUT', { signedOut });
      return;
    }
    case 'cleanup': {
      const complete = await cleanup();
      marker('RESULT', { complete });
      process.exitCode = complete ? 0 : 1;
      process.exit();
      return;
    }
    case 'exit':
      marker('RESULT', { complete: false });
      process.exitCode = 1;
      process.exit();
      return;
    default:
      marker('COMMAND_REJECTED', { code: 'unsupported' });
  }
}

async function main() {
  try {
    cloud = await adapter.loadCloudCredentials();
    userA = await adapter.createSyntheticUser(cloud);
    userB = await adapter.createSyntheticUser(cloud);
    marker('READY', {
      users: 2,
      verified: true,
      credentialsPersisted: false,
    });
  } catch (error) {
    await cleanup();
    marker('FAILURE', { code: safeCodeFor(error) });
    process.exitCode = 1;
    return;
  }

  const input = readline.createInterface({
    input: process.stdin,
    terminal: false,
  });
  input.on('line', (line) => {
    input.pause();
    command(line)
      .catch((error) => marker('FAILURE', { code: safeCodeFor(error) }))
      .finally(() => input.resume());
  });
}

process.on('SIGINT', () => {
  cleanup().finally(() => process.exit(1));
});
process.on('SIGTERM', () => {
  cleanup().finally(() => process.exit(1));
});

void main();
