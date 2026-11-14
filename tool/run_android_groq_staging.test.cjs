'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const repositoryRoot = path.resolve(__dirname, '..');
const runnerPath = path.join(__dirname, 'run_android_groq_staging.ps1');
const launchPath = path.join(repositoryRoot, '.vscode', 'launch.json');
const tasksPath = path.join(repositoryRoot, '.vscode', 'tasks.json');
const stagingConfigPath = path.join(
  repositoryRoot,
  'config',
  'groq_staging.json',
);
const pubspecPath = path.join(repositoryRoot, 'pubspec.yaml');
const intendedNonReleaseStagingConfig = {
  CASH_PILOT_ENVIRONMENT: 'staging',
  CASH_PILOT_AI_PROVIDER: 'groq',
  CASH_PILOT_AI_DIAGNOSTICS: 'false',
  CASH_PILOT_AI_GROQ_GATEWAY_ENABLED: 'true',
  CASH_PILOT_AI_GROQ_GENERAL_CHAT_ENABLED: 'true',
  CASH_PILOT_AI_GROQ_FINANCIAL_EXPLANATION_ENABLED: 'true',
  CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED: 'false',
  CASH_PILOT_AI_GROQ_ARABIC_SPECIALIST_ENABLED: 'true',
  CASH_PILOT_AI_CURRENT_WEB_ENABLED: 'false',
  CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED: 'false',
  CASH_PILOT_AI_FIREBASE_RECEIPT_VISION_ENABLED: 'true',
  CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED: 'true',
  CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED: 'true',
  CASH_PILOT_AI_GATEWAY_BASE_URL:
    'https://cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app',
  CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL:
    'https://cashpilot-account-deletion-staging-yfgt2ypuvq-ew.a.run.app',
  CASH_PILOT_CLIENT_VERSION: '1.0.0',
};
const forbiddenConfigKeyPattern =
  /(?:^|_)(?:GROQ_API_KEY|API_KEY|SECRET(?:_KEY)?|PASSWORD|CREDENTIALS?|PRIVATE_KEY|SIGNING_KEY|TOKEN)$/u;
const forbiddenGroqClientContentPattern =
  /GROQ_API_KEY|GROQ_[A-Z0-9_]*(?:SECRET(?:_KEY)?|TOKEN)\b|\bgsk_[A-Za-z0-9_-]{8,}|-----BEGIN\x20PRIVATE\x20KEY-----|["']private_key["']\s*:/iu;

function powershellExecutable() {
  return process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
}

function runRunner(args, options = {}) {
  return spawnSync(
    powershellExecutable(),
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      runnerPath,
      ...args,
    ],
    {
      cwd: repositoryRoot,
      encoding: 'utf8',
      windowsHide: true,
      ...options,
    },
  );
}

function filesBelow(directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    return entry.isDirectory() ? filesBelow(entryPath) : [entryPath];
  });
}

function installFakeFlutter(t) {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'cashpilot-groq-wrapper-'),
  );
  const argumentsPath = path.join(directory, 'flutter-arguments.txt');
  const executablePath = path.join(
    directory,
    process.platform === 'win32' ? 'flutter.bat' : 'flutter',
  );
  const source =
    process.platform === 'win32'
      ? '@echo off\r\n>> "%CASHPILOT_FAKE_FLUTTER_ARGS%" echo %*\r\nexit /b 0\r\n'
      : '#!/bin/sh\nprintf \'%s\\n\' "$*" >> "$CASHPILOT_FAKE_FLUTTER_ARGS"\n';
  fs.writeFileSync(executablePath, source, 'utf8');
  if (process.platform !== 'win32') {
    fs.chmodSync(executablePath, 0o755);
  }
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return {
    argumentsPath,
    env: {
      ...process.env,
      CASHPILOT_FAKE_FLUTTER_ARGS: argumentsPath,
      PATH: `${directory}${path.delimiter}${process.env.PATH ?? ''}`,
    },
  };
}

test('canonical Groq staging JSON pins the intended non-release policy', () => {
  const rawConfig = fs.readFileSync(stagingConfigPath, 'utf8');
  const config = JSON.parse(rawConfig);

  assert.deepEqual(config, intendedNonReleaseStagingConfig);
  assert.ok(Object.values(config).every((value) => typeof value === 'string'));
  assert.ok(
    Object.keys(config).every((key) => !forbiddenConfigKeyPattern.test(key)),
  );
  assert.doesNotMatch(rawConfig, forbiddenGroqClientContentPattern);
});

test('Flutter source and assets contain no Groq client credential', () => {
  const flutterClientRoots = [
    path.join(repositoryRoot, 'lib'),
    path.join(repositoryRoot, 'assets'),
    path.join(repositoryRoot, 'web'),
    path.join(repositoryRoot, 'android', 'app', 'src', 'main', 'assets'),
    path.join(repositoryRoot, 'ios', 'Runner'),
  ];
  const offendingFiles = flutterClientRoots
    .flatMap(filesBelow)
    .filter((file) =>
      forbiddenGroqClientContentPattern.test(fs.readFileSync(file, 'latin1')),
    )
    .map((file) => path.relative(repositoryRoot, file));

  assert.deepEqual(offendingFiles, []);
  const pubspec = fs.readFileSync(pubspecPath, 'utf8');
  assert.doesNotMatch(pubspec, /groq_staging\.json/iu);
  assert.doesNotMatch(pubspec, /^\s*-\s+config(?:[\\/]|\s*$)/imu);
});

