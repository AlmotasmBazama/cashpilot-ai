'use strict';

function createAndroidSettingsAcceptanceSupport({
  adbExec,
  assertBoundedUiXml,
  deviceViewport,
  findUiTarget,
  isTransientUiSnapshotError,
  nodeAttributes,
  nowImpl = Date.now,
  safeCodeFor,
  safeRunnerError,
  settingsScreenSize,
  snapshotUi,
  strictSettingsResourceId,
  tapPoint,
  validViewport,
  waitForTarget,
  waitImpl,
}) {
  const wait = waitImpl;

// Use overlapping forward swipes so a short group of accessibility rows
// cannot fall entirely between two uiautomator snapshots. The larger bound
// preserves the same total reach across the long Settings list.
const maxSettingsScrollSteps = 28;
const settingsResetScrollSteps = 14;
const maxSettingsScanRefreshes = 3;
const settingsLiveTestSettleMs = 55_000;
const settingsRequiredResourceIds = Object.freeze([
  'ai_settings_card',
  'ai_settings_remote_groq',
  'ai_settings_general_20b',
  'ai_settings_financial_120b',
  'ai_settings_local_parser',
  'ai_settings_receipt_firebase',
  'ai_settings_fallback_disabled',
  'ai_settings_gateway_available',
  'ai_settings_auth_ready',
  'ai_settings_appcheck_verified',
  'ai_settings_live_test',
]);
const settingsRequiredResourceIdSet = new Set(settingsRequiredResourceIds);

function settingsStateFromUiXml(xml) {
  assertBoundedUiXml(xml);
  const rowIds = new Set();
  const testStatuses = new Set();
  for (const node of xml.matchAll(/<node\s+([^>]+)>?/g)) {
    const resourceId = nodeAttributes(node[1])['resource-id'] || '';
    const identifier = strictSettingsResourceId(resourceId);
    if (identifier === null) {
      continue;
    }
    if (settingsRequiredResourceIdSet.has(identifier)) {
      rowIds.add(identifier);
    }
    const statusMatch = /^ai_settings_test_([a-z][a-z0-9_]{0,31})$/.exec(
      identifier,
    );
    if (statusMatch) {
      testStatuses.add(statusMatch[1]);
    }
  }
  if (testStatuses.size > 1) {
    throw safeRunnerError('settings_test_state_ambiguous');
  }
  return Object.freeze({
    rowIds: Object.freeze([...rowIds]),
    testStatus: testStatuses.size === 1 ? [...testStatuses][0] : null,
  });
}

function safeSettingsPresence(observed, testStatus) {
  return Object.freeze({
    card: observed.has('ai_settings_card'),
    remoteGroq: observed.has('ai_settings_remote_groq'),
    general20b: observed.has('ai_settings_general_20b'),
    financial120b: observed.has('ai_settings_financial_120b'),
    localParser: observed.has('ai_settings_local_parser'),
    receiptFirebase: observed.has('ai_settings_receipt_firebase'),
    fallbackDisabled: observed.has('ai_settings_fallback_disabled'),
    gatewayAvailable: observed.has('ai_settings_gateway_available'),
    authReady: observed.has('ai_settings_auth_ready'),
    appCheckVerified: observed.has('ai_settings_appcheck_verified'),
    liveTest: observed.has('ai_settings_live_test'),
    dynamicStatus: testStatus !== null,
  });
}

async function collectRequiredSettingsRows({
  snapshot,
  scroll,
  viewport = null,
  waitImpl = wait,
  maxScrollSteps = maxSettingsScrollSteps,
}) {
  if (
    typeof snapshot !== 'function' ||
    typeof scroll !== 'function' ||
    typeof waitImpl !== 'function' ||
    (viewport !== null && !validViewport(viewport)) ||
    !Number.isSafeInteger(maxScrollSteps) ||
    maxScrollSteps < 0 ||
    maxScrollSteps > maxSettingsScrollSteps
  ) {
    throw safeRunnerError('settings_scroll_contract_invalid');
  }
  const observed = new Set();
  let latestTestStatus = null;
  for (let step = 0; step <= maxScrollSteps; step += 1) {
    let xml;
    let finalLiveTestPoint = null;
    try {
      xml = await snapshot();
      const state = settingsStateFromUiXml(xml);
      finalLiveTestPoint = findUiTarget(xml, 'settingsLiveTest', viewport);
      for (const identifier of state.rowIds) {
        observed.add(identifier);
      }
      if (state.testStatus !== null) {
        latestTestStatus = state.testStatus;
      }
    } finally {
      xml = undefined;
    }
    if (
      latestTestStatus !== null &&
      finalLiveTestPoint !== null &&
      settingsRequiredResourceIds.every((identifier) =>
        observed.has(identifier),
      )
    ) {
      return Object.freeze({
        rowsVerified: true,
        rowCount: observed.size,
        rowIds: Object.freeze([...observed]),
        testStatus: latestTestStatus,
        liveTestPoint: finalLiveTestPoint,
      });
    }
    if (step < maxScrollSteps) {
      await scroll();
      await waitImpl(120);
    }
  }
  const error = safeRunnerError('settings_rows_incomplete');
  error.safeSettingsPresence = safeSettingsPresence(
    observed,
    latestTestStatus,
  );
  throw error;
}

async function collectSettingsRowsAcrossRefreshes({
  scan,
  reset,
  waitImpl = wait,
  maxRefreshes = maxSettingsScanRefreshes,
}) {
  if (
    typeof scan !== 'function' ||
    typeof reset !== 'function' ||
    typeof waitImpl !== 'function' ||
    !Number.isSafeInteger(maxRefreshes) ||
    maxRefreshes < 1 ||
    maxRefreshes > maxSettingsScanRefreshes
  ) {
    throw safeRunnerError('settings_refresh_contract_invalid');
  }
  let retryableError;
  for (let refresh = 0; refresh < maxRefreshes; refresh += 1) {
    await reset();
    try {
      return await scan();
    } catch (error) {
      if (
        safeCodeFor(error) !== 'settings_rows_incomplete' &&
        !isTransientUiSnapshotError(error)
      ) {
        throw error;
      }
      retryableError = error;
      if (refresh + 1 < maxRefreshes) {
        await waitImpl(750);
      }
    }
  }
  throw retryableError || safeRunnerError('settings_rows_incomplete');
}

async function observeSettingsTestTransition({
  baselineStatus,
  readInitialStatus,
  readSettledStatus,
  waitImpl = wait,
  settleDelayMs = settingsLiveTestSettleMs,
}) {
  if (
    typeof readInitialStatus !== 'function' ||
    typeof readSettledStatus !== 'function' ||
    typeof waitImpl !== 'function' ||
    !Number.isSafeInteger(settleDelayMs) ||
    settleDelayMs < 0 ||
    settleDelayMs > settingsLiveTestSettleMs
  ) {
    throw safeRunnerError('settings_test_contract_invalid');
  }
  if (baselineStatus !== 'idle') {
    throw safeRunnerError('settings_live_test_baseline_invalid');
  }
  const initialStatus = await readInitialStatus();
  if (initialStatus === 'available') {
    return Object.freeze({
      baselineIdle: true,
      testingUiObserved: false,
      stateMachineOrdered: true,
      available: true,
    });
  }
  if (initialStatus !== 'testing') {
    if (initialStatus !== null && initialStatus !== 'idle') {
      throw safeRunnerError('settings_live_test_failed');
    }
    throw safeRunnerError('settings_live_test_not_started');
  }
  // After one proof that the tap entered testing, keep the accessibility
  // driver idle while native Firebase token work and the gateway stream run.
  await waitImpl(settleDelayMs);
  const testStatus = await readSettledStatus();
  if (testStatus === 'available') {
    return Object.freeze({
      baselineIdle: true,
      testingUiObserved: true,
      stateMachineOrdered: true,
      available: true,
    });
  }
  if (testStatus !== null && testStatus !== 'idle' && testStatus !== 'testing') {
    throw safeRunnerError('settings_live_test_failed');
  }
  throw safeRunnerError('settings_available_timed_out');
}

async function triggerSettingsLiveTest({
  readTarget,
  tap,
  readStatus,
  waitImpl = wait,
  settleBeforeTapMs = 750,
  settleAfterTapMs = 400,
  maxTapAttempts = 2,
}) {
  if (
    typeof readTarget !== 'function' ||
    typeof tap !== 'function' ||
    typeof readStatus !== 'function' ||
    typeof waitImpl !== 'function' ||
    !Number.isSafeInteger(settleBeforeTapMs) ||
    settleBeforeTapMs < 0 ||
    settleBeforeTapMs > 2_000 ||
    !Number.isSafeInteger(settleAfterTapMs) ||
    settleAfterTapMs < 0 ||
    settleAfterTapMs > 2_000 ||
    !Number.isSafeInteger(maxTapAttempts) ||
    maxTapAttempts < 1 ||
    maxTapAttempts > 2
  ) {
    throw safeRunnerError('settings_tap_contract_invalid');
  }

  let latestStatus = 'idle';
  for (let attempt = 1; attempt <= maxTapAttempts; attempt += 1) {
    // A bounded state-derived settle keeps the first tap from merely stopping
    // the final Settings scroll. A retry is allowed only while the exact
    // package-owned status remains idle; runLiveTest publishes checking
    // synchronously before any token or network work begins.
    await waitImpl(settleBeforeTapMs);
    const point = await readTarget();
    if (point == null) {
      throw safeRunnerError('settings_live_test_unavailable');
    }
    await tap(point);
    await waitImpl(settleAfterTapMs);
    latestStatus = await readStatus();
    if (latestStatus !== null && latestStatus !== 'idle') {
      return Object.freeze({ initialStatus: latestStatus, tapAttempts: attempt });
    }
  }
  return Object.freeze({
    initialStatus: latestStatus,
    tapAttempts: maxTapAttempts,
  });
}

function swipeSettings(deviceId, direction) {
  if (direction !== 'forward' && direction !== 'backward') {
    throw safeRunnerError('settings_scroll_direction_invalid');
  }
  const { width, height } = settingsScreenSize(deviceId);
  const x = Math.floor(width / 2);
  const startY = Math.floor(
    height * (direction === 'forward' ? 0.68 : 0.28),
  );
  const endY = Math.floor(
    height * (direction === 'forward' ? 0.45 : 0.78),
  );
  adbExec(
    deviceId,
    [
      'shell',
      'input',
      'swipe',
      String(x),
      String(startY),
      String(x),
      String(endY),
      '250',
    ],
    { safeCode: 'settings_scroll_failed' },
  );
}

async function resetSettingsScroll(deviceId) {
  for (let step = 0; step < settingsResetScrollSteps; step += 1) {
    swipeSettings(deviceId, 'backward');
    await wait(120);
  }
}

async function openSettingsPage(
  deviceId,
  { requireRestoredRoute = false } = {},
) {
  const deadline = nowImpl() + 45_000;
  while (nowImpl() <= deadline) {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      if (findUiTarget(xml, 'email')) {
        throw safeRunnerError('auth_session_not_restored');
      }
      const state = settingsStateFromUiXml(xml);
      if (
        state.rowIds.length > 0 ||
        state.testStatus !== null ||
        findUiTarget(xml, 'settingsCard')
      ) {
        return;
      }
      const settingsPoint = findUiTarget(xml, 'settings');
      if (settingsPoint) {
        if (requireRestoredRoute) {
          throw safeRunnerError('settings_route_not_restored');
        }
        tapPoint(deviceId, settingsPoint);
        await waitForTarget(deviceId, 'settingsCard', 30_000);
        return;
      }
    } catch (error) {
      if (!isTransientUiSnapshotError(error)) {
        throw error;
      }
    } finally {
      xml = undefined;
    }
    await wait(300);
  }
  throw safeRunnerError(
    requireRestoredRoute
      ? 'settings_route_not_restored'
      : 'settings_navigation_unavailable',
  );
}

