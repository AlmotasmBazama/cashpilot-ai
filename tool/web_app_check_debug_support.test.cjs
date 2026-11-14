'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  buildWebDefines,
  ensureWebDebugRegistration,
  managedRegistrationLabel,
  readDebugToken,
  readWebFirebaseOptions,
} = require('./web_app_check_debug_support.cjs');

const debugToken = '00000000-1111-2222-3333-444444444444';
const firebase = {
  apiKey: 'firebase-client-key',
  appId: '1:123456789:web:abcdef',
  projectId: 'cashpilot-test',
  projectNumber: '123456789',
};

function response(status, body = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() {
      return body;
    },
  };
}

test('merged Web config keeps staging provider and adds only the local token', () => {
  const merged = buildWebDefines(
    {CASH_PILOT_AI_PROVIDER: 'groq', CASH_PILOT_ENVIRONMENT: 'staging'},
    debugToken,
  );
  assert.deepEqual(merged, {
    CASH_PILOT_AI_PROVIDER: 'groq',
    CASH_PILOT_ENVIRONMENT: 'staging',
    FIREBASE_APP_CHECK_DEBUG_TOKEN: debugToken,
  });
});

test('local secret must contain a UUID-shaped explicit token', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cp-web-app-check-'));
  const filePath = path.join(directory, 'defines.json');
  fs.writeFileSync(
    filePath,
    JSON.stringify({FIREBASE_APP_CHECK_DEBUG_TOKEN: debugToken}),
  );
  assert.equal(readDebugToken(filePath), debugToken);
  fs.writeFileSync(
    filePath,
    JSON.stringify({FIREBASE_APP_CHECK_DEBUG_TOKEN: 'invalid'}),
  );
  assert.throws(
    () => readDebugToken(filePath),
    /web_debug_token_missing_or_invalid/u,
  );
  fs.rmSync(directory, {recursive: true, force: true});
});

test('local secret accepts the UTF-8 BOM written by Windows tools', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cp-web-app-check-'));
  const filePath = path.join(directory, 'defines.json');
  fs.writeFileSync(
    filePath,
    `\uFEFF${JSON.stringify({FIREBASE_APP_CHECK_DEBUG_TOKEN: debugToken})}`,
  );
  assert.equal(readDebugToken(filePath), debugToken);
  fs.rmSync(directory, {recursive: true, force: true});
});

test('Web Firebase identifiers are read from generated FlutterFire options', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cp-web-options-'));
  const filePath = path.join(directory, 'firebase_options.dart');
  fs.writeFileSync(
    filePath,
    `static const FirebaseOptions web = FirebaseOptions(\n` +
      `  apiKey: 'client-key',\n` +
      `  appId: '1:987654321:web:abc123',\n` +
      `  projectId: 'cashpilot-web',\n` +
      `);\n`,
  );
  assert.deepEqual(readWebFirebaseOptions(filePath), {
    apiKey: 'client-key',
    appId: '1:987654321:web:abc123',
    projectId: 'cashpilot-web',
    projectNumber: '987654321',
  });
  fs.rmSync(directory, {recursive: true, force: true});
});

test('accepted stable token never needs Firebase admin access', async () => {
  let accessTokenCalls = 0;
  const result = await ensureWebDebugRegistration({
    debugToken,
    firebase,
    fetchImpl: async () => response(200, {token: 'accepted-token-value-12345'}),
    accessTokenLoader: async () => {
      accessTokenCalls += 1;
      return 'unused';
    },
  });
  assert.deepEqual(result, {
    registration: 'existing',
    removedManagedRegistrations: 0,
  });
  assert.equal(accessTokenCalls, 0);
});

test('rejected token replaces only stale tool-managed registration', async () => {
  const methods = [];
  let exchangeCalls = 0;
  const staleName =
    `projects/${firebase.projectNumber}/apps/${firebase.appId}/debugTokens/stale`;
  const unrelatedName =
    `projects/${firebase.projectNumber}/apps/${firebase.appId}/debugTokens/keep`;
  const fetchImpl = async (url, options = {}) => {
    methods.push(options.method ?? 'GET');
    if (url.includes(':exchangeDebugToken')) {
      exchangeCalls += 1;
      return exchangeCalls === 1
        ? response(403)
        : response(200, {token: 'accepted-token-value-12345'});
    }
    if (url.includes('pageSize=100')) {
      return response(200, {
        debugTokens: [
          {name: staleName, displayName: managedRegistrationLabel},
          {name: unrelatedName, displayName: 'another-developer'},
        ],
      });
    }
    return response(200);
  };

  const result = await ensureWebDebugRegistration({
    debugToken,
    firebase,
    fetchImpl,
    accessTokenLoader: async () => 'firebase-access-token',
  });

  assert.deepEqual(result, {
    registration: 'created',
    removedManagedRegistrations: 1,
  });
  assert.deepEqual(methods, ['POST', 'GET', 'DELETE', 'POST', 'POST']);
});
