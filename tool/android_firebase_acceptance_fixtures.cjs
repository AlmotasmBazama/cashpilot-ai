'use strict';

const path = require('node:path');

function createFirebaseAcceptanceFixtures({
  repositoryRoot,
  packageName,
  firebaseProjectId,
  readFileSync,
  randomBytes,
  fetchImplementation = fetch,
  timeoutSignal = AbortSignal.timeout.bind(AbortSignal),
  waitImpl,
  readSdkManagedDebugSecret,
  registerDebugSecret,
  firebaseCliAccessToken,
  safeRunnerError,
}) {
  const fetch = fetchImplementation;
  const AbortSignal = Object.freeze({ timeout: timeoutSignal });
  const wait = waitImpl;

function loadFirebaseClientConfiguration() {
  let raw;
  try {
    raw = readFileSync(
      path.join(repositoryRoot, 'android', 'app', 'google-services.json'),
      'utf8',
    );
    const config = JSON.parse(raw);
    if (config?.project_info?.project_id !== firebaseProjectId) {
      throw safeRunnerError('firebase_project_mismatch');
    }
    const client = config.client?.find(
      (entry) =>
        entry?.client_info?.android_client_info?.package_name === packageName,
    );
    const apiKey = client?.api_key?.[0]?.current_key;
    if (typeof apiKey !== 'string' || apiKey.length < 20) {
      throw safeRunnerError('firebase_client_config_invalid');
    }
    return Object.freeze({ apiKey });
  } catch (error) {
    if (error?.safeCode) {
      throw error;
    }
    throw safeRunnerError('firebase_client_config_invalid');
  } finally {
    raw = undefined;
  }
}

async function createSyntheticUser(cloud) {
  const suffix = randomBytes(8).toString('hex');
  const localId = `cp-restart-${suffix}`;
  const email = `cp-${suffix}@example.com`;
  const password = syntheticPassword(
    randomBytes(16).toString('hex'),
  );
  let failureCode = 'synthetic_user_create_failed';
  try {
    const createResponse = await fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${cloud.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          displayName: 'CashPilot Restart Acceptance',
          email,
          emailVerified: true,
          localId,
          password,
          targetProjectId: firebaseProjectId,
        }),
        signal: AbortSignal.timeout(15_000),
      },
    ).catch(() => null);
    if (createResponse === null) {
      throw safeRunnerError(failureCode);
    }
    if (!createResponse.ok) {
      failureCode = await safeFirebaseFailureCode(
        createResponse,
        'synthetic_user_create',
      );
      throw safeRunnerError(failureCode);
    }
    const created = await createResponse.json().catch(() => null);
    if (created?.localId !== localId) {
      failureCode = 'synthetic_user_create_invalid';
      throw safeRunnerError(failureCode);
    }
    const synthetic = { email, password, localId };
    await verifySyntheticUser(cloud, synthetic);
    await verifySyntheticCredentials(cloud, synthetic);
    await createSyntheticProfile(cloud, synthetic);
    return synthetic;
  } catch (error) {
    const [profileDeletedOrAbsent, userDeletedOrAbsent] = await Promise.all([
      deleteSyntheticProfile(cloud, { localId }),
      deleteSyntheticUser(cloud, { localId }),
    ]);
    if (!profileDeletedOrAbsent || !userDeletedOrAbsent) {
      throw safeRunnerError('synthetic_user_partial_cleanup_failed');
    }
    throw error;
  }
}

function syntheticPassword(randomHex) {
  if (typeof randomHex !== 'string' || !/^[0-9a-f]{32}$/.test(randomHex)) {
    throw safeRunnerError('synthetic_password_source_invalid');
  }
  // Android's shell input can lowercase letters on some API/IME versions.
  // Keep acceptance-only credentials lowercase/digits so the UI receives the
  // exact random value verified through Firebase Auth.
  return `cp9${randomHex.slice(0, 16)}`;
}

