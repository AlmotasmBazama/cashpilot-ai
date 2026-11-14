'use strict';

const { execFileSync } = require('node:child_process');
const path = require('node:path');

const {
  approvedGatewayHost,
  createProductionAdapter: createBaseProductionAdapter,
  observeQuestionCompletion,
  proveProcessRestart,
  settingsRequiredResourceIds,
} = require('./android_cashpilot_acceptance_support.cjs');
const { adbPath } = require('./android_live_groq_runner_support.cjs');
const {
  assertBoundedUiXml: assertUiXmlWithinLimit,
  maxUiXmlBytes,
  nodeAttributes,
  pointFromBounds,
  resourceIdMatches,
} = require('./android_uiautomator_xml_primitives.cjs');
const {
  safeCodeFor,
  serializeSafeMarkerFields,
} = require('./android_safe_output_primitives.cjs');
const {
  createAdbExecutor,
  createUiDumpLifecycle,
  longPressPoint: executeLongPress,
  tapPoint: executeTap,
} = require('./android_adb_ui_primitives.cjs');
const {
  createBoundedExternalProcessWaiter,
} = require('./android_external_process_wait_primitives.cjs');
const {
  androidNetworkStateCommands,
  createAndroidNetworkStateController,
} = require('./android_network_control_primitives.cjs');

const repositoryRoot = path.resolve(__dirname, '..');
const dedicatedDeviceId = 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const firebaseProjectId = 'cashpilot-ai-a6b49';
const gatewayServiceName = 'cashpilot-ai-gateway-staging';
const gatewayRoute = '/v1/ai/general-chat';
const generalModelAlias = 'general-primary';
const generalModel = 'openai/gpt-oss-20b';
const defaultRunWaitSeconds = 20 * 60;
const minimumRunWaitSeconds = 30;
const maximumRunWaitSeconds = 60 * 60;
const processPollIntervalMs = 500;
const acceptanceLongPressMs = 800;
const remoteUiDumpPath =
  '/data/local/tmp/cashpilot_appcheck_smalltalk_acceptance.xml';
const smallTalkResourceId = 'cashpilot_acceptance_ai_small_talk';
const retryResourceId = 'cashpilot_acceptance_ai_retry';
const sendResourceId = 'cashpilot_acceptance_ai_send';
const composerResourceId = 'cashpilot_acceptance_ai_composer';
const acceptedUiResourceIds = new Set([
  smallTalkResourceId,
  retryResourceId,
  sendResourceId,
  composerResourceId,
]);
const offlineRemoteQuestion = 'Explain compound interest simply.';

function acceptanceError(code) {
  const error = new Error('The App Check/small-talk acceptance failed safely.');
  error.safeCode = code;
  return error;
}

function emitSafeMarker(log, name, fields) {
  if (typeof log !== 'function' || !/^[A-Z_]+$/.test(name)) {
    throw acceptanceError('unsafe_marker_contract');
  }
  const serialized = serializeSafeMarkerFields(fields, () =>
    acceptanceError('unsafe_marker_value'),
  );
  log(`ANDROID_APPCHECK_SMALLTALK_${name} ${serialized.join(' ')}`.trim());
}

function parseBoundedSeconds(value) {
  if (!/^[0-9]+$/.test(value)) {
    throw acceptanceError('run_wait_invalid');
  }
  const seconds = Number(value);
  if (
    !Number.isSafeInteger(seconds) ||
    seconds < minimumRunWaitSeconds ||
    seconds > maximumRunWaitSeconds
  ) {
    throw acceptanceError('run_wait_invalid');
  }
  return seconds;
}

