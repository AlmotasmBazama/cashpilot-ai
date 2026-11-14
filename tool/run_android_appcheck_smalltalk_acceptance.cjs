'use strict';

const {
  main,
} = require('./android_appcheck_smalltalk_acceptance_support.cjs');

main()
  .then((exitCode) => {
    process.exitCode = exitCode;
  })
  .catch(() => {
    console.log(
      'ANDROID_APPCHECK_SMALLTALK_FAILURE stage=runner code=runner_failure',
    );
    process.exitCode = 1;
  });
