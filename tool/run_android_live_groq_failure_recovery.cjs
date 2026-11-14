#!/usr/bin/env node

'use strict';

const { runGroqAndroidLiveSuite } = require('./android_live_groq_runner_support.cjs');

void runGroqAndroidLiveSuite({
  suite: 'failure_recovery',
  testFile: 'integration_test/android_live_groq_failure_recovery_test.dart',
  controlsNetwork: true,
});
