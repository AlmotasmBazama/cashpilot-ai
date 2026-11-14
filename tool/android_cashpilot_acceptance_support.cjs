'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const {
  adbPath,
  clearDeviceLogs,
  firebaseCliAccessToken,
  groqDartDefines,
  readSdkManagedDebugSecret,
  registerDebugSecret,
} = require('./android_live_groq_runner_support.cjs');
const {
  assertBoundedUiXml: assertUiXmlWithinLimit,
  maxUiXmlBytes,
  nodeAttributes,
  pointFromBounds,
  pointFromRect,
  rectFromBounds,
  resourceIdMatches,
} = require('./android_uiautomator_xml_primitives.cjs');
const { safeCodeFor } = require('./android_safe_output_primitives.cjs');
const {
  createAdbExecutor,
  createUiDumpLifecycle,
  longPressPoint: executeLongPress,
  tapPoint: executeTap,
} = require('./android_adb_ui_primitives.cjs');
const { createFirebaseAcceptanceFixtures } = require('./android_firebase_acceptance_fixtures.cjs');
const {
  createAndroidSettingsAcceptanceSupport,
} = require('./android_settings_acceptance_support.cjs');
const {
  createAndroidAuthAcceptanceSupport,
} = require('./android_auth_acceptance_support.cjs');
const {
  createAndroidAiQuestionAcceptanceSupport,
} = require('./android_ai_question_acceptance_support.cjs');
const {
  createAndroidDeviceLifecycleSupport,
} = require('./android_device_lifecycle_support.cjs');

const repositoryRoot = path.resolve(__dirname, '..');
const packageName = 'com.example.cashpilot_ai';
const launcherComponent = `${packageName}/.MainActivity`;
const firebaseProjectId = 'cashpilot-ai-a6b49';
const remoteUiDumpPath = '/data/local/tmp/cashpilot_force_stop_ui.xml';

const uiIdentifiers = Object.freeze({
  aiAssistant: ['cashpilot_acceptance_dashboard_ai'],
  authenticatedShell: ['cashpilot_acceptance_authenticated_shell'],
  composer: ['cashpilot_acceptance_ai_composer'],
  dashboard: ['cashpilot_acceptance_nav_dashboard'],
  email: ['cashpilot_acceptance_login_email'],
  login: ['cashpilot_acceptance_welcome_login'],
  loginSubmit: ['cashpilot_acceptance_login_submit'],
  logout: ['cashpilot_acceptance_logout'],
  password: ['cashpilot_acceptance_login_password'],
  send: ['cashpilot_acceptance_ai_send'],
  settings: ['cashpilot_acceptance_nav_settings'],
  settingsCard: ['ai_settings_card'],
  settingsLiveTest: ['ai_settings_live_test'],
  skip: ['cashpilot_acceptance_onboarding_skip'],
});

function safeRunnerError(code) {
  const error = new Error('The force-stop acceptance runner failed safely.');
  error.safeCode = code;
  return error;
}

const firebaseAcceptanceFixtures = createFirebaseAcceptanceFixtures({
  repositoryRoot,
  packageName,
  firebaseProjectId,
  readFileSync: fs.readFileSync,
  randomBytes: crypto.randomBytes,
  fetchImplementation: fetch,
  timeoutSignal: AbortSignal.timeout.bind(AbortSignal),
  waitImpl: wait,
  readSdkManagedDebugSecret,
  registerDebugSecret,
  firebaseCliAccessToken,
  safeRunnerError,
});
const {
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
} = firebaseAcceptanceFixtures;

function validViewport(viewport) {
  return (
    viewport !== null &&
    typeof viewport === 'object' &&
    Number.isSafeInteger(viewport.width) &&
    viewport.width > 0 &&
    Number.isSafeInteger(viewport.height) &&
    viewport.height > 0
  );
}

function pointIsSafelyOnScreen(point, viewport) {
  if (!validViewport(viewport)) {
    return true;
  }
  const verticalInset = Math.max(96, Math.floor(viewport.height * 0.06));
  return (
    point.x >= 0 &&
    point.x < viewport.width &&
    point.y >= verticalInset &&
    point.y < viewport.height - verticalInset
  );
}

