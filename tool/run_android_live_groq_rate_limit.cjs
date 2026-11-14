#!/usr/bin/env node

'use strict';

const { runGroqAndroidLiveSuite } = require('./android_live_groq_runner_support.cjs');

void runGroqAndroidLiveSuite({
  suite: 'rate_limit',
  testFile: 'integration_test/android_live_groq_rate_limit_test.dart',
  extraDefines: ['CASH_PILOT_AI_RATE_LIMIT_PER_MINUTE=20'],
});
