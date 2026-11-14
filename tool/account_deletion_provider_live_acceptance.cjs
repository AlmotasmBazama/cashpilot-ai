#!/usr/bin/env node

'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const {
  createProductionAdapter,
} = require('./android_cashpilot_acceptance_support.cjs');

const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const projectId = 'cashpilot-ai-a6b49';
const remoteDump = '/data/local/tmp/cashpilot_provider_live.xml';
const repositoryRoot = path.resolve(__dirname, '..');
const adapter = createProductionAdapter();
const adbExecutable = path.join(
  process.env.LOCALAPPDATA,
  'Android',
  'Sdk',
  'platform-tools',
  'adb.exe',
);
const scopedTables = Object.freeze([
  'ai_agent_plan_steps',
  'ai_agent_plans',
  'ai_agent_confirmation_proofs',
  'ai_agent_execution_results',
  'ai_agent_execution_attempts',
  'ai_agent_business_operations',
  'ai_agent_idempotency_records',
  'ai_agent_previews',
  'ai_agent_audit_events',
  'ai_agent_commands',
  'transaction_splits',
  'receipt_line_items',
  'receipts',
  'transactions',
  'goal_contributions',
  'goals',
  'budgets',
  'exchange_rates',
  'payees',
  'categories',
  'accounts',
  'owner_scope_migration_audits',
]);

let cloud;
let users = [];

function marker(name, fields = {}) {
  const values = Object.entries(fields).map(([key, value]) => `${key}=${value}`);
  process.stdout.write(`ACCOUNT_DELETION_LIVE_${name} ${values.join(' ')}\n`);
}

function adb(args, { capture = false, input } = {}) {
  return execFileSync(adbExecutable, ['-s', deviceId, ...args], {
    encoding: capture ? 'utf8' : undefined,
    input,
    stdio: input === undefined
      ? capture
        ? ['ignore', 'pipe', 'ignore']
        : 'ignore'
      : ['pipe', capture ? 'pipe' : 'ignore', 'ignore'],
  });
}