function assertBoundedUiXml(xml) {
  assertUiXmlWithinLimit(xml, () => safeRunnerError('ui_snapshot_invalid'));
}

function strictSettingsResourceId(resourceId) {
  if (/^[A-Za-z0-9_]+$/.test(resourceId)) {
    return resourceId;
  }
  const prefix = `${packageName}:id/`;
  if (resourceId.startsWith(prefix)) {
    const identifier = resourceId.slice(prefix.length);
    return /^[A-Za-z0-9_]+$/.test(identifier) ? identifier : null;
  }
  return null;
}

function uiNodesWithParents(xml) {
  const nodes = [];
  const parentStack = [];
  for (const match of xml.matchAll(/<node\s+([^>]*?)(\/?)>|<\/node\s*>/g)) {
    if (match[0].startsWith('</node')) {
      parentStack.pop();
      continue;
    }
    const attributes = nodeAttributes(match[1]);
    const index = nodes.length;
    nodes.push(
      Object.freeze({
        attributes,
        rect: rectFromBounds(attributes.bounds),
        parentIndex:
          parentStack.length === 0
            ? null
            : parentStack[parentStack.length - 1],
      }),
    );
    if (match[2] !== '/') {
      parentStack.push(index);
    }
  }
  return nodes;
}

function findUiTarget(xml, target, viewport = null) {
  assertBoundedUiXml(xml);
  const identifiers = uiIdentifiers[target];
  if (!identifiers) {
    throw safeRunnerError('ui_target_unsupported');
  }
  const nodes = uiNodesWithParents(xml);
  for (let nodeIndex = 0; nodeIndex < nodes.length; nodeIndex += 1) {
    const node = nodes[nodeIndex];
    const { attributes, rect } = node;
    if (attributes.enabled === 'false') {
      continue;
    }
    const resourceId = attributes['resource-id'] || '';
    if (identifiers.some((identifier) => resourceIdMatches(resourceId, identifier))) {
      if (rect === null) {
        continue;
      }
      const trustedPoint = pointFromRect(rect);
      if (
        target === 'loginSubmit' &&
        viewport !== null &&
        (attributes['visible-to-user'] === 'false' ||
          !pointIsSafelyOnScreen(trustedPoint, viewport))
      ) {
        continue;
      }
      if (target !== 'settingsLiveTest') {
        return trustedPoint;
      }
      if (
        viewport === null
          ? attributes['visible-to-user'] === 'false'
          : !pointIsSafelyOnScreen(trustedPoint, viewport)
      ) {
        continue;
      }

      let clickableIndex = nodeIndex;
      while (clickableIndex !== null) {
        const candidate = nodes[clickableIndex];
        if (
          candidate.attributes.enabled !== 'false' &&
          candidate.attributes.clickable === 'true' &&
          candidate.rect !== null &&
          pointIsSafelyOnScreen(pointFromRect(candidate.rect), viewport)
        ) {
          return pointFromRect(candidate.rect);
        }
        clickableIndex = candidate.parentIndex;
      }
      // Flutter can expose the package-owned identifier and the ListTile tap
      // action as sibling platform semantics nodes. The visible identifier's
      // bounds are still inside the physical tile, so its center is the safe
      // fallback when no clickable ancestor exists.
      return pointFromRect(rect);
    }
  }
  return null;
}

const adbExec = createAdbExecutor({
  resolveExecutable: adbPath,
  cwd: repositoryRoot,
  defaultMaxBuffer: maxUiXmlBytes,
  errorForCode: safeRunnerError,
});

const deviceLifecycleSupport = createAndroidDeviceLifecycleSupport({
  adbExec,
  clearDeviceLogs,
  existsSync: fs.existsSync,
  fetchImplementation: fetch,
  groqDartDefines,
  joinPath: path.join,
  launcherComponent,
  packageName,
  repositoryRoot,
  resolveAdbPath: adbPath,
  safeRunnerError,
  spawnSyncImplementation: spawnSync,
  timeoutSignal: AbortSignal.timeout.bind(AbortSignal),
  waitImpl: wait,
});
const {
  acceptanceBuildExtraDefines,
  approvedGatewayHost,
  bestEffortUninstall,
  buildAndInstall,
  clearDeviceLogs: lifecycleClearDeviceLogs,
  currentPid,
  forceStop,
  inspectFeasibility,
  launchFromLauncher,
  pidFromCommandResult,
  proveProcessRestart,
  verifyGatewayHealth,
  waitForNewPid,
  waitForStopped,
} = deviceLifecycleSupport;

