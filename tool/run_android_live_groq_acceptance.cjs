#!/usr/bin/env node

'use strict';

const { runGroqAndroidLiveSuite } = require('./android_live_groq_runner_support.cjs');

void runGroqAndroidLiveSuite({
  suite: 'acceptance',
  testFile: 'integration_test/android_live_groq_acceptance_test.dart',
});
