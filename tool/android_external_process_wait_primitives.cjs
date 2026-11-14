'use strict';

function createBoundedExternalProcessWaiter({
  defaultPollIntervalMs,
  defaultWaitImpl,
  errorForCode,
}) {
  function validPid(pid) {
    return typeof pid === 'string' && /^[0-9]+$/.test(pid);
  }

  async function waitForExternalProcessState({
    readPid,
    state,
    previousPid = null,
    timeoutMs,
    pollIntervalMs = defaultPollIntervalMs,
    waitImpl = defaultWaitImpl,
  }) {
    if (
      typeof readPid !== 'function' ||
      typeof waitImpl !== 'function' ||
      !['started', 'stopped'].includes(state) ||
      !Number.isSafeInteger(timeoutMs) ||
      timeoutMs < 1 ||
      !Number.isSafeInteger(pollIntervalMs) ||
      pollIntervalMs < 1 ||
      pollIntervalMs > timeoutMs ||
      (previousPid !== null && !validPid(previousPid))
    ) {
      throw errorForCode('process_wait_contract_invalid');
    }
    const attempts = Math.ceil(timeoutMs / pollIntervalMs) + 1;
    for (let attempt = 0; attempt < attempts; attempt += 1) {
      const pid = await readPid();
      if (pid !== null && !validPid(pid)) {
        throw errorForCode('process_state_invalid');
      }
      if (state === 'stopped' && pid === null) {
        return true;
      }
      if (state === 'started' && validPid(pid) && pid !== previousPid) {
        return pid;
      }
      if (attempt + 1 < attempts) {
        await waitImpl(pollIntervalMs);
      }
    }
    throw errorForCode(
      state === 'started'
        ? 'external_plain_run_not_observed'
        : 'external_plain_run_not_stopped',
    );
  }

  return Object.freeze({ validPid, waitForExternalProcessState });
}

module.exports = { createBoundedExternalProcessWaiter };
