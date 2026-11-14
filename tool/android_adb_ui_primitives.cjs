'use strict';

const { execFileSync } = require('node:child_process');

function createAdbExecutor({
  resolveExecutable,
  cwd,
  defaultMaxBuffer,
  errorForCode,
  execFileSyncImpl = execFileSync,
}) {
  return function executeAdb(deviceId, args, options = {}) {
    try {
      return execFileSyncImpl(resolveExecutable(), ['-s', deviceId, ...args], {
        cwd,
        encoding: options.encoding,
        maxBuffer: options.maxBuffer || defaultMaxBuffer,
        timeout: options.timeoutMs || 15_000,
        stdio: options.capture
          ? ['ignore', 'pipe', 'ignore']
          : ['ignore', 'ignore', 'ignore'],
      });
    } catch {
      throw errorForCode(options.safeCode || 'adb_command_failed');
    }
  };
}

function createUiDumpLifecycle({
  executeAdb,
  remoteUiDumpPath,
  maxUiXmlBytes,
  assertBoundedUiXml,
  errorForCode,
}) {
  function removeRemoteUiDump(deviceId) {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        executeAdb(deviceId, ['shell', 'rm', '-f', remoteUiDumpPath], {
          safeCode: 'ui_dump_cleanup_failed',
        });
        executeAdb(deviceId, ['shell', 'test', '!', '-e', remoteUiDumpPath], {
          safeCode: 'ui_dump_cleanup_failed',
        });
        return true;
      } catch {
        // Retry only the injected fixed path and never reflect XML or commands.
      }
    }
    return false;
  }

  function snapshotUi(deviceId) {
    let xml;
    try {
      executeAdb(
        deviceId,
        ['shell', 'uiautomator', 'dump', '--compressed', remoteUiDumpPath],
        { safeCode: 'ui_dump_failed' },
      );
      xml = executeAdb(deviceId, ['exec-out', 'cat', remoteUiDumpPath], {
        capture: true,
        encoding: 'utf8',
        maxBuffer: maxUiXmlBytes,
        safeCode: 'ui_dump_read_failed',
      });
      assertBoundedUiXml(xml);
      return xml;
    } finally {
      if (!removeRemoteUiDump(deviceId)) {
        throw errorForCode('ui_dump_cleanup_failed');
      }
      xml = undefined;
    }
  }

  return Object.freeze({ removeRemoteUiDump, snapshotUi });
}

function tapPoint(executeAdb, deviceId, point) {
  executeAdb(
    deviceId,
    ['shell', 'input', 'tap', String(point.x), String(point.y)],
    { safeCode: 'ui_tap_failed' },
  );
}

function longPressPoint(executeAdb, deviceId, point, durationMs) {
  executeAdb(
    deviceId,
    [
      'shell',
      'input',
      'swipe',
      String(point.x),
      String(point.y),
      String(point.x),
      String(point.y),
      String(durationMs),
    ],
    { safeCode: 'ui_long_press_failed' },
  );
}

module.exports = {
  createAdbExecutor,
  createUiDumpLifecycle,
  longPressPoint,
  tapPoint,
};