function adbBuffer(args) {
  return execFileSync(adbExecutable, ['-s', deviceId, ...args], {
    maxBuffer: 4 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'ignore'],
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

function isVisible(node) {
  const match = node?.bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
  if (!match) return false;
  return (
    Number(match[1]) >= 0 &&
    Number(match[2]) >= 64 &&
    Number(match[3]) <= 1080 &&
    Number(match[4]) <= 2400 &&
    Number(match[4]) > Number(match[2])
  );
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

function descriptionStarts(node, values) {
  return values.some((value) => description(node).startsWith(value));
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

function ownerScopeFor(user) {
  return crypto
    .createHash('sha256')
    .update(`cashpilot.local-owner-scope.v1\0${user.localId}`, 'utf8')
    .digest('hex');
}

async function createUser(label) {
  const synthetic = await adapter.createSyntheticUser(cloud);
  return {
    ...synthetic,
    label,
    ownerScope: ownerScopeFor(synthetic),
    deletionStarted: false,
    deletionCompleted: false,
  };
}

async function reachLoginScreen() {
  return waitFor(
    (state) => {
      const fields = state.filter(
        (node) => node.class === 'android.widget.EditText' && isVisible(node),
      );
      if (fields.length >= 2) return fields;
      const login = state.find(
        (node) =>
          node.clickable === 'true' &&
          isVisible(node) &&
          descriptionIs(node, ['Login', 'تسجيل الدخول']),
      );
      if (login) tap(login);
      return null;
    },
    'login_fields_missing',
  );
}

async function login(user) {
  const fields = await reachLoginScreen();
  tap(fields[0]);
  clearFocused();
  inputEmail(user.email);
  tap(fields[1]);
  clearFocused();
  adb(['shell', 'input', 'text', user.password]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  await wait(300);
  const submit = snapshot().find(
    (node) =>
      node.clickable === 'true' &&
      node.enabled === 'true' &&
      isVisible(node) &&
      descriptionIs(node, ['Login', 'تسجيل الدخول']),
  );
  if (!submit) throw new Error('login_submit_missing');
  tap(submit);
  await waitFor(
    (state) =>
      state.find(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          (isVisible(node) && descriptionIs(node, ['Settings', 'الإعدادات'])),
      ),
    'authenticated_shell_missing',
    120_000,
  );
  marker('LOGIN', { target: user.label, authenticated: true });
}

async function tapDashboard() {
  const target = await waitFor(
    (state) =>
      state.find(
        (node) =>
          isVisible(node) &&
          (node['resource-id'] === 'cashpilot_acceptance_nav_dashboard' ||
            descriptionStarts(node, ['Home', 'الرئيسية'])),
      ),
    'dashboard_nav_missing',
  );
  tap(target);
  await wait(500);
}

async function visibleAction(labels, safeCode, timeoutMs = 30_000) {
  return waitFor(
    (state) =>
      state.find(
        (node) =>
          node.clickable === 'true' &&
          isVisible(node) &&
          descriptionStarts(node, labels),
      ),
    safeCode,
    timeoutMs,
  );
}

async function scrollUntilAction(labels, safeCode, maxAttempts = 10) {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const target = snapshot().find(
      (node) =>
        node.clickable === 'true' &&
        isVisible(node) &&
        descriptionStarts(node, labels),
    );
    if (target) return target;
    adb(['shell', 'input', 'swipe', '540', '1840', '540', '760', '350']);
    await wait(350);
  }
  throw new Error(safeCode);
}

async function createAccountThroughUi(user) {
  await tapDashboard();
  let addAccount = snapshot().find(
    (node) =>
      node.clickable === 'true' &&
      isVisible(node) &&
      descriptionStarts(node, ['Add account', 'إضافة حساب']),
  );
  if (!addAccount) {
    const accounts = await visibleAction(
      ['Accounts', 'الحسابات'],
      'accounts_navigation_missing',
    );
    tap(accounts);
    addAccount = await visibleAction(
      ['Add account', 'إضافة حساب'],
      'add_account_missing',
    );
  }
  tap(addAccount);
  await wait(1_000);
  const initialInputs = snapshot().filter(
    (node) => node.class === 'android.widget.EditText' && isVisible(node),
  );
  if (initialInputs.length === 0) {
    const retry = snapshot().find(
      (node) =>
        node.clickable === 'true' &&
        isVisible(node) &&
        descriptionStarts(node, ['Add account', 'إضافة حساب']),
    );
    if (retry) {
      tap(retry);
      await wait(1_000);
    }
  }
  const fields = await waitFor(
    (state) => {
      const inputs = state.filter(
        (node) => node.class === 'android.widget.EditText' && isVisible(node),
      );
      return inputs.length >= 1 ? inputs : null;
    },
    'account_form_missing',
  );
  const nameField = fields.find((field) => field.text === '') || fields[0];
  tap(nameField);
  clearFocused();
  adb(['shell', 'input', 'text', `qa${crypto.randomBytes(4).toString('hex')}`]);
  if (fields.length >= 3) {
    tap(fields[2]);
    clearFocused();
    adb(['shell', 'input', 'text', '9']);
  }
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  const save = await scrollUntilAction(
    ['Save', 'حفظ'],
    'account_save_missing',
  );
  tap(save);
  await waitFor(
    () => localCounts(user).accounts >= 1,
    'account_create_not_persisted',
    60_000,
  );
}

async function createExpenseThroughUi(user) {
  const transactions = await visibleAction(
    ['Transactions', 'المعاملات'],
    'transactions_navigation_missing',
  );
  tap(transactions);
  const addExpense = await visibleAction(
    ['Add expense', 'إضافة مصروف'],
    'add_expense_missing',
    60_000,
  );
  tap(addExpense);
  const fields = await waitFor(
    (state) => {
      const inputs = state.filter(
        (node) => node.class === 'android.widget.EditText' && isVisible(node),
      );
      return inputs.length >= 1 ? inputs : null;
    },
    'expense_form_missing',
  );
  tap(fields[0]);
  clearFocused();
  adb(['shell', 'input', 'text', String(crypto.randomInt(1, 9))]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  const save = await scrollUntilAction(
    ['Save', 'حفظ'],
    'expense_save_missing',
    14,
  );
  tap(save);
  await waitFor(
    () => localCounts(user).transactions >= 1,
    'expense_create_not_persisted',
    60_000,
  );
}

function sqliteOutput(query) {
  return adb(
    [
      'shell',
      'run-as',
      packageName,
      'sqlite3',
      '-separator',
      '=',
      'app_flutter/cashpilot_ai.sqlite',
    ],
    { capture: true, input: query },
  );
}

function localCounts(user) {
  if (!/^[a-f0-9]{64}$/.test(user.ownerScope)) {
    throw new Error('owner_scope_invalid');
  }
  const parts = scopedTables.map(
    (table) =>
      `SELECT '${table}',count(*) FROM ${table} ` +
      `WHERE owner_scope_id='${user.ownerScope}'`,
  );
  parts.push(
    "SELECT 'sync_queue',count(*) FROM sync_queue " +
      `WHERE owner_scope_id='${user.ownerScope}' OR ` +
      `(owner_scope_id IS NULL AND owner_user_id='${user.localId}')`,
  );
  const output = sqliteOutput(`${parts.join(' UNION ALL ')};`);
  const counts = Object.fromEntries(
    output
      .trim()
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => {
        const [name, value] = line.split('=');
        return [name, Number(value)];
      }),
  );
  return counts;
}

function groupedLocalCounts(counts) {
  const aiRows = Object.entries(counts)
    .filter(([name]) => name.startsWith('ai_agent_'))
    .reduce((sum, [, value]) => sum + value, 0);
  const receiptRows = (counts.receipts || 0) + (counts.receipt_line_items || 0);
  const allRows = Object.values(counts).reduce((sum, value) => sum + value, 0);
  return {
    allRows,
    accounts: counts.accounts || 0,
    transactions: counts.transactions || 0,
    categories: counts.categories || 0,
    syncRows: counts.sync_queue || 0,
    aiRows,
    receiptRows,
  };
}

function createReceiptFileFixture(user) {
  const filename = `${crypto.randomBytes(32).toString('hex')}.jpg`;
  const directory = `files/receipt_images/${user.ownerScope}`;
  adb(['shell', 'run-as', packageName, 'mkdir', '-p', directory]);
  adb(['shell', 'run-as', packageName, 'touch', `${directory}/${filename}`]);
}

function receiptFileCount(user) {
  try {
    const output = adb(
      [
        'shell',
        'run-as',
        packageName,
        'ls',
        '-1',
        `files/receipt_images/${user.ownerScope}`,
      ],
      { capture: true },
    );
    return output.trim() === '' ? 0 : output.trim().split(/\r?\n/).length;
  } catch (error) {
    if (error?.status === 1) return 0;
    throw error;
  }
}

function hiveScopeOccurrenceCount(user) {
  let buffer;
  try {
    buffer = adbBuffer([
      'exec-out',
      'run-as',
      packageName,
      'cat',
      'app_flutter/settings.hive',
    ]);
  } catch (error) {
    if (error?.status === 1) return 0;
    throw error;
  }
  const needle = Buffer.from(user.ownerScope, 'utf8');
  let count = 0;
  let offset = 0;
  while ((offset = buffer.indexOf(needle, offset)) !== -1) {
    count += 1;
    offset += needle.length;
  }
  buffer.fill(0);
  buffer = undefined;
  return count;
}

function hiveLogicalOwnerState(user) {
  let buffer;
  const temporaryDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'cashpilot-hive-owner-zero-'),
  );
  try {
    buffer = adbBuffer([
      'exec-out',
      'run-as',
      packageName,
      'cat',
      'app_flutter/settings.hive',
    ]);
    fs.writeFileSync(path.join(temporaryDirectory, 'settings.hive'), buffer, {
      flag: 'wx',
    });
    const localProperties = fs.readFileSync(
      path.join(repositoryRoot, 'android', 'local.properties'),
      'utf8',
    );
    const flutterSdkMatch = /^flutter\.sdk=(.+)$/mu.exec(localProperties);
    if (!flutterSdkMatch) {
      throw new Error('hive_logical_probe_invalid');
    }
    const flutterSdk = flutterSdkMatch[1].replaceAll('\\\\', '\\');
    const dartExecutable = path.join(
      flutterSdk,
      'bin',
      'cache',
      'dart-sdk',
      'bin',
      'dart.exe',
    );
    if (!fs.existsSync(dartExecutable)) {
      throw new Error('hive_logical_probe_invalid');
    }
    const output = execFileSync(
      dartExecutable,
      ['run', 'tool/hive_owner_zero_probe.dart', temporaryDirectory],
      {
        cwd: repositoryRoot,
        encoding: 'utf8',
        input: user.ownerScope,
        stdio: ['pipe', 'pipe', 'ignore'],
        timeout: 30_000,
      },
    );
    const jsonStart = output.lastIndexOf('{');
    const decoded = JSON.parse(jsonStart < 0 ? '' : output.slice(jsonStart));
    if (
      !Number.isSafeInteger(decoded?.userDataEntries) ||
      !Number.isSafeInteger(decoded?.terminalTombstones) ||
      !Number.isSafeInteger(decoded?.liveOwnerReferences)
    ) {
      throw new Error('hive_logical_probe_invalid');
    }
    return decoded;
  } finally {
    buffer?.fill(0);
    buffer = undefined;
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

async function populateThroughProductUi(user) {
  marker('FLOW', { target: user.label, step: 'accountCreateStarted' });
  await createAccountThroughUi(user);
  marker('FLOW', { target: user.label, step: 'accountCreateCompleted' });
  await createExpenseThroughUi(user);
  marker('FLOW', { target: user.label, step: 'expenseCreateCompleted' });
  createReceiptFileFixture(user);
  const counts = groupedLocalCounts(localCounts(user));
  const receiptFiles = receiptFileCount(user);
  marker('PRODUCT_POPULATION', {
    target: user.label,
    accounts: counts.accounts,
    transactions: counts.transactions,
    categoriesPresent: counts.categories > 0,
    receiptFixtureFiles: receiptFiles,
  });
  if (
    counts.accounts < 1 ||
    counts.transactions < 1 ||
    receiptFiles !== 1
  ) {
    throw new Error('product_population_incomplete');
  }
}

async function seedCloudTree(user) {
  const base =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/users/${encodeURIComponent(user.localId)}`;
  const paths = [
    `${base}/accounts/provider-acceptance`,
    `${base}/futureContainers/root/children/deep`,
  ];
  for (const url of paths) {
    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ fields: { synthetic: { booleanValue: true } } }),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw new Error('cloud_seed_failed');
  }
}

async function openSettingsDeletionDialog() {
  const settings = await waitFor(
    (state) =>
      state.find(
        (node) =>
          isVisible(node) &&
          (node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
            descriptionIs(node, ['Settings', 'الإعدادات'])),
      ),
    'settings_nav_missing',
  );
  tap(settings);
  await wait(500);
  const action = await scrollUntilAction(
    ['Delete account', 'حذف الحساب'],
    'settings_delete_action_missing',
  );
  tap(action);
  await wait(1_000);
  const initialState = snapshot();
  const initialFields = initialState.filter(
    (node) => node.class === 'android.widget.EditText' && isVisible(node),
  );
  const initialCheckbox = initialState.find(
    (node) => node.class === 'android.widget.CheckBox' && isVisible(node),
  );
  if (initialFields.length >= 2 && initialCheckbox) {
    return { fields: initialFields, checkbox: initialCheckbox };
  }
  const retry = initialState.find(
    (node) =>
      node.clickable === 'true' &&
      isVisible(node) &&
      descriptionStarts(node, ['Delete account', 'حذف الحساب']),
  );
  if (retry) {
    tap(retry);
    await wait(1_000);
  }
  return waitFor(
    (state) => {
      const fields = state.filter(
        (node) => node.class === 'android.widget.EditText' && isVisible(node),
      );
      const checkbox = state.find(
        (node) => node.class === 'android.widget.CheckBox' && isVisible(node),
      );
      return fields.length >= 2 && checkbox ? { fields, checkbox } : null;
    },
    'deletion_dialog_missing',
  );
}

async function prepareDeletionDialog(dialog, user) {
  const emailField = dialog.fields.find((node) => node.password !== 'true');
  const passwordField = dialog.fields.find((node) => node.password === 'true');
  if (!emailField || !passwordField || emailField.text !== user.email) {
    throw new Error('dialog_target_mismatch');
  }
  tap(passwordField);
  clearFocused();
  adb(['shell', 'input', 'text', user.password]);
  adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
  await wait(300);
  let state = snapshot();
  const checkbox = state.find(
    (node) => node.class === 'android.widget.CheckBox' && isVisible(node),
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
      isVisible(node) &&
      descriptionIs(node, ['Delete', 'حذف']),
  );
  if (!checked || !submit) throw new Error('deletion_submit_missing');
  return submit;
}

async function waitForSignedOut() {
  await waitFor(
    (state) => {
      const login = state.some(
        (node) =>
          node.clickable === 'true' &&
          isVisible(node) &&
          descriptionIs(node, ['Login', 'تسجيل الدخول']),
      );
      const shell = state.some(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
          descriptionIs(node, ['Home', 'الرئيسية']),
      );
      return login && !shell;
    },
    'authoritative_deletion_incomplete',
    150_000,
  );
}

async function completeCleanDeletion(user) {
  const dialog = await openSettingsDeletionDialog();
  const submit = await prepareDeletionDialog(dialog, user);
  user.deletionStarted = true;
  tap(submit);
  await waitForSignedOut();
  user.deletionCompleted = true;
}

function launchApp() {
  adb(['shell', 'monkey', '-p', packageName, '-c', 'android.intent.category.LAUNCHER', '1']);
}

async function resumeInterruptedDeletion(user) {
  launchApp();
  const stateKind = await waitFor(
    (state) => {
      const action = state.find(
        (node) =>
          node.class === 'android.widget.Button' &&
          isVisible(node) &&
          descriptionStarts(node, ['Delete account', 'حذف الحساب']),
      );
      if (action) return { kind: 'action', action };
      const shell = state.some(
        (node) =>
          node['resource-id'] === 'cashpilot_acceptance_authenticated_shell' ||
          node['resource-id'] === 'cashpilot_acceptance_nav_settings',
      );
      if (shell) return { kind: 'shell' };
      const fields = state.filter(
        (node) => node.class === 'android.widget.EditText' && isVisible(node),
      );
      const checkbox = state.find(
        (node) => node.class === 'android.widget.CheckBox' && isVisible(node),
      );
      if (fields.length >= 2 && !checkbox) return { kind: 'login', fields };
      return null;
    },
    'protected_continuation_missing',
    120_000,
  );
  if (stateKind.kind === 'shell') {
    const dialog = await openSettingsDeletionDialog();
    const submit = await prepareDeletionDialog(dialog, user);
    tap(submit);
    await waitForSignedOut();
    user.deletionCompleted = true;
    return;
  }
  let action = stateKind.action;
  if (stateKind.kind === 'login') {
    tap(stateKind.fields[0]);
    clearFocused();
    inputEmail(user.email);
    tap(stateKind.fields[1]);
    clearFocused();
    adb(['shell', 'input', 'text', user.password]);
    adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
    const login = await visibleAction(
      ['Login', 'تسجيل الدخول'],
      'continuation_login_missing',
    );
    tap(login);
    action = await visibleAction(
      ['Delete account', 'حذف الحساب'],
      'continuation_action_missing',
      90_000,
    );
  }
  tap(action);
  const dialog = await waitFor(
    (state) => {
      const fields = state.filter(
        (node) => node.class === 'android.widget.EditText' && isVisible(node),
      );
      const checkbox = state.find(
        (node) => node.class === 'android.widget.CheckBox' && isVisible(node),
      );
      return fields.length >= 2 && checkbox ? { fields, checkbox } : null;
    },
    'continuation_deletion_dialog_missing',
  );
  const submit = await prepareDeletionDialog(dialog, user);
  tap(submit);
  await waitForSignedOut();
  user.deletionCompleted = true;
}

async function authState(user) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:query`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ expression: [{ userId: user.localId }], limit: '1' }),
      signal: AbortSignal.timeout(15_000),
    },
  );
  const body = await response.json().catch(() => null);
  if (!response.ok) return 'unknown';
  const matches = Array.isArray(body?.userInfo)
    ? body.userInfo.filter((entry) => entry.localId === user.localId)
    : [];
  return matches.length === 0 ? 'absent' : matches.length === 1 ? 'exists' : 'unknown';
}