function parseAcceptanceArguments(args, env = process.env) {
  const parsed = {
    executeLive: false,
    explicitDryRun: false,
    dedicatedDevice: false,
    literalFlutterRunConfirmed: false,
    manualAppCheckRegistrationConfirmed: false,
    syntheticAccountConfirmed: false,
    networkControlConfirmed: false,
    noArtifactMutationConfirmed: false,
    deviceId: env.CASHPILOT_ACCEPTANCE_DEVICE || dedicatedDeviceId,
    runWaitSeconds: defaultRunWaitSeconds,
  };

  for (let index = 0; index < args.length; index += 1) {
    const value = args[index];
    if (value === '--dry-run') {
      parsed.explicitDryRun = true;
      continue;
    }
    if (value === '--execute-live') {
      parsed.executeLive = true;
      continue;
    }
    if (value === '--dedicated-device') {
      parsed.dedicatedDevice = true;
      continue;
    }
    if (value === '--literal-flutter-run-confirmed') {
      parsed.literalFlutterRunConfirmed = true;
      continue;
    }
    if (value === '--manual-app-check-registration-confirmed') {
      parsed.manualAppCheckRegistrationConfirmed = true;
      continue;
    }
    if (value === '--synthetic-account-confirmed') {
      parsed.syntheticAccountConfirmed = true;
      continue;
    }
    if (value === '--network-control-confirmed') {
      parsed.networkControlConfirmed = true;
      continue;
    }
    if (value === '--no-build-install-uninstall-confirmed') {
      parsed.noArtifactMutationConfirmed = true;
      continue;
    }
    if (value === '--device' || value === '--run-wait-seconds') {
      if (index + 1 >= args.length) {
        throw acceptanceError('argument_value_missing');
      }
      const nextValue = args[index + 1];
      if (value === '--device') {
        parsed.deviceId = nextValue;
      } else {
        parsed.runWaitSeconds = parseBoundedSeconds(nextValue);
      }
      index += 1;
      continue;
    }
    if (value.startsWith('--device=')) {
      parsed.deviceId = value.slice('--device='.length);
      continue;
    }
    if (value.startsWith('--run-wait-seconds=')) {
      parsed.runWaitSeconds = parseBoundedSeconds(
        value.slice('--run-wait-seconds='.length),
      );
      continue;
    }
    throw acceptanceError('argument_unsupported');
  }

  if (parsed.executeLive && parsed.explicitDryRun) {
    throw acceptanceError('execution_mode_conflict');
  }
  if (parsed.deviceId !== dedicatedDeviceId) {
    throw acceptanceError('dedicated_emulator_required');
  }
  if (
    parsed.executeLive &&
    (!parsed.dedicatedDevice ||
      !parsed.literalFlutterRunConfirmed ||
      !parsed.manualAppCheckRegistrationConfirmed ||
      !parsed.syntheticAccountConfirmed ||
      !parsed.networkControlConfirmed ||
      !parsed.noArtifactMutationConfirmed)
  ) {
    throw acceptanceError('live_confirmation_incomplete');
  }

  return Object.freeze({
    executeLive: parsed.executeLive,
    deviceId: parsed.deviceId,
    runWaitMs: parsed.runWaitSeconds * 1000,
    dedicatedDevice: parsed.dedicatedDevice,
    literalFlutterRunConfirmed: parsed.literalFlutterRunConfirmed,
    manualAppCheckRegistrationConfirmed:
      parsed.manualAppCheckRegistrationConfirmed,
    syntheticAccountConfirmed: parsed.syntheticAccountConfirmed,
    networkControlConfirmed: parsed.networkControlConfirmed,
    noArtifactMutationConfirmed: parsed.noArtifactMutationConfirmed,
  });
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

const {
  waitForExternalProcessState: waitForExternalAppState,
} = createBoundedExternalProcessWaiter({
  defaultPollIntervalMs: processPollIntervalMs,
  defaultWaitImpl: wait,
  errorForCode: acceptanceError,
});

async function waitForExternalAppStart(options) {
  return waitForExternalAppState({ ...options, state: 'started' });
}

function createProductionCoordinator(adapter) {
  return Object.freeze({
    waitForStarted(deviceId, previousPid, timeoutMs) {
      return waitForExternalAppStart({
        readPid: () => adapter.getPid(deviceId),
        previousPid,
        timeoutMs,
      });
    },
    waitForStopped(deviceId, timeoutMs) {
      return waitForExternalAppState({
        readPid: () => adapter.getPid(deviceId),
        state: 'stopped',
        timeoutMs,
      });
    },
  });
}

function assertBoundedUiXml(xml) {
  assertUiXmlWithinLimit(xml, () => acceptanceError('ui_snapshot_invalid'));
}

function resourcePointFromUiXml(xml, identifier) {
  assertBoundedUiXml(xml);
  if (!acceptedUiResourceIds.has(identifier)) {
    throw acceptanceError('ui_target_unsupported');
  }
  for (const node of xml.matchAll(/<node\s+([^>]+)>?/g)) {
    const attributes = nodeAttributes(node[1]);
    if (
      attributes.enabled === 'false' ||
      !resourceIdMatches(attributes['resource-id'] || '', identifier)
    ) {
      continue;
    }
    const point = pointFromBounds(attributes.bounds);
    if (point !== null) {
      return point;
    }
  }
  return null;
}

function acceptanceUiStateFromXml(xml) {
  assertBoundedUiXml(xml);
  const states = [];
  for (const node of xml.matchAll(/<node\s+([^>]+)>?/g)) {
    const resourceId = nodeAttributes(node[1])['resource-id'] || '';
    const ordinary =
      /(?:^|[:/])cashpilot_ai_acceptance_(idle|sending|answer_complete)_([0-9]+)$/.exec(
        resourceId,
      );
    const failure =
      /(?:^|[:/])cashpilot_ai_acceptance_failure_([a-z][a-z0-9_]*)_([0-9]+)$/.exec(
        resourceId,
      );
    if (ordinary) {
      states.push({
        phase: ordinary[1],
        failureKind: null,
        messageCount: Number(ordinary[2]),
      });
    } else if (failure) {
      states.push({
        phase: 'failure',
        failureKind: failure[1],
        messageCount: Number(failure[2]),
      });
    }
  }
  const distinctStates = new Map(
    states.map((state) => [
      `${state.phase}:${state.failureKind || 'none'}:${state.messageCount}`,
      state,
    ]),
  );
  if (distinctStates.size > 1) {
    throw acceptanceError('acceptance_state_ambiguous');
  }
  const state = distinctStates.size === 1
    ? distinctStates.values().next().value
    : null;
  if (
    state !== null &&
    (!Number.isSafeInteger(state.messageCount) ||
      state.messageCount < 0 ||
      state.messageCount > 1000)
  ) {
    throw acceptanceError('acceptance_state_invalid');
  }
  return Object.freeze({
    state: state === null ? null : Object.freeze(state),
    retryVisible: resourcePointFromUiXml(xml, retryResourceId) !== null,
    offlineReason: state?.failureKind === 'offline',
  });
}

const adbExec = createAdbExecutor({
  resolveExecutable: adbPath,
  cwd: repositoryRoot,
  defaultMaxBuffer: maxUiXmlBytes,
  errorForCode: acceptanceError,
});
const { removeRemoteUiDump, snapshotUi } = createUiDumpLifecycle({
  executeAdb: adbExec,
  remoteUiDumpPath,
  maxUiXmlBytes,
  assertBoundedUiXml,
  errorForCode: acceptanceError,
});

function readAcceptanceUiState(deviceId) {
  let xml;
  try {
    xml = snapshotUi(deviceId);
    return acceptanceUiStateFromXml(xml);
  } finally {
    xml = undefined;
  }
}

async function waitForResourcePoint(
  deviceId,
  identifier,
  timeoutMs = 30_000,
) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      const point = resourcePointFromUiXml(xml, identifier);
      if (point !== null) {
        return point;
      }
    } catch (error) {
      if (!['ui_dump_failed', 'ui_dump_read_failed'].includes(safeCodeFor(error))) {
        throw error;
      }
    } finally {
      xml = undefined;
    }
    await wait(300);
  }
  throw acceptanceError('ui_resource_timed_out');
}

function tapPoint(deviceId, point) {
  executeTap(adbExec, deviceId, point);
}

function longPressPoint(deviceId, point, execImpl = adbExec) {
  if (
    deviceId !== dedicatedDeviceId ||
    !Number.isSafeInteger(point?.x) ||
    !Number.isSafeInteger(point?.y) ||
    point.x < 0 ||
    point.y < 0 ||
    typeof execImpl !== 'function'
  ) {
    throw acceptanceError('ui_long_press_contract_invalid');
  }
  executeLongPress(execImpl, deviceId, point, acceptanceLongPressMs);
}

function requireQuestionBaseline(uiState) {
  const state = uiState?.state;
  if (
    state === null ||
    state === undefined ||
    !['idle', 'answer_complete'].includes(state.phase) ||
    !Number.isSafeInteger(state.messageCount)
  ) {
    throw acceptanceError('question_baseline_invalid');
  }
  return state.messageCount;
}

async function askSmallTalkThroughResourceIds(deviceId) {
  const baselineMessageCount = requireQuestionBaseline(
    readAcceptanceUiState(deviceId),
  );
  const hook = await waitForResourcePoint(deviceId, smallTalkResourceId);
  longPressPoint(deviceId, hook);
  return observeQuestionCompletion({
    baselineMessageCount,
    readState: async () => readAcceptanceUiState(deviceId).state,
    timeoutMs: 30_000,
  });
}

