'use strict';

function androidNetworkStateCommands(online) {
  const airplaneVerb = online ? 'disable' : 'enable';
  const networkVerb = online ? 'enable' : 'disable';
  const setting = online ? '0' : '1';
  const broadcastState = online ? 'false' : 'true';
  return [
    ['shell', 'cmd', 'connectivity', 'airplane-mode', airplaneVerb],
    ['shell', 'settings', 'put', 'global', 'airplane_mode_on', setting],
    [
      'shell',
      'am',
      'broadcast',
      '-a',
      'android.intent.action.AIRPLANE_MODE',
      '--ez',
      'state',
      broadcastState,
    ],
    ['shell', 'svc', 'wifi', networkVerb],
    ['shell', 'svc', 'data', networkVerb],
  ];
}

function createAndroidNetworkStateController({
  commandsForState = androidNetworkStateCommands,
  cwd,
  errorForInvalidRequest,
  errorForNotApplied,
  executeFileSync,
  requestIsAllowed,
  resolveAdbExecutable,
  timeoutMs = null,
}) {
  return function applyAndroidNetworkState(deviceId, state, online) {
    if (!requestIsAllowed(deviceId, state, online)) {
      throw errorForInvalidRequest();
    }
    const desired = online ? 'online' : 'offline';
    if (state.current === desired) {
      return true;
    }
    let appliedCommands = 0;
    for (const command of commandsForState(online)) {
      try {
        executeFileSync(
          resolveAdbExecutable(),
          ['-s', deviceId, ...command],
          {
            cwd,
            stdio: 'ignore',
            ...(timeoutMs === null ? {} : { timeout: timeoutMs }),
          },
        );
        appliedCommands += 1;
      } catch {
        // Android releases expose different subsets of these fixed controls.
      }
    }
    if (appliedCommands === 0) {
      throw errorForNotApplied(desired);
    }
    state.current = desired;
    return true;
  };
}

module.exports = {
  androidNetworkStateCommands,
  createAndroidNetworkStateController,
};
