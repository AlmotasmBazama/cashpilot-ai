#!/usr/bin/env node

'use strict';

const { publicApi, runCli } = require(
  './groq_primary_text_evaluation_support.cjs',
);

if (require.main === module) {
  void runCli();
}

module.exports = publicApi;