const { removeRemoteUiDump, snapshotUi } = createUiDumpLifecycle({
  executeAdb: adbExec,
  remoteUiDumpPath,
  maxUiXmlBytes,
  assertBoundedUiXml,
  errorForCode: safeRunnerError,
});

function deviceViewport(deviceId) {
  const output = adbExec(deviceId, ['shell', 'wm', 'size'], {
    capture: true,
    encoding: 'utf8',
    maxBuffer: 8 * 1024,
    safeCode: 'display_size_unavailable',
  });
  const matches = [...output.matchAll(/(?:Physical|Override) size:\s*([0-9]+)x([0-9]+)/g)];
  const match = matches[matches.length - 1];
  if (!match) {
    throw safeRunnerError('display_size_unavailable');
  }
  const viewport = Object.freeze({
    width: Number(match[1]),
    height: Number(match[2]),
  });
  if (!validViewport(viewport)) {
    throw safeRunnerError('display_size_unavailable');
  }
  return viewport;
}

function tapPoint(deviceId, point) {
  executeTap(adbExec, deviceId, point);
}

function inputText(deviceId, value, kind) {
  const valid =
    (kind === 'email' && /^[A-Za-z0-9@._-]+$/.test(value)) ||
    (kind === 'password' && /^[A-Za-z0-9]+$/.test(value)) ||
    (kind === 'question' && /^[A-Za-z0-9 .]+$/.test(value));
  if (!valid || value.length > 200) {
    throw safeRunnerError('ui_input_shape_invalid');
  }
  if (kind === 'email' || kind === 'password') {
    for (const command of credentialClearCommands()) {
      adbExec(deviceId, command, {
        safeCode: 'ui_input_clear_failed',
        timeoutMs: 15_000,
      });
    }
  }
  if (kind === 'email') {
    for (const command of emailInputCommands(value)) {
      adbExec(deviceId, command, {
        safeCode: 'ui_input_failed',
        timeoutMs: 30_000,
      });
    }
    return;
  }
  const adbEncoded = value.replaceAll(' ', '%s');
  adbExec(deviceId, ['shell', 'input', 'text', adbEncoded], {
    safeCode: 'ui_input_failed',
    timeoutMs: 30_000,
  });
}