async function verifySyntheticCredentials(
  cloud,
  synthetic,
  fetchImpl = fetch,
) {
  if (
    typeof cloud?.apiKey !== 'string' ||
    cloud.apiKey.length < 20 ||
    typeof synthetic?.email !== 'string' ||
    typeof synthetic?.password !== 'string' ||
    typeof synthetic?.localId !== 'string'
  ) {
    throw safeRunnerError('synthetic_credentials_contract_invalid');
  }
  let body;
  try {
    const response = await fetchImpl(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword' +
        `?key=${encodeURIComponent(cloud.apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: synthetic.email,
          password: synthetic.password,
          returnSecureToken: true,
        }),
        signal: AbortSignal.timeout(15_000),
      },
    ).catch(() => null);
    if (response === null) {
      throw safeRunnerError('synthetic_credentials_verify_failed');
    }
    if (!response.ok) {
      throw safeRunnerError(
        `synthetic_credentials_verify_http_${response.status}`,
      );
    }
    body = await response.json().catch(() => null);
    if (
      body?.localId !== synthetic.localId ||
      typeof body?.idToken !== 'string' ||
      body.idToken.length < 20
    ) {
      throw safeRunnerError('synthetic_credentials_verify_invalid');
    }
    return true;
  } finally {
    body = undefined;
  }
}

async function verifySyntheticUser(cloud, synthetic) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${firebaseProjectId}/accounts:query`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        expression: [{ userId: synthetic.localId }],
        limit: '1',
      }),
      signal: AbortSignal.timeout(15_000),
    },
  ).catch(() => null);
  if (!response?.ok) {
    throw safeRunnerError(
      response === null
        ? 'synthetic_user_verify_failed'
        : `synthetic_user_verify_http_${response.status}`,
    );
  }
  const body = await response.json().catch(() => null);
  const user = Array.isArray(body?.userInfo) ? body.userInfo[0] : null;
  if (
    user?.localId !== synthetic.localId ||
    user?.emailVerified !== true ||
    user?.displayName !== 'CashPilot Restart Acceptance'
  ) {
    throw safeRunnerError('synthetic_user_verify_invalid');
  }
}

function firestoreProfileUrl(localId, { createOnly = false } = {}) {
  const documentUrl =
    `https://firestore.googleapis.com/v1/projects/${firebaseProjectId}` +
    `/databases/(default)/documents/users/${encodeURIComponent(localId)}`;
  return createOnly
    ? `${documentUrl}?currentDocument.exists=false`
    : documentUrl;
}

async function createSyntheticProfile(cloud, synthetic, fetchImpl = fetch) {
  const now = new Date().toISOString();
  const response = await fetchImpl(
    firestoreProfileUrl(synthetic.localId, { createOnly: true }),
    {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${cloud.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        fields: {
          uid: { stringValue: synthetic.localId },
          name: { stringValue: 'CashPilot Restart Acceptance' },
          email: { stringValue: synthetic.email },
          currency: { stringValue: 'LYD' },
          language: { stringValue: 'en' },
          country: { stringValue: 'LY' },
          timezone: { stringValue: 'UTC' },
          createdAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
          lastLogin: { timestampValue: now },
        },
      }),
      signal: AbortSignal.timeout(15_000),
    },
  ).catch(() => null);
  if (!response?.ok) {
    throw safeRunnerError(
      response === null
        ? 'synthetic_profile_create_failed'
        : `synthetic_profile_create_http_${response.status}`,
    );
  }
  const body = await response.json().catch(() => null);
  const expectedSuffix = `/documents/users/${synthetic.localId}`;
  if (
    typeof body?.name !== 'string' ||
    !body.name.endsWith(expectedSuffix) ||
    !profileDocumentMatches(body, synthetic)
  ) {
    throw safeRunnerError('synthetic_profile_create_invalid');
  }
}

function profileDocumentMatches(document, synthetic) {
  const fields = document?.fields;
  return (
    fields?.uid?.stringValue === synthetic.localId &&
    fields?.name?.stringValue === 'CashPilot Restart Acceptance' &&
    fields?.email?.stringValue === synthetic.email &&
    fields?.currency?.stringValue === 'LYD' &&
    fields?.language?.stringValue === 'en' &&
    fields?.country?.stringValue === 'LY' &&
    fields?.timezone?.stringValue === 'UTC'
  );
}

async function readSyntheticProfileState(cloud, synthetic, fetchImpl) {
  const response = await fetchImpl(firestoreProfileUrl(synthetic.localId), {
    method: 'GET',
    headers: { Authorization: `Bearer ${cloud.accessToken}` },
    signal: AbortSignal.timeout(15_000),
  }).catch(() => null);
  if (response === null) {
    return 'unknown';
  }
  if (response.status === 404) {
    return 'absent';
  }
  if (!response.ok) {
    return 'unknown';
  }
  const body = await response.json().catch(() => null);
  return profileDocumentMatches(body, synthetic) ? 'matching' : 'mismatch';
}

