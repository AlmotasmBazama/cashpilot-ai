'use strict';

function createAndroidAiQuestionAcceptanceSupport({
  adbExec,
  assertBoundedUiXml,
  composerResourceIdentifiers,
  executeLongPress,
  findUiTarget,
  inputText,
  isTransientUiSnapshotError,
  nodeAttributes,
  nowImpl = Date.now,
  resourceIdMatches,
  safeRunnerError,
  snapshotUi,
  tapPoint,
  uiNodesWithParents,
  waitForTarget,
  waitImpl,
}) {
  const wait = waitImpl;
  const firstQuestion = 'اشرح لي مفهوم التضخم بطريقة بسيطة';
  const secondQuestion = 'Explain compound interest simply.';
  const acceptancePromptLongPressMs = 800;
  const acceptancePromptProofTimeoutMs = 10_000;
  const questionCompletionSettleSnapshots = 4;
  const questionCompletionSettleIntervalMs = 200;

  function composerInputStateFromUiXml(xml) {
    assertBoundedUiXml(xml);
    const states = new Set();
    for (const node of uiNodesWithParents(xml)) {
      const resourceId = node.attributes['resource-id'] || '';
      if (
        !composerResourceIdentifiers.some((identifier) =>
          resourceIdMatches(resourceId, identifier),
        )
      ) {
        continue;
      }
      const text = node.attributes.text || '';
      states.add(
        text === ''
          ? 'empty'
          : text === firstQuestion
            ? 'fixedPrompt'
            : 'other',
      );
    }
    if (states.size > 1) {
      throw safeRunnerError('composer_state_ambiguous');
    }
    return states.size === 1 ? [...states][0] : 'missing';
  }

  function acceptanceStateFromUiXml(xml) {
    assertBoundedUiXml(xml);
    const states = [];
    for (const node of xml.matchAll(/<node\s+([^>]+)>?/g)) {
      const resourceId = nodeAttributes(node[1])['resource-id'] || '';
      const match =
        /(?:^|[:/])cashpilot_ai_acceptance_(idle|sending|answer_complete|failure)_([0-9]+)$/.exec(
          resourceId,
        );
      if (match) {
        states.push(match);
      }
    }
    if (states.length === 0) {
      return null;
    }
    if (states.length !== 1) {
      throw safeRunnerError('acceptance_state_ambiguous');
    }
    const [match] = states;
    const count = Number(match[2]);
    if (!Number.isSafeInteger(count) || count < 0 || count > 1000) {
      throw safeRunnerError('acceptance_state_invalid');
    }
    return Object.freeze({ phase: match[1], messageCount: count });
  }

  async function waitForComposerInputState(
    deviceId,
    expectedState,
    timeoutMs = acceptancePromptProofTimeoutMs,
  ) {
    if (!['empty', 'fixedPrompt'].includes(expectedState)) {
      throw safeRunnerError('composer_expected_state_invalid');
    }
    const deadline = nowImpl() + timeoutMs;
    while (nowImpl() <= deadline) {
      let xml;
      try {
        xml = snapshotUi(deviceId);
        const state = composerInputStateFromUiXml(xml);
        if (state === expectedState) {
          return true;
        }
        if (
          state === 'other' ||
          (expectedState === 'empty' && state !== 'missing')
        ) {
          throw safeRunnerError(
            expectedState === 'empty'
              ? 'composer_not_empty'
              : 'composer_prompt_mismatch',
          );
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
    throw safeRunnerError(
      expectedState === 'empty'
        ? 'composer_empty_state_timed_out'
        : 'composer_prompt_not_observed',
    );
  }

  async function openAiAssistant(
    deviceId,
    { requireRestoredSession = false } = {},
  ) {
    const deadline = nowImpl() + 60_000;
    while (nowImpl() <= deadline) {
      let xml;
      try {
        xml = snapshotUi(deviceId);
        if (requireRestoredSession && findUiTarget(xml, 'email')) {
          throw safeRunnerError('auth_session_not_restored');
        }
        if (findUiTarget(xml, 'composer')) {
          return;
        }
        const point = findUiTarget(xml, 'aiAssistant');
        if (point) {
          tapPoint(deviceId, point);
          await waitForTarget(deviceId, 'composer', 30_000);
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
      requireRestoredSession
        ? 'post_restart_dashboard_timed_out'
        : 'dashboard_timed_out',
    );
  }

  async function readAcceptanceState(deviceId) {
    let xml;
    try {
      xml = snapshotUi(deviceId);
      return acceptanceStateFromUiXml(xml);
    } finally {
      xml = undefined;
    }
  }

  function questionInputMode(index) {
    if (index === 0) {
      return 'fixedPromptHook';
    }
    if (index === 1) {
      return 'replace';
    }
    throw safeRunnerError('question_index_invalid');
  }

  function selectAllQuestionComposer(deviceId) {
    adbExec(
      deviceId,
      [
        'shell',
        'input',
        'keycombination',
        'KEYCODE_CTRL_LEFT',
        'KEYCODE_A',
      ],
      { safeCode: 'composer_select_all_failed' },
    );
  }

  function deleteSelectedQuestionComposer(deviceId) {
    adbExec(deviceId, ['shell', 'input', 'keyevent', 'KEYCODE_DEL'], {
      safeCode: 'composer_clear_failed',
    });
  }

  function longPressPrompt(deviceId, point) {
    executeLongPress(
      adbExec,
      deviceId,
      point,
      acceptancePromptLongPressMs,
    );
  }

  async function prepareAndSubmitQuestion(
    index,
    {
      waitForComposer,
      tapComposer,
      proveComposerEmpty,
      waitForPromptHook,
      longPressPrompt,
      proveFixedPrompt,
      selectAll,
      deleteSelection,
      inputReplacement,
      waitForSend,
      tapSend,
      waitImpl = wait,
    },
  ) {
    const inputMode = questionInputMode(index);
    const operations = [
      waitForComposer,
      tapComposer,
      waitForSend,
      tapSend,
      waitImpl,
    ];
    if (
      inputMode === 'fixedPromptHook' &&
      [
        proveComposerEmpty,
        waitForPromptHook,
        longPressPrompt,
        proveFixedPrompt,
      ].some((operation) => typeof operation !== 'function')
    ) {
      throw safeRunnerError('question_input_contract_invalid');
    }
    if (
      inputMode === 'replace' &&
      [selectAll, deleteSelection, inputReplacement].some(
        (operation) => typeof operation !== 'function',
      )
    ) {
      throw safeRunnerError('question_input_contract_invalid');
    }
    if (operations.some((operation) => typeof operation !== 'function')) {
      throw safeRunnerError('question_input_contract_invalid');
    }
    const composer = await waitForComposer();
    await tapComposer(composer);
    if (inputMode === 'fixedPromptHook') {
      await proveComposerEmpty();
      const promptHook = await waitForPromptHook();
      await longPressPrompt(promptHook);
      await proveFixedPrompt();
    } else {
      await selectAll();
      await deleteSelection();
      await waitImpl(120);
      await inputReplacement();
    }
    const send = await waitForSend();
    await tapSend(send);
    return Object.freeze({ inputMode });
  }

  async function observeQuestionCompletion({
    baselineMessageCount,
    readState,
    waitImpl = wait,
    timeoutMs = 90_000,
    settleSnapshotCount = questionCompletionSettleSnapshots,
    settleIntervalMs = questionCompletionSettleIntervalMs,
    now = nowImpl,
  }) {
    if (
      !Number.isSafeInteger(baselineMessageCount) ||
      baselineMessageCount < 0 ||
      typeof readState !== 'function' ||
      typeof waitImpl !== 'function' ||
      !Number.isSafeInteger(timeoutMs) ||
      timeoutMs < 1 ||
      !Number.isSafeInteger(settleSnapshotCount) ||
      settleSnapshotCount < 2 ||
      settleSnapshotCount > 10 ||
      !Number.isSafeInteger(settleIntervalMs) ||
      settleIntervalMs < 1 ||
      settleIntervalMs > 1_000
    ) {
      throw safeRunnerError('question_completion_contract_invalid');
    }
    const expectedCompletedCount = baselineMessageCount + 2;
    const deadline = now() + timeoutMs;
    let sendingObserved = false;
    let settledSnapshots = 0;
    while (now() <= deadline) {
      const state = await readState();
      if (state?.phase === 'failure') {
        throw safeRunnerError('groq_ui_failure');
      }
      if (
        Number.isSafeInteger(state?.messageCount) &&
        state.messageCount < baselineMessageCount
      ) {
        throw safeRunnerError('groq_message_count_regressed');
      }
      if (state?.messageCount > expectedCompletedCount) {
        throw safeRunnerError('groq_duplicate_response_observed');
      }
      if (
        state?.phase === 'sending' &&
        state.messageCount > baselineMessageCount
      ) {
        sendingObserved = true;
      }
      if (
        state?.phase === 'answer_complete' &&
        state.messageCount === expectedCompletedCount
      ) {
        settledSnapshots += 1;
        if (settledSnapshots > settleSnapshotCount) {
          return Object.freeze({
            sendingObserved,
            answerCompleted: true,
            messageDelta: 2,
            duplicateResponse: false,
          });
        }
        await waitImpl(settleIntervalMs);
        continue;
      }
      settledSnapshots = 0;
      await waitImpl(200);
    }
    throw safeRunnerError('groq_answer_timed_out');
  }

  async function askGroqQuestion(deviceId, index) {
    const baseline = await readAcceptanceState(deviceId);
    if (baseline?.phase === 'failure') {
      throw safeRunnerError('groq_ui_failure');
    }
    if (
      baseline === null ||
      !['idle', 'answer_complete'].includes(baseline.phase)
    ) {
      throw safeRunnerError('groq_question_baseline_invalid');
    }
    const baselineMessageCount = baseline.messageCount;
    await prepareAndSubmitQuestion(index, {
      waitForComposer: () => waitForTarget(deviceId, 'composer'),
      tapComposer: (point) => tapPoint(deviceId, point),
      proveComposerEmpty: () =>
        waitForComposerInputState(deviceId, 'empty'),
      waitForPromptHook: () => waitForTarget(deviceId, 'send'),
      longPressPrompt: (point) => longPressPrompt(deviceId, point),
      proveFixedPrompt: () =>
        waitForComposerInputState(deviceId, 'fixedPrompt'),
      selectAll: () => selectAllQuestionComposer(deviceId),
      deleteSelection: () => deleteSelectedQuestionComposer(deviceId),
      inputReplacement: () => inputText(deviceId, secondQuestion, 'question'),
      waitForSend: () => waitForTarget(deviceId, 'send'),
      tapSend: (point) => tapPoint(deviceId, point),
    });

    return observeQuestionCompletion({
      baselineMessageCount,
      readState: () => readAcceptanceState(deviceId),
    });
  }

  return Object.freeze({
    acceptanceStateFromUiXml,
    askGroqQuestion,
    composerInputStateFromUiXml,
    deleteSelectedQuestionComposer,
    observeQuestionCompletion,
    openAiAssistant,
    prepareAndSubmitQuestion,
    questionInputMode,
    readAcceptanceState,
    selectAllQuestionComposer,
    waitForComposerInputState,
  });
}

module.exports = { createAndroidAiQuestionAcceptanceSupport };