async function cloudTreeEmpty(user) {
  const base =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/users/${encodeURIComponent(user.localId)}`;
  const headers = { Authorization: `Bearer ${cloud.accessToken}` };
  const [root, collections] = await Promise.all([
    fetch(base, { headers, signal: AbortSignal.timeout(15_000) }),
    fetch(`${base}:listCollectionIds`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ pageSize: 100 }),
      signal: AbortSignal.timeout(15_000),
    }),
  ]);
  const body = await collections.json().catch(() => null);
  return (
    root.status === 404 &&
    collections.ok &&
    (!Array.isArray(body?.collectionIds) || body.collectionIds.length === 0) &&
    !body?.nextPageToken
  );
}

async function permanentLockPresent(user) {
  const lockId = crypto
    .createHash('sha256')
    .update(user.localId, 'utf8')
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

async function verifyDeleted(user, phase) {
  const [auth, tree, lock] = await Promise.all([
    authState(user),
    cloudTreeEmpty(user),
    permanentLockPresent(user),
  ]);
  const local = groupedLocalCounts(localCounts(user));
  const receiptFiles = receiptFileCount(user);
  const hiveOccurrences = hiveScopeOccurrenceCount(user);
  const hive = hiveLogicalOwnerState(user);
  const success =
    auth === 'absent' &&
    tree &&
    lock &&
    local.allRows === 0 &&
    receiptFiles === 0 &&
    hive.userDataEntries === 0 &&
    hive.terminalTombstones === 1;
  marker('ZERO_VERIFICATION', {
    target: user.label,
    phase,
    authAbsent: auth === 'absent',
    cloudTreeEmpty: tree,
    driftRows: local.allRows,
    receiptRows: local.receiptRows,
    receiptFiles,
    aiRows: local.aiRows,
    syncRows: local.syncRows,
    hiveUserDataEntries: hive.userDataEntries,
    hiveTerminalTombstones: hive.terminalTombstones,
    hiveLiveOwnerReferences: hive.liveOwnerReferences,
    hiveScopeByteOccurrences: hiveOccurrences,
    permanentFencePresent: lock,
  });
  if (!success) throw new Error('zero_verification_failed');
}

function canonicalJson(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalJson);
  }
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  }
  return value;
}

async function profileFingerprint(user) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/users/${encodeURIComponent(user.localId)}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${cloud.accessToken}` },
    signal: AbortSignal.timeout(15_000),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || typeof body?.updateTime !== 'string') return null;
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(canonicalJson(body)), 'utf8')
    .digest('hex');
}