async function deleteSyntheticProfile(
  cloud,
  synthetic,
  fetchImpl = fetch,
  waitImpl = wait,
) {
  let state = await readSyntheticProfileState(cloud, synthetic, fetchImpl);
  if (state === 'absent') {
    return true;
  }
  if (state !== 'matching') {
    return false;
  }
  for (let attempt = 0; attempt < 3; attempt += 1) {
    await fetchImpl(firestoreProfileUrl(synthetic.localId), {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${cloud.accessToken}` },
      signal: AbortSignal.timeout(15_000),
    }).catch(() => null);
    state = await readSyntheticProfileState(cloud, synthetic, fetchImpl);
    if (state === 'absent') {
      return true;
    }
    if (state !== 'matching') {
      return false;
    }
    await waitImpl(200);
  }
  return false;
}

async function safeFirebaseFailureCode(response, prefix) {
  const failure = await response.json().catch(() => null);
  const status = failure?.error?.status;
  const messageCode =
    typeof failure?.error?.message === 'string'
      ? failure.error.message.match(/^[A-Z][A-Z0-9_]+/)?.[0]
      : null;
  const safeReason =
    typeof messageCode === 'string'
      ? messageCode.toLowerCase()
      : typeof status === 'string' && /^[A-Z][A-Z0-9_]+$/.test(status)
      ? status.toLowerCase()
      : `http_${response.status}`;
  return `${prefix}_${safeReason}`;
}

async function deleteSyntheticUser(cloud, synthetic) {
  try {
    const response = await fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:delete',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${cloud.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          localId: synthetic.localId,
          targetProjectId: firebaseProjectId,
        }),
        signal: AbortSignal.timeout(15_000),
      },
    );
    if (response.ok) {
      return true;
    }
    const failure = await response.json().catch(() => null);
    return (
      typeof failure?.error?.message === 'string' &&
      failure.error.message.startsWith('USER_NOT_FOUND')
    );
  } catch {
    return false;
  }
}

async function loadCloudCredentials() {
  const firebase = loadFirebaseClientConfiguration();
  const accessToken = await firebaseCliAccessToken().catch(() => {
    throw safeRunnerError('firebase_cli_auth_unavailable');
  });
  return { accessToken, apiKey: firebase.apiKey };
}

async function registerAcceptanceAppCheck(deviceId, cloud) {
  const deadline = Date.now() + 45_000;
  let debugSecret;
  while (Date.now() <= deadline && !debugSecret) {
    try {
      debugSecret = readSdkManagedDebugSecret(deviceId);
    } catch {
      await wait(300);
    }
  }
  if (!debugSecret) {
    throw safeRunnerError('app_check_debug_store_timed_out');
  }
  try {
    return await registerDebugSecret({
      accessToken: cloud.accessToken,
      debugSecret,
      suite: 'force-stop-reopen',
    });
  } finally {
    debugSecret = undefined;
  }
}

async function deleteAppCheckRegistration(cloud, registration) {
  if (!registration?.resourceCreated || !registration.resourceName) {
    return !registration?.resourceCreated;
  }
  if (
    !/^projects\/[0-9]+\/apps\/[A-Za-z0-9:_-]+\/debugTokens\/[A-Za-z0-9_-]+$/.test(
      registration.resourceName,
    )
  ) {
    return false;
  }
  try {
    const response = await fetch(
      `https://firebaseappcheck.googleapis.com/v1/${registration.resourceName}`,
      {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${cloud.accessToken}` },
        signal: AbortSignal.timeout(10_000),
      },
    );
    return response.ok;
  } catch {
    return false;
  }
}

  return Object.freeze({
    createSyntheticProfile,
    createSyntheticUser,
    deleteAppCheckRegistration,
    deleteSyntheticProfile,
    deleteSyntheticUser,
    firestoreProfileUrl,
    loadCloudCredentials,
    registerAcceptanceAppCheck,
    syntheticPassword,
    verifySyntheticCredentials,
  });
}

module.exports = { createFirebaseAcceptanceFixtures };
