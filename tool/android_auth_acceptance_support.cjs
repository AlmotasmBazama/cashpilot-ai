'use strict';

function createAndroidAuthAcceptanceSupport({
  adbExec,
  assertBoundedUiXml,
  deviceViewport,
  findUiTarget,
  inputText,
  isTransientUiSnapshotError,
  nowImpl = Date.now,
  openSettingsPage,
  resetSettingsScroll,
  safeRunnerError,
  settingsScreenSize,
  snapshotUi,
  strictSettingsResourceId,
  tapPoint,
  tapTarget,
  uiNodesWithParents,
  waitForTarget,
  waitImpl,
}) {
  const wait = waitImpl;

const maxLoginSubmitScrollSteps = 8;

const loginAcceptanceStates = new Set([
  'idle',
  'ready',
  'submitting',
  'failure_invalid_form',
  'failure_invalid_credentials',
  'failure_network',
  'failure_permission_denied',
  'failure_unauthenticated',
  'failure_session_changed',
  'failure_rate_limited',
  'failure_provider_disabled',
  'failure_user_disabled',
  'failure_unknown',
]);

function authSurfaceFromUiXml(xml) {
  const email = findUiTarget(xml, 'email');
  const password = findUiTarget(xml, 'password');
  if (email && password) {
    return 'signedOut';
  }
  if (
    findUiTarget(xml, 'authenticatedShell') ||
    findUiTarget(xml, 'settings')
  ) {
    return 'signedIn';
  }
  if (findUiTarget(xml, 'skip') || findUiTarget(xml, 'login')) {
    return 'entry';
  }
  return 'unknown';
}

function loginStateFromUiXml(xml) {
  assertBoundedUiXml(xml);
  const prefix = 'cashpilot_acceptance_login_state_';
  const states = [];
  for (const node of uiNodesWithParents(xml)) {
    const identifier = strictSettingsResourceId(
      node.attributes['resource-id'] || '',
    );
    if (identifier === null || !identifier.startsWith(prefix)) {
      continue;
    }
    const state = identifier.slice(prefix.length);
    if (!loginAcceptanceStates.has(state)) {
      throw safeRunnerError('login_state_invalid');
    }
    states.push(state);
  }
  if (states.length === 0) {
    return null;
  }
  if (states.length !== 1) {
    throw safeRunnerError('login_state_ambiguous');
  }
  return states[0];
}

async function observeLoginAuthentication({
  readSnapshot,
  waitImpl = wait,
  now = nowImpl,
  timeoutMs = 60_000,
}) {
  if (
    typeof readSnapshot !== 'function' ||
    typeof waitImpl !== 'function' ||
    typeof now !== 'function' ||
    !Number.isSafeInteger(timeoutMs) ||
    timeoutMs < 1 ||
    timeoutMs > 120_000
  ) {
    throw safeRunnerError('login_observer_contract_invalid');
  }
  const deadline = now() + timeoutMs;
  let lastState = null;
  let submittingObserved = false;
  while (now() <= deadline) {
    let xml;
    try {
      xml = await readSnapshot();
      if (findUiTarget(xml, 'authenticatedShell')) {
        return Object.freeze({
          authenticated: true,
          submittingObserved,
        });
      }
      const state = loginStateFromUiXml(xml);
      if (state !== null) {
        lastState = state;
      }
      if (state === 'submitting') {
        submittingObserved = true;
      } else if (state?.startsWith('failure_')) {
        throw safeRunnerError(`ui_login_${state}`);
      }
    } catch (error) {
      if (!isTransientUiSnapshotError(error)) {
        throw error;
      }
    } finally {
      xml = undefined;
    }
    await waitImpl(300);
  }
  if (lastState === 'submitting') {
    throw safeRunnerError('ui_login_submitting_timed_out');
  }
  if (lastState === 'ready' || lastState === 'idle') {
    throw safeRunnerError('ui_login_submit_not_observed');
  }
  throw safeRunnerError('ui_authenticated_shell_timed_out');
}

function credentialClearCommands() {
  return Object.freeze([
    Object.freeze([
      'shell',
      'input',
      'keycombination',
      'KEYCODE_CTRL_LEFT',
      'KEYCODE_A',
    ]),
    Object.freeze(['shell', 'input', 'keyevent', 'KEYCODE_DEL']),
  ]);
}

function emailInputCommands(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9@._-]+$/.test(value)) {
    throw safeRunnerError('ui_input_shape_invalid');
  }
  const commands = [];
  let segment = '';
  const flush = () => {
    if (segment === '') return;
    commands.push(['shell', 'input', 'text', segment]);
    segment = '';
  };
  for (const character of value) {
    if (character === '@' || character === '.') {
      flush();
      commands.push([
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
  if (commands.length === 0) {
    throw safeRunnerError('ui_input_shape_invalid');
  }
  return Object.freeze(commands.map((command) => Object.freeze(command)));
}

async function waitForLoginState(deviceId, expectedState, timeoutMs = 10_000) {
  if (!loginAcceptanceStates.has(expectedState)) {
    throw safeRunnerError('login_expected_state_invalid');
  }
  const deadline = nowImpl() + timeoutMs;
  while (nowImpl() <= deadline) {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      const state = loginStateFromUiXml(xml);
      if (state === expectedState) {
        return state;
      }
      if (state?.startsWith('failure_')) {
        throw safeRunnerError(`ui_login_${state}`);
      }
    } catch (error) {
      if (!isTransientUiSnapshotError(error)) {
        throw error;
      }
    } finally {
      xml = undefined;
    }
    await wait(200);
  }
  throw safeRunnerError(`ui_login_${expectedState}_timed_out`);
}

function waitForAuthenticatedLoginOutcome(deviceId) {
  return observeLoginAuthentication({
    readSnapshot: () => snapshotUi(deviceId),
  });
}

async function reachLoginScreen(deviceId) {
  const deadline = nowImpl() + 45_000;
  while (nowImpl() <= deadline) {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      if (findUiTarget(xml, 'email') && findUiTarget(xml, 'password')) {
        return;
      }
      const skip = findUiTarget(xml, 'skip');
      if (skip) {
        tapPoint(deviceId, skip);
        await wait(400);
        continue;
      }
      const login = findUiTarget(xml, 'login');
      if (login) {
        tapPoint(deviceId, login);
        await wait(400);
        continue;
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
  throw safeRunnerError('ui_login_screen_timed_out');
}

async function normalizeSignedOutSession(
  deviceId,
  {
    snapshotImpl = snapshotUi,
    tapPointImpl = tapPoint,
    logoutImpl = bestEffortLogout,
    waitImpl = wait,
    now = nowImpl,
    timeoutMs = 45_000,
  } = {},
) {
  const deadline = now() + timeoutMs;
  let priorSession = false;
  while (now() <= deadline) {
    let xml;
    try {
      xml = snapshotImpl(deviceId);
      const surface = authSurfaceFromUiXml(xml);
      if (surface === 'signedOut') {
        return Object.freeze({ signedOut: true, priorSession });
      }
      if (surface === 'entry') {
        const entryPoint =
          findUiTarget(xml, 'skip') || findUiTarget(xml, 'login');
        if (!entryPoint) {
          throw safeRunnerError('prior_auth_entry_unavailable');
        }
        await tapPointImpl(deviceId, entryPoint);
        await waitImpl(400);
        continue;
      }
      if (surface === 'signedIn') {
        const signedOut = await logoutImpl(deviceId);
        if (!signedOut) {
          throw safeRunnerError('prior_auth_logout_failed');
        }
        priorSession = true;
        await waitImpl(300);
        continue;
      }
    } catch (error) {
      if (!isTransientUiSnapshotError(error)) {
        throw error;
      }
    } finally {
      xml = undefined;
    }
    await waitImpl(300);
  }
  throw safeRunnerError('prior_auth_state_unavailable');
}

async function findAndTapLoginSubmit({
  readTarget,
  scrollForward,
  tap,
  waitImpl = wait,
  maxScrollSteps = maxLoginSubmitScrollSteps,
}) {
  if (
    typeof readTarget !== 'function' ||
    typeof scrollForward !== 'function' ||
    typeof tap !== 'function' ||
    typeof waitImpl !== 'function' ||
    !Number.isSafeInteger(maxScrollSteps) ||
    maxScrollSteps < 0 ||
    maxScrollSteps > maxLoginSubmitScrollSteps
  ) {
    throw safeRunnerError('login_submit_contract_invalid');
  }
  for (let step = 0; step <= maxScrollSteps; step += 1) {
    const point = await readTarget();
    if (point !== null) {
      await tap(point);
      return Object.freeze({ scrollSteps: step });
    }
    if (step < maxScrollSteps) {
      await scrollForward();
      await waitImpl(200);
    }
  }
  throw safeRunnerError('ui_login_submit_timed_out');
}

function swipeLoginForward(deviceId) {
  const { width, height } = settingsScreenSize(deviceId);
  const x = Math.floor(width / 2);
  adbExec(
    deviceId,
    [
      'shell',
      'input',
      'swipe',
      String(x),
      String(Math.floor(height * 0.72)),
      String(x),
      String(Math.floor(height * 0.32)),
      '250',
    ],
    { safeCode: 'ui_login_scroll_failed' },
  );
}

async function tapLoginSubmit(deviceId) {
  const viewport = deviceViewport(deviceId);
  return findAndTapLoginSubmit({
    readTarget: () => {
      let xml;
      try {
        xml = snapshotUi(deviceId);
        return findUiTarget(xml, 'loginSubmit', viewport);
      } catch (error) {
        if (isTransientUiSnapshotError(error)) {
          return null;
        }
        throw error;
      } finally {
        xml = undefined;
      }
    },
    scrollForward: () => swipeLoginForward(deviceId),
    tap: (point) => tapPoint(deviceId, point),
  });
}

async function fillAndSubmitLogin({
  waitForEmail,
  tapEmail,
  inputEmail,
  waitForPassword,
  tapPassword,
  inputPassword,
  waitForReady,
  tapSubmit,
  waitForAuthenticated,
}) {
  const operations = [
    waitForEmail,
    tapEmail,
    inputEmail,
    waitForPassword,
    tapPassword,
    inputPassword,
    waitForReady,
    tapSubmit,
    waitForAuthenticated,
  ];
  if (operations.some((operation) => typeof operation !== 'function')) {
    throw safeRunnerError('login_input_contract_invalid');
  }
  const emailPoint = await waitForEmail();
  await tapEmail(emailPoint);
  await inputEmail();
  const passwordPoint = await waitForPassword();
  await tapPassword(passwordPoint);
  await inputPassword();
  await waitForReady();
  await tapSubmit();
  await waitForAuthenticated();
  return true;
}

async function loginSyntheticUser(deviceId, synthetic) {
  return fillAndSubmitLogin({
    waitForEmail: () => waitForTarget(deviceId, 'email'),
    tapEmail: (point) => tapPoint(deviceId, point),
    inputEmail: () => inputText(deviceId, synthetic.email, 'email'),
    waitForPassword: () => waitForTarget(deviceId, 'password'),
    tapPassword: (point) => tapPoint(deviceId, point),
    inputPassword: () =>
      inputText(deviceId, synthetic.password, 'password'),
    waitForReady: () => waitForLoginState(deviceId, 'ready'),
    tapSubmit: () => tapLoginSubmit(deviceId),
    waitForAuthenticated: () => waitForAuthenticatedLoginOutcome(deviceId),
  });
}

async function performResourceIdLogout({
  openSettings,
  waitForSettingsCard,
  resetScroll,
  tapLogout,
  waitForEmail,
  waitForPassword,
}) {
  const operations = [
    openSettings,
    waitForSettingsCard,
    resetScroll,
    tapLogout,
    waitForEmail,
    waitForPassword,
  ];
  if (operations.some((operation) => typeof operation !== 'function')) {
    throw safeRunnerError('logout_contract_invalid');
  }
  await openSettings();
  await waitForSettingsCard();
  await resetScroll();
  await tapLogout();
  await waitForEmail();
  await waitForPassword();
  return true;
}

async function bestEffortLogout(deviceId) {
  try {
    return await performResourceIdLogout({
      openSettings: () => openSettingsPage(deviceId),
      waitForSettingsCard: () =>
        waitForTarget(deviceId, 'settingsCard', 15_000),
      resetScroll: () => resetSettingsScroll(deviceId),
      tapLogout: () => tapTarget(deviceId, 'logout', 15_000),
      waitForEmail: () => waitForTarget(deviceId, 'email', 20_000),
      waitForPassword: () => waitForTarget(deviceId, 'password', 20_000),
    });
  } catch {
    return false;
  }
}

  return Object.freeze({
    authSurfaceFromUiXml,
    bestEffortLogout,
    credentialClearCommands,
    emailInputCommands,
    fillAndSubmitLogin,
    findAndTapLoginSubmit,
    loginStateFromUiXml,
    loginSyntheticUser,
    normalizeSignedOutSession,
    observeLoginAuthentication,
    performResourceIdLogout,
    reachLoginScreen,
    swipeLoginForward,
    tapLoginSubmit,
    waitForAuthenticatedLoginOutcome,
    waitForLoginState,
  });
}

module.exports = { createAndroidAuthAcceptanceSupport };