async function verifyControlsUnchanged(controls, fingerprints) {
  const results = await Promise.all(
    controls.map(async (control, index) => ({
      auth: await authState(control),
      fingerprint: await profileFingerprint(control),
      expected: fingerprints[index],
    })),
  );
  const unchanged = results.every(
    (result) =>
      result.auth === 'exists' &&
      result.fingerprint !== null &&
      result.fingerprint === result.expected,
  );
  marker('CONTROL_PRESERVATION', { users: controls.length, unchanged });
  if (!unchanged) throw new Error('control_user_changed');
}

async function runInterrupted(user) {
  await login(user);
  await seedCloudTree(user);
  await populateThroughProductUi(user);
  const dialog = await openSettingsDeletionDialog();
  const submit = await prepareDeletionDialog(dialog, user);
  user.deletionStarted = true;
  tap(submit);
  await wait(500);
  adb(['shell', 'am', 'force-stop', packageName]);
  await wait(3_000);
  const [authAfterStop, cloudAfterStop] = await Promise.all([
    authState(user),
    cloudTreeEmpty(user),
  ]);
  marker('INTERRUPTION', {
    target: user.label,
    forceStopped: true,
    authStillPresent: authAfterStop === 'exists',
    cloudCompletedBeforeResume: cloudAfterStop,
    protectedPreAuthStage: authAfterStop === 'exists',
  });
  if (authAfterStop !== 'exists') throw new Error('interruption_too_late');
  await resumeInterruptedDeletion(user);
  await verifyDeleted(user, 'interrupted');
}