async function askRemoteWhileOffline(deviceId) {
  const baselineMessageCount = requireQuestionBaseline(
    readAcceptanceUiState(deviceId),
  );
  // Use a fixed substantive request that has no supported local/offline
  // answer. The value is never emitted or read back from the UI.
  const composer = await waitForResourcePoint(deviceId, composerResourceId);
  tapPoint(deviceId, composer);
  replaceOfflineQuestion(deviceId);
  const send = await waitForResourcePoint(deviceId, sendResourceId, 10_000);
  tapPoint(deviceId, send);

  const deadline = Date.now() + 45_000;
  let lastFailureKind = 'none';
  while (Date.now() <= deadline) {
    const observed = readAcceptanceUiState(deviceId);
    if (
      observed.state?.phase === 'failure' &&
      typeof observed.state.failureKind === 'string'
    ) {
      lastFailureKind = observed.state.failureKind;
    }
    if (
      observed.state?.phase === 'failure' &&
      observed.state.messageCount === baselineMessageCount + 2 &&
      observed.retryVisible &&
      observed.offlineReason
    ) {
      return Object.freeze({
        baselineMessageCount,
        failedMessageCount: baselineMessageCount + 2,
        failedMessageDelta: 2,
        retryVisible: true,
        failureReason: 'offline',
      });
    }
    await wait(200);
  }
  throw acceptanceError(
    `typed_offline_failure_not_proven_${lastFailureKind}`,
  );
}

function offlineQuestionInputCommands() {
  return Object.freeze([
    Object.freeze([
      'shell',
      'input',
      'keycombination',
      'KEYCODE_CTRL_LEFT',
      'KEYCODE_A',
    ]),
    Object.freeze(['shell', 'input', 'keyevent', 'KEYCODE_DEL']),
    Object.freeze([
      'shell',
      'input',
      'text',
      offlineRemoteQuestion.replaceAll(' ', '%s'),
    ]),
  ]);
}

function replaceOfflineQuestion(deviceId) {
  for (const command of offlineQuestionInputCommands()) {
    adbExec(deviceId, command, {
      safeCode: 'offline_question_input_failed',
      timeoutMs: 30_000,
    });
  }
}

async function retryOfflineThroughResourceId(deviceId, offlineProof) {
  if (
    !Number.isSafeInteger(offlineProof?.baselineMessageCount) ||
    offlineProof.baselineMessageCount < 0 ||
    offlineProof.failedMessageCount !==
      offlineProof.baselineMessageCount + 2 ||
    offlineProof.failureReason !== 'offline' ||
    offlineProof.retryVisible !== true
  ) {
    throw acceptanceError('offline_retry_contract_invalid');
  }
  const retry = await waitForResourcePoint(deviceId, retryResourceId, 10_000);
  tapPoint(deviceId, retry);
  return observeOfflineRetryCompletion({
    failureMessageCount: offlineProof.failedMessageCount,
    readState: async () => readAcceptanceUiState(deviceId).state,
    timeoutMs: 90_000,
  });
}

async function observeOfflineRetryCompletion({
  failureMessageCount,
  readState,
  waitImpl = wait,
  timeoutMs = 90_000,
  settleSnapshotCount = 3,
  settleIntervalMs = 250,
  now = Date.now,
}) {
  if (
    !Number.isSafeInteger(failureMessageCount) ||
    failureMessageCount < 2 ||
    typeof readState !== 'function' ||
    typeof waitImpl !== 'function' ||
    !Number.isSafeInteger(timeoutMs) ||
    timeoutMs < 1 ||
    !Number.isSafeInteger(settleSnapshotCount) ||
    settleSnapshotCount < 2 ||
    settleSnapshotCount > 10 ||
    !Number.isSafeInteger(settleIntervalMs) ||
    settleIntervalMs < 1 ||
    settleIntervalMs > 1_000 ||
    typeof now !== 'function'
  ) {
    throw acceptanceError('offline_retry_observer_contract_invalid');
  }
  const sendingMessageCount = failureMessageCount - 1;
  const completedMessageCount = failureMessageCount;
  const deadline = now() + timeoutMs;
  let sendingObserved = false;
  let settledSnapshots = 0;
  while (now() <= deadline) {
    const state = await readState();
    if (
      Number.isSafeInteger(state?.messageCount) &&
      state.messageCount < sendingMessageCount
    ) {
      throw acceptanceError('offline_retry_message_count_regressed');
    }
    if (state?.messageCount > completedMessageCount) {
      throw acceptanceError('offline_retry_duplicate_response_observed');
    }
    if (
      state?.phase === 'sending' &&
      (state.messageCount === sendingMessageCount ||
        state.messageCount === failureMessageCount)
    ) {
      sendingObserved = true;
    }
    if (
      state?.phase === 'answer_complete' &&
      state.messageCount === completedMessageCount
    ) {
      settledSnapshots += 1;
      if (settledSnapshots >= settleSnapshotCount) {
        return Object.freeze({
          sendingObserved,
          answerCompleted: true,
          reusedUserMessage: true,
          assistantMessageDelta: 1,
          totalMessageDelta: 2,
          duplicateResponse: false,
        });
      }
      await waitImpl(settleIntervalMs);
      continue;
    }
    if (
      state?.phase === 'failure' &&
      state.messageCount === failureMessageCount &&
      !sendingObserved
    ) {
      await waitImpl(100);
      continue;
    }
    if (state?.phase === 'failure') {
      throw acceptanceError('offline_retry_failed');
    }
    settledSnapshots = 0;
    await waitImpl(200);
  }
  throw acceptanceError('offline_retry_answer_timed_out');
}

const applyNetworkState = createAndroidNetworkStateController({
  commandsForState: androidNetworkStateCommands,
  cwd: repositoryRoot,
  errorForInvalidRequest: () =>
    acceptanceError('network_control_contract_invalid'),
  errorForNotApplied: () => acceptanceError('network_state_not_applied'),
  executeFileSync: execFileSync,
  requestIsAllowed: (deviceId, networkState) =>
    deviceId === dedicatedDeviceId &&
    networkState !== null &&
    typeof networkState === 'object',
  resolveAdbExecutable: adbPath,
  timeoutMs: 15_000,
});

function deviceNetworkReachable(deviceId) {
  try {
    execFileSync(
      adbPath(),
      ['-s', deviceId, 'shell', 'ping', '-c', '1', '-W', '1', '8.8.8.8'],
      {
        cwd: repositoryRoot,
        stdio: 'ignore',
        timeout: 5_000,
      },
    );
    return true;
  } catch {
    return false;
  }
}