test('canonical Groq staging runner validates without reading a secret file', (t) => {
  const result = runRunner(['-ValidateOnly']);
  if (result.error?.code === 'ENOENT') {
    t.skip('PowerShell is unavailable on this platform.');
    return;
  }

  assert.equal(result.status, 0, result.stderr);
  assert.match(
    result.stdout,
    /CASH_PILOT_GROQ_STAGING_CONFIG status=valid environment=staging provider=groq fallback=false secrets=false/u,
  );
  assert.doesNotMatch(result.stdout + result.stderr, /https?:\/\//iu);

  const source = fs.readFileSync(runnerPath, 'utf8');
  assert.match(source, /--dart-define-from-file=/u);
  assert.doesNotMatch(source, /\.dart-define\.appcheck/u);
  assert.doesNotMatch(source, /FIREBASE_APP_CHECK_DEBUG_TOKEN/u);
});

test('canonical runner keeps build and launch arguments functional', (t) => {
  const fakeFlutter = installFakeFlutter(t);
  const build = runRunner(['-BuildOnly'], { env: fakeFlutter.env });
  if (build.error?.code === 'ENOENT') {
    t.skip('PowerShell is unavailable on this platform.');
    return;
  }
  assert.equal(build.status, 0, build.stderr);
  assert.match(
    build.stdout,
    /CASH_PILOT_GROQ_STAGING_BUILD status=completed/u,
  );

  const launch = runRunner(['-DeviceId', 'synthetic-device'], {
    env: fakeFlutter.env,
  });
  assert.equal(launch.status, 0, launch.stderr);
  assert.match(
    launch.stdout,
    /CASH_PILOT_GROQ_STAGING_RUN status=launched mode=debug/u,
  );

  const invocations = fs
    .readFileSync(fakeFlutter.argumentsPath, 'utf8')
    .split(/\r?\n/u)
    .filter(Boolean);
  assert.equal(invocations.length, 2);
  assert.match(invocations[0], /^build apk --debug --no-pub /u);
  assert.match(invocations[0], /--dart-define-from-file=.*groq_staging\.json/u);
  assert.match(
    invocations[1],
    /^run --debug --no-pub --no-resident -d synthetic-device /u,
  );
  assert.match(invocations[1], /--dart-define-from-file=.*groq_staging\.json/u);
  assert.ok(
    invocations.every(
      (value) => !/token|secret|password|api[_-]?key/iu.test(value),
    ),
  );
});

test('canonical runner rejects contradictory modes before Flutter lookup', (t) => {
  const result = runRunner(['-BuildOnly', '-ValidateOnly']);
  if (result.error?.code === 'ENOENT') {
    t.skip('PowerShell is unavailable on this platform.');
    return;
  }

  assert.notEqual(result.status, 0);
  assert.match(
    result.stdout + result.stderr,
    /BuildOnly and ValidateOnly cannot be combined/u,
  );
  assert.doesNotMatch(
    result.stdout + result.stderr,
    /Flutter is unavailable on PATH/u,
  );
});

test('VS Code exposes the three canonical Flutter profiles', () => {
  const launch = JSON.parse(fs.readFileSync(launchPath, 'utf8'));
  const profiles = new Map(
    launch.configurations.map((profile) => [profile.name, profile]),
  );
  const expectedNames = [
    'CashPilot Android — Groq Staging',
    'CashPilot Android — Local Debug',
    'CashPilot Web — Staging',
  ];

  assert.deepEqual([...profiles.keys()], expectedNames);
  for (const name of expectedNames) {
    assert.equal(profiles.get(name).type, 'dart');
    assert.equal(profiles.get(name).request, 'launch');
    assert.equal(profiles.get(name).program, 'lib/main.dart');
    assert.equal(profiles.get(name).flutterMode, 'debug');
    assert.ok(
      profiles
        .get(name)
        .toolArgs.every(
          (argument) =>
            !/token|secret|password|api[_-]?key/iu.test(argument),
        ),
    );
  }
  assert.deepEqual(profiles.get(expectedNames[0]).toolArgs, [
    '--dart-define-from-file=${workspaceFolder}/config/groq_staging.json',
  ]);
  assert.ok(
    profiles
      .get(expectedNames[1])
      .toolArgs.includes('--dart-define=CASH_PILOT_AI_PROVIDER=localParserOnly'),
  );
  assert.deepEqual(profiles.get(expectedNames[1]).toolArgs, [
    '--dart-define=CASH_PILOT_ENVIRONMENT=local',
    '--dart-define=CASH_PILOT_AI_PROVIDER=localParserOnly',
    '--dart-define=CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED=false',
  ]);
  assert.equal(profiles.get(expectedNames[2]).deviceId, 'chrome');
  assert.equal(
    profiles.get(expectedNames[2]).preLaunchTask,
    'CashPilot: Prepare Web App Check',
  );
  assert.deepEqual(profiles.get(expectedNames[2]).toolArgs, [
    '--dart-define-from-file=${workspaceFolder}/.dart-define.groq-staging.local.json',
  ]);

  const tasks = JSON.parse(fs.readFileSync(tasksPath, 'utf8'));
  const prepareTask = tasks.tasks.find(
    (entry) => entry.label === 'CashPilot: Prepare Web App Check',
  );
  assert.equal(prepareTask.type, 'process');
  assert.equal(prepareTask.command, 'node');
  assert.deepEqual(prepareTask.args, [
    '${workspaceFolder}/tool/prepare_web_app_check_debug.cjs',
  ]);
});