async function runClean(user) {
  await login(user);
  await seedCloudTree(user);
  await populateThroughProductUi(user);
  await completeCleanDeletion(user);
  await verifyDeleted(user, 'clean');
}

async function verifyNoResurrection(targets) {
  adb(['shell', 'am', 'force-stop', packageName]);
  launchApp();
  await waitForSignedOut();
  await wait(30_000);
  for (const target of targets) {
    await verifyDeleted(target, 'boundedReopen');
  }
  marker('NO_RESURRECTION', {
    targets: targets.length,
    waitSeconds: 30,
    dataReappeared: false,
    networkRestored: true,
    workersRestarted: true,
  });
}

async function bestEffortAppLogout() {
  try {
    launchApp();
    await wait(1_000);
    for (let attempt = 0; attempt < 18; attempt += 1) {
      const state = snapshot();
      if (
        state.some(
          (node) =>
            node['resource-id'] === 'cashpilot_acceptance_welcome_login' ||
            node['resource-id'] === 'cashpilot_acceptance_login_email',
        )
      ) {
        return true;
      }
      const logout = state.find(
        (node) =>
          node.clickable === 'true' &&
          isVisible(node) &&
          (node['resource-id'] === 'cashpilot_acceptance_logout' ||
            descriptionIs(node, ['Log out', 'تسجيل الخروج'])),
      );
      if (logout) {
        tap(logout);
        await wait(1_000);
        continue;
      }
      const settings = state.find(
        (node) =>
          node.clickable === 'true' &&
          isVisible(node) &&
          (node['resource-id'] === 'cashpilot_acceptance_nav_settings' ||
            descriptionStarts(node, ['Settings', 'الإعدادات'])),
      );
      if (settings) {
        tap(settings);
        await wait(500);
      }
      adb(['shell', 'input', 'swipe', '540', '1850', '540', '800', '300']);
      await wait(350);
    }
  } catch {
    return false;
  }
  return false;
}

