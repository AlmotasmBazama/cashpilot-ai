'use strict';

const {
  main,
} = require('./android_plain_flutter_run_acceptance_support.cjs');

void main().then(
  (exitCode) => {
    process.exitCode = exitCode;
  },
  () => {
    console.log(
      'ANDROID_PLAIN_RUN_FAILURE stage=runner code=runner_failure',
    );
    process.exitCode = 1;
  },
);