async function scanSettingsPage(deviceId) {
  const viewport = deviceViewport(deviceId);
  return collectSettingsRowsAcrossRefreshes({
    reset: () => resetSettingsScroll(deviceId),
    scan: () =>
      collectRequiredSettingsRows({
        snapshot: () => snapshotUi(deviceId),
        scroll: () => swipeSettings(deviceId, 'forward'),
        viewport,
      }),
  });
}

async function verifySettingsPage(deviceId) {
  await openSettingsPage(deviceId);
  return scanSettingsPage(deviceId);
}

async function verifyRestoredSettingsPage(deviceId) {
  await openSettingsPage(deviceId);
  const result = await scanSettingsPage(deviceId);
  return Object.freeze({
    ...result,
    restoredSession: true,
    settingsReopened: true,
    dynamicStatusObserved: result.testStatus !== null,
  });
}

async function runSettingsLiveTest(deviceId, baselineStatus) {
  if (baselineStatus !== 'idle') {
    throw safeRunnerError('settings_live_test_baseline_invalid');
  }
  const viewport = deviceViewport(deviceId);
  const readTarget = () => {
    let xml;
    try {
      // The verified scan is required to finish with this node visible. Read a
      // fresh point from the same package-owned resource ID so a coordinate
      // from an earlier scroll position can never be reused.
      xml = snapshotUi(deviceId);
      return findUiTarget(xml, 'settingsLiveTest', viewport);
    } finally {
      xml = undefined;
    }
  };
  const readStatus = () => {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      return settingsStateFromUiXml(xml).testStatus;
    } finally {
      xml = undefined;
    }
  };
  const trigger = await triggerSettingsLiveTest({
    readTarget,
    tap: (point) => tapPoint(deviceId, point),
    readStatus,
  });
  const transition = await observeSettingsTestTransition({
    baselineStatus,
    readInitialStatus: () => trigger.initialStatus,
    readSettledStatus: async () => (await scanSettingsPage(deviceId)).testStatus,
  });
  return Object.freeze({ ...transition, tapAttempts: trigger.tapAttempts });
}

  return Object.freeze({
    collectRequiredSettingsRows,
    collectSettingsRowsAcrossRefreshes,
    observeSettingsTestTransition,
    openSettingsPage,
    resetSettingsScroll,
    runSettingsLiveTest,
    settingsRequiredResourceIds,
    settingsStateFromUiXml,
    triggerSettingsLiveTest,
    verifyRestoredSettingsPage,
    verifySettingsPage,
  });
}

module.exports = { createAndroidSettingsAcceptanceSupport };