async function cleanupControl(control) {
  const [profile, auth] = await Promise.all([
    adapter.deleteSyntheticProfile(cloud, control),
    adapter.deleteSyntheticUser(cloud, control),
  ]);
  return profile && auth;
}

async function exactSyntheticCount() {
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
  if (!response.ok) throw new Error('synthetic_query_failed');
  return (Array.isArray(body?.userInfo) ? body.userInfo : []).filter(
    (user) =>
      /^cp-restart-[0-9a-f]{16}$/.test(user?.localId || '') &&
      /^cp-[0-9a-f]{16}@example\.com$/.test(user?.email || '') &&
      user?.displayName === 'CashPilot Restart Acceptance',
  ).length;
}

async function waitForSyntheticCleanupConvergence(runUsers) {
  let remaining = -1;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const states = await Promise.all(runUsers.map(authState));
    if (states.some((state) => state === 'unknown')) {
      throw new Error('synthetic_query_failed');
    }
    remaining = states.filter((state) => state === 'exists').length;
    if (remaining === 0) return 0;
    await wait(1_000);
  }
  return remaining;
}

async function main() {
  try {
    cloud = await adapter.loadCloudCredentials();
    for (const label of ['A', 'B', 'C', 'D']) {
      users.push(await createUser(label));
    }
    marker('SYNTHETIC_SETUP', { users: users.length, credentialsPersisted: false });
    const controls = users.slice(0, 2);
    const targets = users.slice(2);
    const controlFingerprints = await Promise.all(controls.map(profileFingerprint));
    if (controlFingerprints.some((fingerprint) => fingerprint === null)) {
      throw new Error('control_baseline_failed');
    }

    await runInterrupted(targets[0]);
    await runClean(targets[1]);
    await verifyControlsUnchanged(controls, controlFingerprints);
    await verifyNoResurrection(targets);

    const controlCleanup = await Promise.all(controls.map(cleanupControl));
    if (!controlCleanup.every(Boolean)) throw new Error('control_cleanup_failed');
    const remaining = await waitForSyntheticCleanupConvergence(users);
    marker('CLEANUP', {
      controlsDeleted: controlCleanup.length,
      targetAccountsDeletedByApp: targets.filter(
        (target) => target.deletionCompleted,
      ).length,
      exactSyntheticAccountsRemaining: remaining,
    });
    if (remaining !== 0) throw new Error('synthetic_cleanup_incomplete');
    marker('RESULT', {
      interrupted: true,
      clean: true,
      controlsPreservedBeforeCleanup: true,
      noResurrection: true,
      complete: true,
    });
  } finally {
    try {
      adb(['shell', 'rm', '-f', remoteDump]);
    } catch {
      // Best-effort removal of a credential-bearing UI snapshot.
    }
    const hasIncompleteDeletion = users.some(
      (user) => user.deletionStarted && !user.deletionCompleted,
    );
    if (!hasIncompleteDeletion) {
      try {
        adb(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
        launchApp();
        await wait(1_000);
      } catch {
        // Continue to the bounded app-level logout attempt.
      }
      await bestEffortAppLogout();
    }
    if (cloud) {
      for (const user of users) {
        if (!user.deletionStarted || user.deletionCompleted || ['A', 'B'].includes(user.label)) {
          await adapter.deleteSyntheticProfile(cloud, user).catch(() => false);
          await adapter.deleteSyntheticUser(cloud, user).catch(() => false);
        }
      }
    }
    for (const user of users) {
      user.email = undefined;
      user.password = undefined;
      user.localId = undefined;
      user.ownerScope = undefined;
    }
    users = [];
    if (cloud) cloud.accessToken = undefined;
    cloud = undefined;
  }
}

const allowedErrors = new Set([
  'ui_snapshot_invalid',
  'ui_bounds_invalid',
  'login_fields_missing',
  'login_submit_missing',
  'authenticated_shell_missing',
  'dashboard_nav_missing',
  'accounts_navigation_missing',
  'add_account_missing',
  'account_form_missing',
  'account_save_missing',
  'account_create_not_persisted',
  'transactions_navigation_missing',
  'add_expense_missing',
  'expense_form_missing',
  'expense_save_missing',
  'expense_create_not_persisted',
  'owner_scope_invalid',
  'product_population_incomplete',
  'cloud_seed_failed',
  'settings_nav_missing',
  'settings_delete_action_missing',
  'deletion_dialog_missing',
  'dialog_target_mismatch',
  'deletion_confirmation_missing',
  'deletion_submit_missing',
  'authoritative_deletion_incomplete',
  'protected_continuation_missing',
  'continuation_login_missing',
  'continuation_action_missing',
  'continuation_deletion_dialog_missing',
  'zero_verification_failed',
  'hive_logical_probe_invalid',
  'control_user_changed',
  'control_baseline_failed',
  'interruption_too_late',
  'control_cleanup_failed',
  'synthetic_query_failed',
  'synthetic_cleanup_incomplete',
]);

main().catch((error) => {
  marker('FAILURE', {
    code: allowedErrors.has(error?.message) ? error.message : 'live_acceptance_failed',
    errorType: /^[A-Za-z0-9_]+$/.test(error?.name || '')
      ? error.name
      : 'unknown',
    systemCode: /^[A-Za-z0-9_]+$/.test(error?.code || '')
      ? error.code
      : 'none',
    adapterCode: /^[A-Za-z0-9_]+$/.test(error?.safeCode || '')
      ? error.safeCode
      : 'none',
    rawSafeCode: /^[a-z0-9_]{1,80}$/.test(error?.message || '')
      ? error.message
      : 'none',
    processStatus: Number.isSafeInteger(error?.status) ? error.status : -1,
    processSignal: /^[A-Z0-9]+$/.test(error?.signal || '')
      ? error.signal
      : 'none',
  });
  process.exitCode = 1;
});
