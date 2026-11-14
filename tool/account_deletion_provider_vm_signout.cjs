#!/usr/bin/env node

'use strict';

const path = require('node:path');
const { execFileSync } = require('node:child_process');

const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const adbExecutable = path.join(
  process.env.LOCALAPPDATA,
  'Android',
  'Sdk',
  'platform-tools',
  'adb.exe',
);

function adb(args, capture = false) {
  return execFileSync(adbExecutable, ['-s', deviceId, ...args], {
    encoding: capture ? 'utf8' : undefined,
    stdio: capture ? ['ignore', 'pipe', 'ignore'] : 'ignore',
  });
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function main() {
  let rawLogs;
  let vmPath;
  let socket;
  let hostPort;
  let ownsForward = false;
  try {
    rawLogs = adb(['logcat', '-d', '-v', 'brief', '-s', 'flutter'], true);
    const matches = [
      ...rawLogs.matchAll(
        /Dart VM service is listening on http:\/\/127\.0\.0\.1:(\d+)\/([^\s]+)/g,
      ),
    ];
    const match = matches.at(-1);
    if (!match) throw new Error('vm_service_unavailable');
    const devicePort = match[1];
    vmPath = match[2];
    const forwards = adb(['forward', '--list'], true);
    const existingForward = forwards.match(
      new RegExp(`^${deviceId} tcp:(\\d+) tcp:${devicePort}$`, 'm'),
    );
    const attachedHostPort = process.env.CASHPILOT_VM_HOST_PORT;
    if (/^\d{4,5}$/.test(attachedHostPort || '')) {
      hostPort = attachedHostPort;
    } else if (existingForward) {
      hostPort = existingForward[1];
    } else {
      hostPort = adb(
        ['forward', 'tcp:0', `tcp:${devicePort}`],
        true,
      ).trim();
      ownsForward = true;
    }
    if (!/^\d{4,5}$/.test(hostPort)) throw new Error('vm_forward_failed');
    const baseUrl = `http://127.0.0.1:${hostPort}/${vmPath}`;
    const rpc = async (method, params = {}) => {
      const query = new URLSearchParams(params);
      const response = await fetch(`${baseUrl}${method}?${query}`, {
        signal: AbortSignal.timeout(10_000),
      });
      const message = await response.json().catch(() => null);
      if (!response.ok || !message || message.error) {
        const safeMessage = String(message?.error?.message || 'unknown')
          .replace(/[^A-Za-z0-9 _-]/g, '')
          .slice(0, 80);
        process.stdout.write(
          `VM_RPC_ERROR method=${method} code=${Number(message?.error?.code) || 0} message=${safeMessage}\n`,
        );
        if (method === 'evaluate') {
          const safeDetails = String(message?.error?.data?.details || '')
            .replace(/[^A-Za-z0-9 _.:()'\/-]/g, ' ')
            .replace(/\s+/g, ' ')
            .slice(0, 400);
          process.stdout.write(`VM_EVALUATE_DETAILS ${safeDetails}\n`);
        }
        throw new Error(`vm_rpc_failed_${method}`);
      }
      return message.result;
    };
    const vm = await rpc('getVM');
    const isolateId = vm?.isolates?.[0]?.id;
    if (typeof isolateId !== 'string') throw new Error('vm_isolate_unavailable');
    const isolate = await rpc('getIsolate', { isolateId });
    const firebaseLibrary = isolate?.libraries?.find(
      (library) =>
        library.uri ===
        'package:cashpilot_ai/features/auth/data/datasources/firebase_auth_data_source.dart',
    );
    if (typeof firebaseLibrary?.id !== 'string') {
      throw new Error('firebase_auth_library_unavailable');
    }
    await rpc('evaluate', {
      isolateId,
      targetId: firebaseLibrary.id,
      expression: 'firebase_auth.FirebaseAuth.instance.signOut()',
    });
    await wait(4_000);
    adb(['shell', 'am', 'force-stop', packageName]);
    adb([
      'shell',
      'monkey',
      '-p',
      packageName,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);
    await wait(5_000);
    process.stdout.write('VM_SIGNOUT complete=true dataCleared=false\n');
  } finally {
    rawLogs = undefined;
    vmPath = undefined;
    if (socket) socket.close();
    if (ownsForward && hostPort && /^\d{4,5}$/.test(hostPort)) {
      adb(['forward', '--remove', `tcp:${hostPort}`]);
    }
    hostPort = undefined;
  }
}

main().catch((error) => {
  const allowed = new Set([
    'vm_service_unavailable',
    'vm_forward_failed',
    'vm_connect_failed',
    'vm_rpc_timeout',
    'vm_rpc_failed_getVM',
    'vm_rpc_failed_getIsolate',
    'vm_rpc_failed_evaluate',
    'vm_isolate_unavailable',
    'firebase_auth_library_unavailable',
  ]);
  const safeDebug = String(error?.message || '')
    .replace(/[^A-Za-z0-9 _-]/g, '')
    .slice(0, 100);
  process.stdout.write(
    `VM_SIGNOUT complete=false code=${
      allowed.has(error?.message) ? error.message : 'vm_signout_failed'
    } debug=${safeDebug}\n`,
  );
  process.exitCode = 1;
});
