'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const harnessPath = path.join(
  __dirname,
  'run_groq_primary_text_evaluation.cjs',
);
const harness = require(harnessPath);

test('the sprint matrix is exactly 15 Arabic and 10 English cases', () => {
  assert.deepEqual(Object.keys(harness), [
    'ALLOWED_MODEL_IDS',
    'CASES',
    'CSV_HEADER',
    'DEFAULT_BETWEEN_CASE_DELAY_MS',
    'MODEL_ID',
    'evaluationRequestBody',
    'evaluateRubrics',
    'parseArguments',
    'resultToCsv',
    'runCase',
    'validateCases',
  ]);
  assert.equal(Object.isFrozen(harness), true);
  assert.equal(harness.validateCases(), true);
  assert.equal(harness.MODEL_ID, 'openai/gpt-oss-20b');
  assert.deepEqual(harness.ALLOWED_MODEL_IDS, [
    'openai/gpt-oss-20b',
    'openai/gpt-oss-120b',
  ]);
  assert.equal(harness.CASES.length, 25);
  assert.equal(
    harness.CASES.filter((item) => item.language === 'ar').length,
    15,
  );
  assert.equal(
    harness.CASES.filter((item) => item.language === 'en').length,
    10,
  );
});

test('dry-run uses no API key and emits only safe case inventory fields', () => {
  const environment = { ...process.env };
  delete environment.GROQ_API_KEY;

  const result = spawnSync(process.execPath, [harnessPath, '--dry-run'], {
    cwd: __dirname,
    encoding: 'utf8',
    env: environment,
    timeout: 10_000,
  });

  assert.equal(result.status, 0);
  assert.equal(result.stderr, '');
  const lines = result.stdout.trimEnd().split(/\r?\n/u);
  assert.equal(lines.length, 26);
  assert.equal(lines[0], harness.CSV_HEADER.join(','));

  const rows = lines.slice(1).map((line) => line.split(','));
  assert.equal(rows.filter((row) => row[2] === 'ar').length, 15);
  assert.equal(rows.filter((row) => row[2] === 'en').length, 10);
  assert.ok(rows.every((row) => row.length === harness.CSV_HEADER.length));
  assert.ok(rows.every((row) => row[3] === 'openai/gpt-oss-20b'));
  assert.ok(rows.every((row) => row[4] === 'dry_run'));
  assert.ok(rows.every((row) => /^(?:AR|EN)\d{2}$/u.test(row[0])));
  assert.ok(!/[\u0600-\u06ff]/u.test(result.stdout));
  assert.ok(!/Bearer|GROQ_API_KEY|https?:\/\//u.test(result.stdout));
});

test('model selection is allowlisted and defaults to 20b', () => {
  assert.equal(
    harness.parseArguments([]).modelId,
    'openai/gpt-oss-20b',
  );
  assert.equal(
    harness.parseArguments(['--model', 'openai/gpt-oss-120b']).modelId,
    'openai/gpt-oss-120b',
  );
  assert.equal(
    harness.parseArguments(['--model=openai/gpt-oss-20b']).modelId,
    'openai/gpt-oss-20b',
  );
  assert.throws(
    () => harness.parseArguments(['--model', 'arbitrary/model']),
    /invalid_model/u,
  );
  assert.throws(
    () => harness.parseArguments(['--model=openai/gpt-oss-20b\nunsafe']),
    /invalid_model/u,
  );
  assert.throws(
    () => harness.parseArguments(['--model']),
    /invalid_model/u,
  );
});

test('paced evaluation delay is bounded and defaults safely', () => {
  assert.equal(
    harness.parseArguments([]).betweenCaseDelayMs,
    harness.DEFAULT_BETWEEN_CASE_DELAY_MS,
  );
  assert.equal(
    harness.parseArguments(['--between-case-delay-ms', '6000'])
      .betweenCaseDelayMs,
    6000,
  );
  assert.equal(
    harness.parseArguments(['--between-case-delay-ms=10000'])
      .betweenCaseDelayMs,
    10000,
  );
  for (const value of ['249', '10001', '-1', '2.5', 'slow', '']) {
    assert.throws(
      () => harness.parseArguments([`--between-case-delay-ms=${value}`]),
      /invalid_between_case_delay/u,
    );
  }
  assert.throws(
    () => harness.parseArguments(['--between-case-delay-ms']),
    /invalid_between_case_delay/u,
  );
});

test('evaluation request matches the fixed low-reasoning gateway profile', () => {
  const item = harness.CASES.find((candidate) => candidate.id === 'EN06');
  const body = harness.evaluationRequestBody(item, harness.MODEL_ID);

  assert.deepEqual(
    {
      model: body.model,
      stream: body.stream,
      temperature: body.temperature,
      maxCompletionTokens: body.max_completion_tokens,
      reasoningEffort: body.reasoning_effort,
      reasoningFormat: body.reasoning_format,
      messageCount: body.messages.length,
    },
    {
      model: 'openai/gpt-oss-20b',
      stream: true,
      temperature: 0.1,
      maxCompletionTokens: 512,
      reasoningEffort: 'low',
      reasoningFormat: 'hidden',
      messageCount: 1,
    },
  );
});

test('120b dry-run emits only the allowlisted safe model ID', () => {
  const environment = { ...process.env };
  delete environment.GROQ_API_KEY;
  const result = spawnSync(
    process.execPath,
    [harnessPath, '--dry-run', '--model=openai/gpt-oss-120b'],
    {
      cwd: __dirname,
      encoding: 'utf8',
      env: environment,
      timeout: 10_000,
    },
  );

  assert.equal(result.status, 0);
  assert.equal(result.stderr, '');
  const rows = result.stdout.trimEnd().split(/\r?\n/u).slice(1);
  assert.equal(rows.length, 25);
  assert.ok(
    rows.every((row) => row.split(',')[3] === 'openai/gpt-oss-120b'),
  );
});

test('rubrics are deterministic and CSV output contains no evaluated text', () => {
  const item = harness.CASES.find((candidate) => candidate.id === 'EN06');
  const evaluatedText =
    'Compound interest means interest can grow on earlier interest over time.';
  const rubric = harness.evaluateRubrics(
    item,
    evaluatedText,
    Buffer.byteLength(evaluatedText, 'utf8'),
  );

  assert.deepEqual(rubric, {
    nonempty: true,
    languageMatch: true,
    relevance: true,
    bounded: true,
  });

  const csv = harness.resultToCsv({
    caseId: item.id,
    category: item.category,
    language: item.language,
    modelId: harness.MODEL_ID,
    status: 'ok',
    firstContentMs: 120,
    completionMs: 480,
    chunks: 4,
    responseSizeBytes: Buffer.byteLength(evaluatedText, 'utf8'),
    rubricNonempty: rubric.nonempty,
    rubricLanguageMatch: rubric.languageMatch,
    rubricRelevance: rubric.relevance,
    rubricBounded: rubric.bounded,
  });

  assert.ok(!csv.includes(evaluatedText));
  assert.equal(csv.trimEnd().split(',').length, harness.CSV_HEADER.length);
});

test('one transient failure before content permits exactly one retry', async () => {
  const originalFetch = global.fetch;
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    if (calls === 1) {
      return new Response(null, { status: 503 });
    }
    const body = [
      'data: {"choices":[{"delta":{"content":"Compound interest grows over time."}}]}',
      '',
      'data: [DONE]',
      '',
    ].join('\n');
    return new Response(body, {
      status: 200,
      headers: { 'content-type': 'text/event-stream' },
    });
  };

  try {
    const item = harness.CASES.find((candidate) => candidate.id === 'EN06');
    const result = await harness.runCase(item, 'synthetic-test-key');
    assert.equal(calls, 2);
    assert.equal(result.status, 'ok');
    assert.equal(result.chunks, 1);
  } finally {
    global.fetch = originalFetch;
  }
});

test('a stream failure after content is never retried', async () => {
  const originalFetch = global.fetch;
  let calls = 0;
  global.fetch = async () => {
    calls += 1;
    let step = 0;
    const body = new ReadableStream({
      pull(controller) {
        if (step === 0) {
          step += 1;
          controller.enqueue(
            new TextEncoder().encode(
              'data: {"choices":[{"delta":{"content":"Compound interest"}}]}\n\n',
            ),
          );
          return;
        }
        controller.error(new Error('synthetic_stream_failure'));
      },
    });
    return new Response(body, {
      status: 200,
      headers: { 'content-type': 'text/event-stream' },
    });
  };

  try {
    const item = harness.CASES.find((candidate) => candidate.id === 'EN06');
    const result = await harness.runCase(item, 'synthetic-test-key');
    assert.equal(calls, 1);
    assert.equal(result.status, 'network_error');
    assert.equal(result.chunks, 1);
    assert.ok(result.responseSizeBytes > 0);
  } finally {
    global.fetch = originalFetch;
  }
});