async function waitForDeviceNetworkState(
  deviceId,
  online,
  {
    probe = () => deviceNetworkReachable(deviceId),
    waitImpl = wait,
    timeoutMs = 15_000,
  } = {},
) {
  const deadline = Date.now() + timeoutMs;
  do {
    if (Boolean(await probe()) === online) return true;
    await waitImpl(400);
  } while (Date.now() <= deadline);
  throw acceptanceError(
    online ? 'network_online_not_proven' : 'network_offline_not_proven',
  );
}

function createGatewayWindow(now = Date.now) {
  const startedAtMs = now();
  if (!Number.isSafeInteger(startedAtMs) || startedAtMs < 1) {
    throw acceptanceError('gateway_window_clock_invalid');
  }
  return Object.freeze({ startedAtMs });
}

function closeGatewayWindow(window, now = Date.now) {
  const endedAtMs = now();
  if (
    !Number.isSafeInteger(window?.startedAtMs) ||
    !Number.isSafeInteger(endedAtMs) ||
    endedAtMs < window.startedAtMs
  ) {
    throw acceptanceError('gateway_window_invalid');
  }
  return Object.freeze({
    startedAt: new Date(window.startedAtMs).toISOString(),
    endedAt: new Date(endedAtMs).toISOString(),
  });
}

function safeLoggingFieldsUrl() {
  // jsonPayload is a protobuf Struct whose dynamic keys cannot be selected by
  // this API's partial-response grammar. Keep the bounded response in memory,
  // project it immediately through parseSafeTraceEntry, and never log or
  // persist the raw entry.
  return 'https://logging.googleapis.com/v2/entries:list';
}

function traceFilter(window) {
  if (
    typeof window?.startedAt !== 'string' ||
    typeof window?.endedAt !== 'string' ||
    Number.isNaN(Date.parse(window.startedAt)) ||
    Number.isNaN(Date.parse(window.endedAt))
  ) {
    throw acceptanceError('gateway_window_invalid');
  }
  return [
    'resource.type="cloud_run_revision"',
    `resource.labels.service_name="${gatewayServiceName}"`,
    'jsonPayload.kind="cashpilot_ai_stream"',
    `jsonPayload.route="${gatewayRoute}"`,
    `timestamp>="${window.startedAt}"`,
    `timestamp<="${window.endedAt}"`,
  ].join(' AND ');
}

function parseSafeTraceEntry(entry) {
  const payload = entry?.jsonPayload;
  const revision = entry?.resource?.labels?.revision_name;
  if (
    typeof entry?.timestamp !== 'string' ||
    typeof revision !== 'string' ||
    !/^cashpilot-ai-gateway-staging-[0-9]{5}-[a-z0-9]+$/.test(revision) ||
    payload?.kind !== 'cashpilot_ai_stream' ||
    payload?.route !== gatewayRoute ||
    typeof payload?.selectedModelAlias !== 'string' ||
    typeof payload?.selectedModel !== 'string' ||
    typeof payload?.upstreamHttpStatusCategory !== 'string' ||
    typeof payload?.finalCode !== 'string' ||
    !Number.isSafeInteger(Number(payload?.statusCode)) ||
    !Number.isSafeInteger(Number(payload?.durationMs)) ||
    !Number.isSafeInteger(Number(payload?.retryCount))
  ) {
    throw acceptanceError('gateway_trace_shape_invalid');
  }
  return Object.freeze({
    revision,
    selectedModelAlias: payload.selectedModelAlias,
    selectedModel: payload.selectedModel,
    upstreamHttpStatusCategory: payload.upstreamHttpStatusCategory,
    finalCode: payload.finalCode,
    statusCode: Number(payload.statusCode),
    durationMs: Number(payload.durationMs),
    retryCount: Number(payload.retryCount),
  });
}

