'use strict';

const acceptanceBuildExtraDefines = Object.freeze([]);
const approvedGatewayHost =
  'cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app';

function createAndroidDeviceLifecycleSupport({
  adbExec,
  clearDeviceLogs,
  existsSync,
  fetchImplementation,
  groqDartDefines,
  joinPath,
  launcherComponent,
  nowImpl = Date.now,
  packageName,
  repositoryRoot,
  resolveAdbPath,
  safeRunnerError,
  spawnSyncImplementation,
  timeoutSignal,
  waitImpl,
}) {
  const wait = waitImpl;

  function proveProcessRestart({ oldPid, stopped, newPid }) {
    if (
      !stopped ||
      !/^[0-9]+$/.test(oldPid || '') ||
      !/^[0-9]+$/.test(newPid || '') ||
      oldPid === newPid
    ) {
      throw safeRunnerError('process_restart_not_proven');
    }
    return Object.freeze({
      oldProcessStopped: true,
      newProcessStarted: true,
      pidChanged: true,
    });
  }

  function pidFromCommandResult(result) {
    const output =
      typeof result.stdout === 'string' ? result.stdout.trim() : '';
    const errorOutput =
      typeof result.stderr === 'string' ? result.stderr.trim() : '';
    if (
      result.error ||
      (result.status !== 0 &&
        !(result.status === 1 && !output && !errorOutput))
    ) {
      throw safeRunnerError('pid_query_failed');
    }
    if (!output) {
      return null;
    }
    const pid = output.split(/\s+/)[0];
    if (!/^[0-9]+$/.test(pid)) {
      throw safeRunnerError('pid_query_failed');
    }
    return pid;
  }

  function currentPid(deviceId) {
    const result = spawnSyncImplementation(
      resolveAdbPath(),
      ['-s', deviceId, 'shell', 'pidof', packageName],
      {
        cwd: repositoryRoot,
        encoding: 'utf8',
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
        timeout: 5_000,
      },
    );
    return pidFromCommandResult(result);
  }

  function launchFromLauncher(deviceId) {
    adbExec(deviceId, ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP']);
    try {
      adbExec(deviceId, ['shell', 'wm', 'dismiss-keyguard']);
    } catch {
      // Some Android versions do not expose dismiss-keyguard to shell.
    }
    let resolved;
    try {
      resolved = adbExec(
        deviceId,
        [
          'shell',
          'cmd',
          'package',
          'resolve-activity',
          '--brief',
          '-a',
          'android.intent.action.MAIN',
          '-c',
          'android.intent.category.LAUNCHER',
          packageName,
        ],
        {
          capture: true,
          encoding: 'utf8',
          safeCode: 'launcher_resolution_failed',
        },
      );
      const resolvedComponent = resolved
        .trim()
        .split(/\r?\n/)
        .filter(Boolean)
        .at(-1);
      if (resolvedComponent !== launcherComponent) {
        throw safeRunnerError('launcher_component_mismatch');
      }
    } finally {
      resolved = undefined;
    }
    adbExec(
      deviceId,
      [
        'shell',
        'am',
        'start',
        '-W',
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER',
        '-n',
        launcherComponent,
      ],
      {
        safeCode: 'launcher_reopen_failed',
        // `am start -W` waits for the first frame. A fresh App Check process
        // refresh on slower emulators can legitimately exceed the generic
        // 15-second ADB command bound; the subsequent PID proof still fails
        // closed if no new process actually starts.
        timeoutMs: 45_000,
      },
    );
  }

  async function waitForPid(deviceId, predicate, timeoutMs, code) {
    const deadline = nowImpl() + timeoutMs;
    while (nowImpl() <= deadline) {
      const pid = currentPid(deviceId);
      if (predicate(pid)) {
        return pid;
      }
      await wait(200);
    }
    throw safeRunnerError(code);
  }

  async function waitForNewPid(deviceId, oldPid) {
    return waitForPid(
      deviceId,
      (pid) => pid !== null && pid !== oldPid,
      20_000,
      'new_process_not_observed',
    );
  }

  async function waitForStopped(deviceId) {
    await waitForPid(
      deviceId,
      (pid) => pid === null,
      10_000,
      'old_process_still_running',
    );
    return true;
  }

  async function verifyGatewayHealth(gatewayUrl) {
    const response = await fetchImplementation(`${gatewayUrl}/health`, {
      headers: { Accept: 'application/json' },
      signal: timeoutSignal(10_000),
    }).catch(() => {
      throw safeRunnerError('gateway_health_unreachable');
    });
    if (!response.ok) {
      throw safeRunnerError(`gateway_health_http_${response.status}`);
    }
    const body = await response.json().catch(() => null);
    if (
      body?.status !== 'success' ||
      body?.environment !== 'staging' ||
      body?.supportedClientVersion !== '1.0.0' ||
      body?.readiness?.ready !== true
    ) {
      throw safeRunnerError('gateway_health_contract_mismatch');
    }
  }

  function packageIsInstalled(deviceId) {
    let packageList;
    try {
      packageList = adbExec(
        deviceId,
        [
          'shell',
          'pm',
          'list',
          'packages',
          '-u',
          '--user',
          '0',
          packageName,
        ],
        {
          capture: true,
          encoding: 'utf8',
          safeCode: 'package_state_unavailable',
        },
      );
      return packageList
        .split(/\r?\n/)
        .some((line) => line.trim() === `package:${packageName}`);
    } finally {
      packageList = undefined;
    }
  }

  function inspectFeasibility(deviceId) {
    const adbAvailable = existsSync(resolveAdbPath());
    const flutterLookup = spawnSyncImplementation('where.exe', ['flutter.bat'], {
      cwd: repositoryRoot,
      encoding: 'utf8',
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 5_000,
    });
    const flutterAvailable = flutterLookup.status === 0;
    let deviceAvailable = false;
    let packageInstalled = false;
    if (adbAvailable) {
      try {
        const state = adbExec(deviceId, ['get-state'], {
          capture: true,
          encoding: 'utf8',
          safeCode: 'device_state_unavailable',
        });
        deviceAvailable = state.trim() === 'device';
        if (deviceAvailable) {
          packageInstalled = packageIsInstalled(deviceId);
        }
      } catch {
        deviceAvailable = false;
      }
    }
    return Object.freeze({
      adbAvailable,
      flutterAvailable,
      deviceAvailable,
      packageInstalled,
      uiDriverAvailable: adbAvailable && deviceAvailable,
    });
  }

  function buildAndInstall(deviceId, gatewayUrl) {
    const buildArguments = [
      'build',
      'apk',
      '--debug',
      '--no-pub',
      ...groqDartDefines(gatewayUrl, acceptanceBuildExtraDefines),
    ];
    if (
      buildArguments.some(
        (argument) => !/^[A-Za-z0-9_./:=+-]+$/.test(argument),
      )
    ) {
      throw safeRunnerError('flutter_build_argument_invalid');
    }
    // Passing one fully validated command string avoids Node's unsafe
    // shell-with-args path while still allowing Windows to execute flutter.bat.
    const build = spawnSyncImplementation(
      `flutter.bat ${buildArguments.join(' ')}`,
      {
        cwd: repositoryRoot,
        shell: true,
        windowsHide: true,
        stdio: 'ignore',
        timeout: 10 * 60_000,
      },
    );
    if (build.status !== 0) {
      throw safeRunnerError('flutter_build_failed');
    }
    const apkPath = joinPath(
      repositoryRoot,
      'build',
      'app',
      'outputs',
      'flutter-apk',
      'app-debug.apk',
    );
    if (!existsSync(apkPath)) {
      throw safeRunnerError('acceptance_apk_missing');
    }
    adbExec(deviceId, ['install', apkPath], {
      safeCode: 'acceptance_apk_install_failed',
      timeoutMs: 2 * 60_000,
    });
  }

  function bestEffortUninstall(deviceId) {
    try {
      if (!packageIsInstalled(deviceId)) {
        return true;
      }
      adbExec(deviceId, ['uninstall', packageName]);
      return !packageIsInstalled(deviceId);
    } catch {
      return false;
    }
  }

  function forceStop(deviceId) {
    adbExec(deviceId, ['shell', 'am', 'force-stop', packageName], {
      safeCode: 'force_stop_failed',
    });
  }

  return Object.freeze({
    acceptanceBuildExtraDefines,
    approvedGatewayHost,
    bestEffortUninstall,
    buildAndInstall,
    clearDeviceLogs,
    currentPid,
    forceStop,
    inspectFeasibility,
    launchFromLauncher,
    packageIsInstalled,
    pidFromCommandResult,
    proveProcessRestart,
    verifyGatewayHealth,
    waitForNewPid,
    waitForPid,
    waitForStopped,
  });
}

module.exports = { createAndroidDeviceLifecycleSupport };
