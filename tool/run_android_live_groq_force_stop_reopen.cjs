'use strict';

const {
  main,
} = require('./android_live_groq_force_stop_support.cjs');

void main().then(
  (exitCode) => {
    process.exitCode = exitCode;
  },
  () => {
    console.log(
      'ANDROID_GROQ_RESTART_FAILURE stage=runner code=runner_failure',
    );
    process.exitCode = 1;
  },
);