async function listSafeGatewayTraces({
  accessToken,
  window,
  fetchImpl = fetch,
}) {
  if (
    typeof accessToken !== 'string' ||
    accessToken.length < 1 ||
    typeof fetchImpl !== 'function'
  ) {
    throw acceptanceError('gateway_trace_query_contract_invalid');
  }
  const entries = [];
  let pageToken;
  for (let page = 0; page < 3; page += 1) {
    const response = await fetchImpl(safeLoggingFieldsUrl(), {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        resourceNames: [`projects/${firebaseProjectId}`],
        filter: traceFilter(window),
        orderBy: 'timestamp asc',
        pageSize: 20,
        ...(pageToken ? { pageToken } : {}),
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      throw acceptanceError(`gateway_trace_http_${response.status}`);
    }
    const body = await response.json().catch(() => null);
    if (body === null || typeof body !== 'object') {
      throw acceptanceError('gateway_trace_response_invalid');
    }
    for (const entry of body.entries || []) {
      entries.push(parseSafeTraceEntry(entry));
      if (entries.length > 20) {
        throw acceptanceError('gateway_trace_count_unbounded');
      }
    }
    if (typeof body.nextPageToken !== 'string' || body.nextPageToken === '') {
      break;
    }
    pageToken = body.nextPageToken;
  }
  return Object.freeze(entries);
}

function validateTraceExpectation(entries, expectedCount) {
  if (!Array.isArray(entries) || ![0, 1].includes(expectedCount)) {
    throw acceptanceError('gateway_trace_expectation_invalid');
  }
  if (entries.length > expectedCount) {
    throw acceptanceError('gateway_duplicate_request_observed');
  }
  if (entries.length < expectedCount) {
    return null;
  }
  if (expectedCount === 0) {
    return Object.freeze({
      traceCount: 0,
      httpStatus: 'none',
      provider: 'none',
      model: 'none',
    });
  }
  const [trace] = entries;
  if (
    trace.selectedModelAlias !== generalModelAlias ||
    trace.selectedModel !== generalModel ||
    trace.upstreamHttpStatusCategory !== 'success' ||
    trace.finalCode !== 'completed' ||
    trace.statusCode !== 200
  ) {
    throw acceptanceError('gateway_trace_not_successful_groq');
  }
  return Object.freeze({
    traceCount: 1,
    httpStatus: 200,
    provider: 'groq',
    model: 'general20b',
    revision: trace.revision,
  });
}

async function verifyGatewayTraceWindow({
  accessToken,
  window,
  expectedCount,
  queryImpl = listSafeGatewayTraces,
  waitImpl = wait,
  initialDelayMs = 4_000,
  retryDelayMs = 2_000,
  rateLimitDelayMs = 15_000,
  settleDelayMs = 3_000,
  maximumQueries = 16,
}) {
  if (
    ![0, 1].includes(expectedCount) ||
    typeof queryImpl !== 'function' ||
    typeof waitImpl !== 'function' ||
    !Number.isSafeInteger(initialDelayMs) ||
    initialDelayMs < 0 ||
    !Number.isSafeInteger(retryDelayMs) ||
    retryDelayMs < 0 ||
    !Number.isSafeInteger(rateLimitDelayMs) ||
    rateLimitDelayMs < 0 ||
    !Number.isSafeInteger(settleDelayMs) ||
    settleDelayMs < 0 ||
    !Number.isSafeInteger(maximumQueries) ||
    maximumQueries < 2 ||
    maximumQueries > 30
  ) {
    throw acceptanceError('gateway_trace_verifier_contract_invalid');
  }
  await waitImpl(initialDelayMs);
  for (let query = 0; query < maximumQueries; query += 1) {
    let entries;
    try {
      entries = await queryImpl({ accessToken, window });
    } catch (error) {
      if (
        safeCodeFor(error) === 'gateway_trace_http_429' &&
        query + 1 < maximumQueries
      ) {
        await waitImpl(rateLimitDelayMs);
        continue;
      }
      throw error;
    }
    const proof = validateTraceExpectation(entries, expectedCount);
    if (proof !== null) {
      await waitImpl(settleDelayMs);
      let settledEntries;
      try {
        settledEntries = await queryImpl({ accessToken, window });
      } catch (error) {
        if (
          safeCodeFor(error) === 'gateway_trace_http_429' &&
          query + 1 < maximumQueries
        ) {
          await waitImpl(rateLimitDelayMs);
          continue;
        }
        throw error;
      }
      const settled = validateTraceExpectation(settledEntries, expectedCount);
      if (settled !== null) {
        return settled;
      }
    }
    if (query + 1 < maximumQueries) {
      await waitImpl(retryDelayMs);
    }
  }
  throw acceptanceError('gateway_trace_evidence_timed_out');
}

function requireQuestionProof(proof, code) {
  if (
    proof?.answerCompleted !== true ||
    proof?.messageDelta !== 2 ||
    proof?.duplicateResponse !== false
  ) {
    throw acceptanceError(code);
  }
  return proof;
}

function requireRetryProof(proof, code) {
  if (
    proof?.answerCompleted !== true ||
    proof?.reusedUserMessage !== true ||
    proof?.assistantMessageDelta !== 1 ||
    proof?.totalMessageDelta !== 2 ||
    proof?.duplicateResponse !== false
  ) {
    throw acceptanceError(code);
  }
  return proof;
}

function requireTraceProof(proof, expectedCount, code) {
  if (
    proof?.traceCount !== expectedCount ||
    (expectedCount === 1 &&
      (proof.httpStatus !== 200 ||
        proof.provider !== 'groq' ||
        proof.model !== 'general20b'))
  ) {
    throw acceptanceError(code);
  }
  return proof;
}

function createProductionAcceptanceAdapter(
  base = createBaseProductionAdapter(),
) {
  const networkState = { current: 'unknown' };
  return Object.freeze({
    askRemote: (deviceId, index) => base.askQuestion(deviceId, index),
    askSmallTalk: askSmallTalkThroughResourceIds,
    beginGatewayWindow: () => createGatewayWindow(),
    clearLogs: base.clearLogs,
    clearUiDump: async (deviceId) =>
      Boolean(await base.clearUiDump(deviceId)) && removeRemoteUiDump(deviceId),
    closeGatewayWindow: (window) => closeGatewayWindow(window),
    createSyntheticUser: base.createSyntheticUser,
    deleteSyntheticProfile: base.deleteSyntheticProfile,
    deleteSyntheticUser: base.deleteSyntheticUser,
    forceStop: base.forceStop,
    getPid: base.getPid,
    inspectFeasibility: base.inspectFeasibility,
    launchFromLauncher: base.launchFromLauncher,
    loadCloudCredentials: base.loadCloudCredentials,
    login: base.login,
    logout: base.logout,
    navigateToDashboard: base.navigateToDashboard,
    normalizeSignedOut: base.normalizeSignedOut,
    openAi: base.openAi,
    reachLoginScreen: base.reachLoginScreen,
    retryOffline: retryOfflineThroughResourceId,
    runSettingsLiveTest: base.runSettingsLiveTest,
    setNetworkOnline: async (deviceId, online) => {
      applyNetworkState(deviceId, networkState, online);
      await waitForDeviceNetworkState(deviceId, online);
      return true;
    },
    submitOffline: askRemoteWhileOffline,
    verifyGatewayHealth: base.verifyGatewayHealth,
    verifySettings: base.verifySettings,
    verifyGatewayWindow: (cloud, window, expectedCount) =>
      verifyGatewayTraceWindow({
        accessToken: cloud.accessToken,
        window,
        expectedCount,
      }),
    waitForNewPid: base.waitForNewPid,
    waitForStopped: base.waitForStopped,
  });
}

async function runBestEffort(operation) {
  try {
    return Boolean(await operation());
  } catch {
    return false;
  }
}

function initialCleanupState() {
  return {
    networkRestored: true,
    logoutRequired: false,
    logoutAttempted: false,
    logoutRetryAttempted: false,
    signedOut: true,
    profileDeleteAttempted: false,
    profileDeleted: true,
    userDeleteAttempted: false,
    userDeleted: true,
    uiDumpCleared: false,
    logsCleared: false,
    externalStopComplete: true,
    packagePreserved: false,
    complete: false,
  };
}

function createExternalRunState() {
  return {
    started: false,
    active: false,
    stopRequested: false,
    stopWaitAttempted: false,
    stopped: false,
    stopFailureCode: null,
  };
}

async function requestExternalFlutterStop({
  runState,
  coordinator,
  deviceId,
  timeoutMs,
  log,
  reason,
  accountCleanup,
}) {
  if (!runState.started || !runState.active) {
    return !runState.started || runState.stopped;
  }
  if (!runState.stopRequested) {
    emitSafeMarker(log, 'READY_STOP', {
      action: 'sendQToFlutterRun',
      reason,
      accountCleanup,
      packagePreserved: true,
    });
    runState.stopRequested = true;
  }
  if (runState.stopWaitAttempted) {
    return runState.stopped;
  }
  runState.stopWaitAttempted = true;
  try {
    const stopped = await coordinator.waitForStopped(deviceId, timeoutMs);
    if (stopped !== true) {
      throw acceptanceError('external_plain_run_not_stopped');
    }
    runState.active = false;
    runState.stopped = true;
    return true;
  } catch (error) {
    runState.stopFailureCode = safeCodeFor(error);
    emitSafeMarker(log, 'STOP_FAILURE', {
      code: runState.stopFailureCode,
    });
    return false;
  }
}

async function cleanupSyntheticState({
  adapter,
  deviceId,
  cloud,
  synthetic,
  cleanup,
}) {
  cleanup.networkRestored = await runBestEffort(() =>
    adapter.setNetworkOnline(deviceId, true),
  );
  if (cleanup.logoutRequired && !cleanup.logoutAttempted) {
    cleanup.logoutAttempted = true;
    cleanup.signedOut = await runBestEffort(() => adapter.logout(deviceId));
  }
  if (synthetic && cloud && !cleanup.profileDeleteAttempted) {
    cleanup.profileDeleteAttempted = true;
    cleanup.profileDeleted = await runBestEffort(() =>
      adapter.deleteSyntheticProfile(cloud, synthetic),
    );
  }
  if (synthetic && cloud && !cleanup.userDeleteAttempted) {
    cleanup.userDeleteAttempted = true;
    cleanup.userDeleted = await runBestEffort(() =>
      adapter.deleteSyntheticUser(cloud, synthetic),
    );
  }
  if (
    cleanup.logoutRequired &&
    !cleanup.signedOut &&
    cleanup.userDeleted &&
    !cleanup.logoutRetryAttempted
  ) {
    cleanup.logoutRetryAttempted = true;
    cleanup.signedOut = await runBestEffort(async () => {
      const result = await adapter.normalizeSignedOut(deviceId);
      return result?.signedOut === true;
    });
  }
}

function feasibilityReady(feasibility) {
  return (
    feasibility?.adbAvailable === true &&
    feasibility?.deviceAvailable === true &&
    feasibility?.flutterAvailable === true &&
    feasibility?.uiDriverAvailable === true
  );
}

async function executeAcceptance({
  options,
  adapter = createProductionAcceptanceAdapter(),
  coordinator = createProductionCoordinator(adapter),
  log = console.log,
  now = Date.now,
}) {
  let feasibility;
  try {
    feasibility = await adapter.inspectFeasibility(options.deviceId);
  } catch (error) {
    const failureCode = safeCodeFor(error);
    emitSafeMarker(log, 'FAILURE', {
      stage: 'feasibility',
      code: failureCode,
    });
    return Object.freeze({
      exitCode: 1,
      liveExecuted: false,
      failureCode,
    });
  }

  emitSafeMarker(log, 'FEASIBILITY', {
    adb: feasibility?.adbAvailable === true,
    device: feasibility?.deviceAvailable === true,
    flutter: feasibility?.flutterAvailable === true,
    uiDriver: feasibility?.uiDriverAvailable === true ? 'uiautomator' : 'unavailable',
    packageInstalled: feasibility?.packageInstalled === true,
    noBuild: true,
    noInstall: true,
    noUninstall: true,
    noAppCheckMutation: true,
    liveExecuted: options.executeLive,
  });

  if (!options.executeLive) {
    emitSafeMarker(log, 'RESULT', {
      completed: false,
      dryRun: true,
      noBuild: true,
      noInstall: true,
      noUninstall: true,
      noAppCheckMutation: true,
    });
    return Object.freeze({ exitCode: 0, liveExecuted: false });
  }

  let stage = 'preflight';
  let failureCode = null;
  let cloud;
  let synthetic;
  let initialPid = null;
  let runPid = null;
  let reopenedPid = null;
  let smallTalkComplete = false;
  let coldRemoteComplete = false;
  let settingsLiveComplete = false;
  let restartProven = false;
  let reopenedRemoteComplete = false;
  let offlineFailureProven = false;
  let retryComplete = false;
  let networkWasDisabled = false;
  const cleanup = initialCleanupState();
  const externalRun = createExternalRunState();

  try {
    if (!feasibilityReady(feasibility)) {
      throw acceptanceError('plain_preflight_unavailable');
    }

    stage = 'gateway_health';
    await adapter.verifyGatewayHealth(`https://${approvedGatewayHost}`);
    stage = 'cloud_credentials';
    cloud = await adapter.loadCloudCredentials();
    stage = 'synthetic_auth_create';
    synthetic = await adapter.createSyntheticUser(cloud);

    stage = 'cold_start_prepare';
    initialPid = await adapter.getPid(options.deviceId);
    if (initialPid !== null) {
      await adapter.forceStop(options.deviceId);
      await adapter.waitForStopped(options.deviceId);
    }
    emitSafeMarker(log, 'PREP', {
      syntheticCreated: true,
      profileCreated: true,
      appCheckRegistration: 'operator',
      appCheckCreated: false,
      appCheckDeleted: false,
      packagePreserved: true,
    });
    emitSafeMarker(log, 'READY_RUN', {
      action: 'startLiteralFlutterRun',
      device: 'emulator-5554',
      plainCommand: true,
      noDefines: true,
      noWrapper: true,
      noBuildByHarness: true,
      noInstallByHarness: true,
    });

    stage = 'wait_plain_run_start';
    runPid = await coordinator.waitForStarted(
      options.deviceId,
      initialPid,
      options.runWaitMs,
    );
    externalRun.started = true;
    externalRun.active = true;
    const postStartFeasibility = await adapter.inspectFeasibility(
      options.deviceId,
    );
    if (postStartFeasibility?.packageInstalled !== true) {
      throw acceptanceError('plain_run_package_not_observed');
    }

    stage = 'auth_normalize';
    const priorAuth = await adapter.normalizeSignedOut(options.deviceId);
    if (
      priorAuth?.signedOut !== true ||
      typeof priorAuth?.priorSession !== 'boolean'
    ) {
      throw acceptanceError('prior_auth_not_normalized');
    }
    stage = 'ui_login';
    await adapter.reachLoginScreen(options.deviceId);
    cleanup.logoutRequired = true;
    cleanup.signedOut = false;
    await adapter.login(options.deviceId, synthetic);
    await adapter.openAi(options.deviceId);

    stage = 'small_talk';
    const smallTalkGatewayWindow = adapter.beginGatewayWindow();
    const smallTalkStartedAt = now();
    const smallTalk = requireQuestionProof(
      await adapter.askSmallTalk(options.deviceId),
      'small_talk_completion_not_proven',
    );
    const smallTalkWindow = adapter.closeGatewayWindow(
      smallTalkGatewayWindow,
    );
    const smallTalkDurationMs = now() - smallTalkStartedAt;

    stage = 'cold_remote';
    let window = adapter.beginGatewayWindow();
    let startedAt = now();
    const coldRemote = requireQuestionProof(
      await adapter.askRemote(options.deviceId, 0),
      'cold_remote_completion_not_proven',
    );
    const coldRemoteWindow = adapter.closeGatewayWindow(window);
    const coldRemoteDurationMs = now() - startedAt;

    stage = 'initial_trace_proof';
    const smallTalkTrace = requireTraceProof(
      await adapter.verifyGatewayWindow(cloud, smallTalkWindow, 0),
      0,
      'small_talk_cloud_trace_observed',
    );
    const coldTrace = requireTraceProof(
      await adapter.verifyGatewayWindow(cloud, coldRemoteWindow, 1),
      1,
      'cold_remote_trace_not_proven',
    );
    smallTalkComplete = true;
    coldRemoteComplete = true;
    emitSafeMarker(log, 'SMALL_TALK', {
      promptClass: 'englishSmallTalk',
      route: 'directConversation',
      answerCompleted: true,
      messageDelta: smallTalk.messageDelta,
      duplicateResponse: false,
      appCheckPathEntered: false,
      cloudTraceCount: smallTalkTrace.traceCount,
      durationMs: smallTalkDurationMs,
    });
    emitSafeMarker(log, 'COLD_REMOTE', {
      promptClass: 'arabicInflation',
      route: 'generalConversation',
      answerCompleted: true,
      messageDelta: coldRemote.messageDelta,
      duplicateResponse: false,
      gatewayCalls: coldTrace.traceCount,
      provider: coldTrace.provider,
      model: coldTrace.model,
      httpStatus: coldTrace.httpStatus,
      firebaseFallback: false,
      durationMs: coldRemoteDurationMs,
    });

    stage = 'settings_verify';
    const settingsStartedAt = now();
    const settingsBefore = await adapter.verifySettings(options.deviceId);
    if (
      settingsBefore?.rowsVerified !== true ||
      settingsBefore?.rowCount !== settingsRequiredResourceIds.length ||
      settingsBefore?.testStatus !== 'idle'
    ) {
      throw acceptanceError('settings_rows_not_verified');
    }
    window = adapter.beginGatewayWindow();
    const settingsLive = await adapter.runSettingsLiveTest(
      options.deviceId,
      settingsBefore.testStatus,
    );
    const settingsWindow = adapter.closeGatewayWindow(window);
    if (
      settingsLive?.baselineIdle !== true ||
      typeof settingsLive?.testingUiObserved !== 'boolean' ||
      settingsLive?.stateMachineOrdered !== true ||
      settingsLive?.available !== true
    ) {
      throw acceptanceError('settings_live_test_not_verified');
    }
    const settingsTrace = requireTraceProof(
      await adapter.verifyGatewayWindow(cloud, settingsWindow, 1),
      1,
      'settings_live_trace_not_proven',
    );
    settingsLiveComplete = true;
    emitSafeMarker(log, 'SETTINGS', {
      rowsVerified: true,
      rowCount: settingsBefore.rowCount,
      remoteGroq: true,
      general20b: true,
      financial120b: true,
      localParser: true,
      receiptFirebase: true,
      fallbackDisabled: true,
      gatewayAvailable: true,
      authReady: true,
      appCheckVerified: true,
      baselineIdle: true,
      testingUiObserved: settingsLive.testingUiObserved,
      stateMachineOrdered: true,
      available: true,
      gatewayCalls: settingsTrace.traceCount,
      provider: settingsTrace.provider,
      model: settingsTrace.model,
      httpStatus: settingsTrace.httpStatus,
      durationMs: now() - settingsStartedAt,
    });

    stage = 'force_stop';
    startedAt = now();
    await adapter.forceStop(options.deviceId);
    const stopped = await adapter.waitForStopped(options.deviceId);
    stage = 'launcher_reopen';
    await adapter.launchFromLauncher(options.deviceId);
    reopenedPid = await adapter.waitForNewPid(options.deviceId, runPid);
    const restart = proveProcessRestart({
      oldPid: runPid,
      stopped,
      newPid: reopenedPid,
    });
    restartProven = true;
    emitSafeMarker(log, 'PROCESS', {
      oldProcessStopped: restart.oldProcessStopped,
      launcherCategory: true,
      newProcessStarted: restart.newProcessStarted,
      pidChanged: restart.pidChanged,
      durationMs: now() - startedAt,
    });

    stage = 'reopened_remote';
    await adapter.navigateToDashboard(options.deviceId);
    await adapter.openAi(options.deviceId, { requireRestoredSession: true });
    window = adapter.beginGatewayWindow();
    startedAt = now();
    const reopenedRemote = requireQuestionProof(
      await adapter.askRemote(options.deviceId, 1),
      'reopened_remote_completion_not_proven',
    );
    const reopenedRemoteWindow = adapter.closeGatewayWindow(window);
    const reopenedTrace = requireTraceProof(
      await adapter.verifyGatewayWindow(cloud, reopenedRemoteWindow, 1),
      1,
      'reopened_remote_trace_not_proven',
    );
    reopenedRemoteComplete = true;
    emitSafeMarker(log, 'REOPEN_REMOTE', {
      promptClass: 'englishCompoundInterest',
      restoredSession: true,
      answerCompleted: true,
      messageDelta: reopenedRemote.messageDelta,
      duplicateResponse: false,
      gatewayCalls: reopenedTrace.traceCount,
      provider: reopenedTrace.provider,
      model: reopenedTrace.model,
      httpStatus: reopenedTrace.httpStatus,
      durationMs: now() - startedAt,
    });

    stage = 'offline_prepare';
    await adapter.setNetworkOnline(options.deviceId, false);
    networkWasDisabled = true;
    window = adapter.beginGatewayWindow();
    startedAt = now();
    stage = 'offline_request';
    const offline = await adapter.submitOffline(options.deviceId);
    if (
      offline?.failedMessageDelta !== 2 ||
      offline?.failedMessageCount !==
        offline?.baselineMessageCount + 2 ||
      offline?.retryVisible !== true ||
      offline?.failureReason !== 'offline'
    ) {
      throw acceptanceError('typed_offline_failure_not_proven');
    }
    const offlineWindow = adapter.closeGatewayWindow(window);
    const offlineTrace = requireTraceProof(
      await adapter.verifyGatewayWindow(cloud, offlineWindow, 0),
      0,
      'offline_gateway_trace_observed',
    );
    offlineFailureProven = true;
    emitSafeMarker(log, 'OFFLINE', {
      promptClass: 'englishCompoundInterest',
      failureReason: 'offline',
      retryVisible: true,
      messageDelta: offline.failedMessageDelta,
      gatewayCalls: offlineTrace.traceCount,
      durationMs: now() - startedAt,
    });

    stage = 'network_restore';
    await adapter.setNetworkOnline(options.deviceId, true);
    networkWasDisabled = false;
    stage = 'retry';
    window = adapter.beginGatewayWindow();
    startedAt = now();
    const retried = requireRetryProof(
      await adapter.retryOffline(options.deviceId, offline),
      'offline_retry_completion_not_proven',
    );
    const retryWindow = adapter.closeGatewayWindow(window);
    const retryTrace = requireTraceProof(
      await adapter.verifyGatewayWindow(cloud, retryWindow, 1),
      1,
      'offline_retry_trace_not_proven',
    );
    retryComplete = true;
    emitSafeMarker(log, 'RETRY', {
      reusedUserMessage: true,
      answerCompleted: true,
      assistantMessageDelta: retried.assistantMessageDelta,
      totalMessageDelta: retried.totalMessageDelta,
      duplicateResponse: false,
      gatewayCalls: retryTrace.traceCount,
      provider: retryTrace.provider,
      model: retryTrace.model,
      httpStatus: retryTrace.httpStatus,
      durationMs: now() - startedAt,
    });
  } catch (error) {
    failureCode = safeCodeFor(error);
  } finally {
    await cleanupSyntheticState({
      adapter,
      deviceId: options.deviceId,
      cloud,
      synthetic,
      cleanup,
    });
    const accountCleanupComplete =
      cleanup.networkRestored &&
      (!cleanup.logoutRequired || cleanup.signedOut) &&
      cleanup.profileDeleted &&
      cleanup.userDeleted;
    cleanup.externalStopComplete = await requestExternalFlutterStop({
      runState: externalRun,
      coordinator,
      deviceId: options.deviceId,
      timeoutMs: options.runWaitMs,
      log,
      reason:
        failureCode === null &&
        smallTalkComplete &&
        coldRemoteComplete &&
        settingsLiveComplete &&
        restartProven &&
        reopenedRemoteComplete &&
        offlineFailureProven &&
        retryComplete &&
        accountCleanupComplete
          ? 'workflow'
          : 'failure',
      accountCleanup: accountCleanupComplete ? 'complete' : 'incomplete',
    });
    cleanup.uiDumpCleared = await runBestEffort(() =>
      adapter.clearUiDump(options.deviceId),
    );
    cleanup.logsCleared = await runBestEffort(() =>
      adapter.clearLogs(options.deviceId),
    );
    cleanup.packagePreserved = await runBestEffort(async () => {
      const finalState = await adapter.inspectFeasibility(options.deviceId);
      return finalState?.packageInstalled === true;
    });
    cleanup.complete =
      cleanup.networkRestored &&
      (!cleanup.logoutRequired || cleanup.signedOut) &&
      cleanup.profileDeleted &&
      cleanup.userDeleted &&
      cleanup.externalStopComplete &&
      cleanup.uiDumpCleared &&
      cleanup.logsCleared &&
      cleanup.packagePreserved;
    emitSafeMarker(log, 'CLEANUP', {
      networkRestored: cleanup.networkRestored,
      logoutAttempted: cleanup.logoutAttempted,
      logoutRetryAttempted: cleanup.logoutRetryAttempted,
      signedOut: cleanup.signedOut,
      profileDeleteAttempted: cleanup.profileDeleteAttempted,
      profileDeleted: cleanup.profileDeleted,
      userDeleteAttempted: cleanup.userDeleteAttempted,
      userDeleted: cleanup.userDeleted,
      appCheckCreated: false,
      appCheckDeleted: false,
      uiDumpCleared: cleanup.uiDumpCleared,
      logsCleared: cleanup.logsCleared,
      externalStopComplete: cleanup.externalStopComplete,
      packagePreserved: cleanup.packagePreserved,
      noBuild: true,
      noInstall: true,
      noUninstall: true,
      complete: cleanup.complete,
    });
    cloud = undefined;
    synthetic = undefined;
    initialPid = null;
    runPid = null;
    reopenedPid = null;
  }

  if (networkWasDisabled && !cleanup.networkRestored && failureCode === null) {
    stage = 'network_restore';
    failureCode = 'network_restore_failed';
  }
  if (!cleanup.externalStopComplete && failureCode === null) {
    stage = 'external_flutter_stop';
    failureCode =
      externalRun.stopFailureCode || 'external_plain_run_not_stopped';
  }
  if (!cleanup.complete && failureCode === null) {
    stage = 'cleanup';
    failureCode = 'cleanup_incomplete';
  }
  if (failureCode !== null) {
    emitSafeMarker(log, 'FAILURE', { stage, code: failureCode });
  }
  const completed =
    failureCode === null &&
    smallTalkComplete &&
    coldRemoteComplete &&
    settingsLiveComplete &&
    restartProven &&
    reopenedRemoteComplete &&
    offlineFailureProven &&
    retryComplete &&
    cleanup.complete;
  emitSafeMarker(log, 'RESULT', {
    completed,
    smallTalk: smallTalkComplete,
    coldRemote: coldRemoteComplete,
    settingsLive: settingsLiveComplete,
    forceStopReopen: restartProven,
    reopenedRemote: reopenedRemoteComplete,
    offlineTyped: offlineFailureProven,
    retry: retryComplete,
    externalStop: cleanup.externalStopComplete,
    cleanup: cleanup.complete,
    noBuild: true,
    noInstall: true,
    noUninstall: true,
    noAppCheckMutation: true,
  });
  return Object.freeze({
    exitCode: completed ? 0 : 1,
    liveExecuted: true,
    ...(failureCode === null ? {} : { failureCode }),
  });
}

async function main(args = process.argv.slice(2)) {
  let options;
  try {
    options = parseAcceptanceArguments(args);
  } catch (error) {
    emitSafeMarker(console.log, 'FAILURE', {
      stage: 'arguments',
      code: safeCodeFor(error),
    });
    return 1;
  }
  const result = await executeAcceptance({ options });
  return result.exitCode;
}

module.exports = {
  acceptanceUiStateFromXml,
  closeGatewayWindow,
  createGatewayWindow,
  createProductionAcceptanceAdapter,
  createProductionCoordinator,
  emitSafeMarker,
  executeAcceptance,
  listSafeGatewayTraces,
  longPressPoint,
  main,
  observeOfflineRetryCompletion,
  offlineQuestionInputCommands,
  parseAcceptanceArguments,
  parseSafeTraceEntry,
  resourcePointFromUiXml,
  validateTraceExpectation,
  verifyGatewayTraceWindow,
  waitForDeviceNetworkState,
  waitForExternalAppStart,
  waitForExternalAppState,
};