function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitForTarget(deviceId, target, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      const point = findUiTarget(xml, target);
      if (point) {
        return point;
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
  const safeTarget = target.replace(
    /[A-Z]/g,
    (character) => `_${character.toLowerCase()}`,
  );
  throw safeRunnerError(`ui_${safeTarget}_timed_out`);
}


async function tapTarget(deviceId, target, timeoutMs) {
  const point = await waitForTarget(deviceId, target, timeoutMs);
  tapPoint(deviceId, point);
}

function isTransientUiSnapshotError(error) {
  const code = safeCodeFor(error);
  return code === 'ui_dump_failed' || code === 'ui_dump_read_failed';
}

function settingsScreenSize(deviceId) {
  let output;
  try {
    output = adbExec(deviceId, ['shell', 'wm', 'size'], {
      capture: true,
      encoding: 'utf8',
      maxBuffer: 4096,
      safeCode: 'settings_screen_size_unavailable',
    });
    const matches = [...output.matchAll(/([0-9]{3,5})x([0-9]{3,5})/g)];
    const match = matches.at(-1);
    if (!match) {
      throw safeRunnerError('settings_screen_size_invalid');
    }
    const width = Number(match[1]);
    const height = Number(match[2]);
    if (
      !Number.isSafeInteger(width) ||
      !Number.isSafeInteger(height) ||
      width < 240 ||
      width > 10_000 ||
      height < 240 ||
      height > 10_000
    ) {
      throw safeRunnerError('settings_screen_size_invalid');
    }
    return Object.freeze({ width, height });
  } finally {
    output = undefined;
  }
}

const settingsAcceptanceSupport = createAndroidSettingsAcceptanceSupport({
  adbExec,
  assertBoundedUiXml,
  deviceViewport,
  findUiTarget,
  isTransientUiSnapshotError,
  nodeAttributes,
  safeCodeFor,
  safeRunnerError,
  settingsScreenSize,
  snapshotUi,
  strictSettingsResourceId,
  tapPoint,
  validViewport,
  waitForTarget,
  waitImpl: wait,
});
const {
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
} = settingsAcceptanceSupport;

const authAcceptanceSupport = createAndroidAuthAcceptanceSupport({
  adbExec,
  assertBoundedUiXml,
  deviceViewport,
  findUiTarget,
  inputText,
  isTransientUiSnapshotError,
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
  waitImpl: wait,
});
const {
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
} = authAcceptanceSupport;

async function navigateToDashboard(deviceId) {
  // Launcher restoration can expose the shell one or two frames before the
  // compact navigation semantics tree. Join that bounded UI transition rather
  // than failing from a single early snapshot.
  const dashboardPoint = await waitForTarget(deviceId, 'dashboard', 30_000);
  tapPoint(deviceId, dashboardPoint);
  await waitForTarget(deviceId, 'aiAssistant', 30_000);
}

const aiQuestionAcceptanceSupport = createAndroidAiQuestionAcceptanceSupport({
  adbExec,
  assertBoundedUiXml,
  composerResourceIdentifiers: uiIdentifiers.composer,
  executeLongPress,
  findUiTarget,
  inputText,
  isTransientUiSnapshotError,
  nodeAttributes,
  resourceIdMatches,
  safeRunnerError,
  snapshotUi,
  tapPoint,
  uiNodesWithParents,
  waitForTarget,
  waitImpl: wait,
});
const {
  acceptanceStateFromUiXml,
  askGroqQuestion,
  composerInputStateFromUiXml,
  observeQuestionCompletion,
  openAiAssistant,
  prepareAndSubmitQuestion,
  questionInputMode,
} = aiQuestionAcceptanceSupport;


function createProductionAdapter() {
  return {
    askQuestion: askGroqQuestion,
    buildAndInstall,
    clearLogs: lifecycleClearDeviceLogs,
    clearUiDump: async (deviceId) => removeRemoteUiDump(deviceId),
    createSyntheticUser,
    deleteAppCheckRegistration,
    deleteSyntheticProfile,
    deleteSyntheticUser,
    forceStop,
    getPid: currentPid,
    inspectFeasibility,
    loadCloudCredentials,
    login: loginSyntheticUser,
    logout: bestEffortLogout,
    launchFromLauncher,
    navigateToDashboard,
    normalizeSignedOut: normalizeSignedOutSession,
    openAi: openAiAssistant,
    reachLoginScreen,
    registerAppCheck: registerAcceptanceAppCheck,
    runSettingsLiveTest,
    uninstall: bestEffortUninstall,
    verifyRestoredSettings: verifyRestoredSettingsPage,
    verifyGatewayHealth,
    verifySettings: verifySettingsPage,
    waitForNewPid,
    waitForStopped,
  };
}

module.exports = {
  acceptanceBuildExtraDefines,
  acceptanceStateFromUiXml,
  approvedGatewayHost,
  authSurfaceFromUiXml,
  collectRequiredSettingsRows,
  collectSettingsRowsAcrossRefreshes,
  composerInputStateFromUiXml,
  credentialClearCommands,
  createProductionAdapter,
  createSyntheticProfile,
  deleteSyntheticProfile,
  emailInputCommands,
  fillAndSubmitLogin,
  findAndTapLoginSubmit,
  findUiTarget,
  firestoreProfileUrl,
  loginStateFromUiXml,
  normalizeSignedOutSession,
  observeLoginAuthentication,
  observeQuestionCompletion,
  observeSettingsTestTransition,
  performResourceIdLogout,
  pidFromCommandResult,
  prepareAndSubmitQuestion,
  proveProcessRestart,
  questionInputMode,
  safeRunnerError,
  settingsRequiredResourceIds,
  settingsStateFromUiXml,
  syntheticPassword,
  triggerSettingsLiveTest,
  verifySyntheticCredentials,
};
