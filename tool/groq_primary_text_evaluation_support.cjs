'use strict';

const fs = require('node:fs');

const MODEL_ID = 'openai/gpt-oss-20b';
const ALLOWED_MODEL_IDS = Object.freeze([
  MODEL_ID,
  'openai/gpt-oss-120b',
]);
const GROQ_CHAT_COMPLETIONS_URL =
  'https://api.groq.com/openai/v1/chat/completions';

const CASE_TIMEOUT_MS = 45_000;
const ATTEMPT_TIMEOUT_MS = 20_000;
const MAX_ATTEMPTS = 2;
const MAX_RETRY_DELAY_MS = 750;
const DEFAULT_BETWEEN_CASE_DELAY_MS = 250;
const MAX_BETWEEN_CASE_DELAY_MS = 10_000;
const MAX_STREAM_BYTES = 256 * 1024;
const MAX_SSE_LINE_BYTES = 64 * 1024;
const MAX_SSE_EVENT_BYTES = 96 * 1024;
const MAX_CONTENT_BYTES = 16 * 1024;

const CSV_HEADER = Object.freeze([
  'case_id',
  'category',
  'language',
  'model',
  'status',
  'first_content_ms',
  'completion_ms',
  'chunks',
  'response_size_bytes',
  'rubric_nonempty',
  'rubric_language_match',
  'rubric_relevance',
  'rubric_bounded',
]);

// All prompts are fictional, contain no account data, and are never emitted by
// this process. The signal patterns are deliberately coarse deterministic
// checks; they are not a substitute for human quality review.
const CASES = Object.freeze([
  Object.freeze({
    id: 'AR01',
    category: 'finance_basics',
    language: 'ar',
    synthetic: true,
    prompt: 'اشرح الفرق بين الدخل والمصروف في جملتين واضحتين.',
    signals: Object.freeze([/دخل/u, /مصروف/u, /إنفاق/u]),
  }),
  Object.freeze({
    id: 'AR02',
    category: 'budgeting',
    language: 'ar',
    synthetic: true,
    prompt: 'اقترح تقسيمًا بسيطًا لميزانية شهرية مع توضيح أن النسب قابلة للتعديل.',
    signals: Object.freeze([/ميزاني/u, /نسب/u, /احتياج/u]),
  }),
  Object.freeze({
    id: 'AR03',
    category: 'emergency_fund',
    language: 'ar',
    synthetic: true,
    prompt: 'ما فائدة صندوق الطوارئ وكيف يبدأ شخص بمبلغ صغير؟',
    signals: Object.freeze([/طوارئ/u, /ادخار/u, /احتياط/u]),
  }),
  Object.freeze({
    id: 'AR04',
    category: 'saving_goal',
    language: 'ar',
    synthetic: true,
    prompt: 'ضع خطة حسابية موجزة لادخار 1200 دينار خلال 6 أشهر.',
    signals: Object.freeze([/200/u, /ادخار/u, /شهر/u]),
  }),
  Object.freeze({
    id: 'AR05',
    category: 'debt_repayment',
    language: 'ar',
    synthetic: true,
    prompt: 'اشرح باختصار كيف يمكن ترتيب عدة ديون للسداد بطريقة مسؤولة.',
    signals: Object.freeze([/دين/u, /ديون/u, /سداد/u]),
  }),
  Object.freeze({
    id: 'AR06',
    category: 'interest_education',
    language: 'ar',
    synthetic: true,
    prompt: 'وضّح الفرق بين الفائدة البسيطة والفائدة المركبة بمثال صغير.',
    signals: Object.freeze([/فائد/u, /مركب/u, /بسيط/u]),
  }),
  Object.freeze({
    id: 'AR07',
    category: 'spending_habits',
    language: 'ar',
    synthetic: true,
    prompt: 'اذكر ثلاث طرق عملية لتقليل المصروفات غير الضرورية من دون حرمان قاسٍ.',
    signals: Object.freeze([/مصروف/u, /إنفاق/u, /ضروري/u]),
  }),
  Object.freeze({
    id: 'AR08',
    category: 'variable_income',
    language: 'ar',
    synthetic: true,
    prompt: 'كيف يبني صاحب دخل متغير ميزانية شهرية محافظة؟',
    signals: Object.freeze([/دخل/u, /متغير/u, /ميزاني/u]),
  }),
  Object.freeze({
    id: 'AR09',
    category: 'risk_awareness',
    language: 'ar',
    synthetic: true,
    prompt: 'اشرح لماذا لا ينبغي استثمار مال الإيجار أو الاحتياجات الأساسية.',
    signals: Object.freeze([/مخاطر/u, /إيجار/u, /أساسي/u]),
  }),
  Object.freeze({
    id: 'AR10',
    category: 'investment_safety',
    language: 'ar',
    synthetic: true,
    prompt: 'كيف ترد على عرض استثماري يدّعي ربحًا مضمونًا وسريعًا؟',
    signals: Object.freeze([/مضمون/u, /مخاطر/u, /احتيال/u]),
  }),
  Object.freeze({
    id: 'AR11',
    category: 'fraud_awareness',
    language: 'ar',
    synthetic: true,
    prompt: 'اذكر علامات عامة تساعد على اكتشاف عرض مالي احتيالي.',
    signals: Object.freeze([/احتيال/u, /تحقق/u, /تحذير/u]),
  }),
  Object.freeze({
    id: 'AR12',
    category: 'libyan_arabic',
    language: 'ar',
    synthetic: true,
    prompt: 'باللهجة الليبية الخفيفة، فسّر كيف نراجع صرف الأسبوع بطريقة بسيطة ومحترمة.',
    signals: Object.freeze([/صرف/u, /أسبوع/u, /مصاريف/u]),
  }),
  Object.freeze({
    id: 'AR13',
    category: 'purchase_decision',
    language: 'ar',
    synthetic: true,
    prompt: 'ما الذي يجب مقارنته عند الاختيار بين الدفع نقدًا والتقسيط؟',
    signals: Object.freeze([/تقسيط/u, /نقد/u, /تكلف/u]),
  }),
  Object.freeze({
    id: 'AR14',
    category: 'inflation_education',
    language: 'ar',
    synthetic: true,
    prompt: 'اشرح أثر التضخم على القوة الشرائية بلغة عربية سهلة.',
    signals: Object.freeze([/تضخم/u, /قوة شرائية/u, /أسعار/u]),
  }),
  Object.freeze({
    id: 'AR15',
    category: 'professional_help',
    language: 'ar',
    synthetic: true,
    prompt: 'متى يكون طلب مساعدة مستشار مالي مرخص قرارًا مناسبًا؟',
    signals: Object.freeze([/مستشار/u, /مرخص/u, /مختص/u]),
  }),
  Object.freeze({
    id: 'EN01',
    category: 'finance_basics',
    language: 'en',
    synthetic: true,
    prompt: 'Explain the difference between income and an expense in two clear sentences.',
    signals: Object.freeze([/income/i, /expense/i, /spend/i]),
  }),
  Object.freeze({
    id: 'EN02',
    category: 'budgeting',
    language: 'en',
    synthetic: true,
    prompt: 'Explain the 50-30-20 budget as a flexible guideline, including one limitation.',
    signals: Object.freeze([/budget/i, /needs/i, /flexib/i]),
  }),
  Object.freeze({
    id: 'EN03',
    category: 'emergency_fund',
    language: 'en',
    synthetic: true,
    prompt: 'Why is an emergency fund useful, and how can someone start small?',
    signals: Object.freeze([/emergency/i, /saving/i, /unexpected/i]),
  }),
  Object.freeze({
    id: 'EN04',
    category: 'saving_goal',
    language: 'en',
    synthetic: true,
    prompt: 'Give a short calculation for saving 2400 dollars evenly over 8 months.',
    signals: Object.freeze([/300/i, /month/i, /sav/i]),
  }),
  Object.freeze({
    id: 'EN05',
    category: 'debt_repayment',
    language: 'en',
    synthetic: true,
    prompt: 'Compare the debt avalanche and debt snowball methods without choosing for the reader.',
    signals: Object.freeze([/avalanche/i, /snowball/i, /interest/i]),
  }),
  Object.freeze({
    id: 'EN06',
    category: 'interest_education',
    language: 'en',
    synthetic: true,
    prompt: 'Explain compound interest with a small, easy-to-follow example.',
    signals: Object.freeze([/compound/i, /interest/i, /grow/i]),
  }),
  Object.freeze({
    id: 'EN07',
    category: 'variable_income',
    language: 'en',
    synthetic: true,
    prompt: 'Suggest a conservative budgeting approach for irregular monthly income.',
    signals: Object.freeze([/income/i, /budget/i, /minimum/i]),
  }),
  Object.freeze({
    id: 'EN08',
    category: 'fraud_awareness',
    language: 'en',
    synthetic: true,
    prompt: 'List common red flags of an online financial scam in concise language.',
    signals: Object.freeze([/scam/i, /pressure/i, /guarantee/i]),
  }),
  Object.freeze({
    id: 'EN09',
    category: 'investment_safety',
    language: 'en',
    synthetic: true,
    prompt: 'Respond cautiously to a claim of guaranteed high investment returns.',
    signals: Object.freeze([/guarantee/i, /risk/i, /fraud/i]),
  }),
  Object.freeze({
    id: 'EN10',
    category: 'professional_help',
    language: 'en',
    synthetic: true,
    prompt: 'When may speaking with a licensed financial adviser be appropriate?',
    signals: Object.freeze([/adviser/i, /advisor/i, /licensed/i]),
  }),
]);

class EvaluationFailure extends Error {
  constructor(code, options = {}) {
    super(code);
    this.name = 'EvaluationFailure';
    this.code = safeStatus(code);
    this.transient = options.transient === true;
    this.sawContent = options.sawContent === true;
    this.retryAfterMs = Number.isFinite(options.retryAfterMs)
      ? Math.max(0, Math.min(MAX_RETRY_DELAY_MS, options.retryAfterMs))
      : 0;
    this.metrics = options.metrics ?? emptyMetrics();
  }
}

function validateCases() {
  if (CASES.length !== 25) {
    throw new Error('invalid_case_count');
  }

  const arabicCount = CASES.filter((item) => item.language === 'ar').length;
  const englishCount = CASES.filter((item) => item.language === 'en').length;
  if (arabicCount !== 15 || englishCount !== 10) {
    throw new Error('invalid_language_count');
  }

  const ids = new Set();
  const unsafePromptPatterns = [
    /https?:\/\//iu,
    /[A-Z]:\\/u,
    /(?:^|\s)\/Users\//u,
    /[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/u,
    /\d{7,}/u,
    /(?:api[_ -]?key|password|كلمة مرور|مفتاح واجهة)/iu,
  ];

  for (const item of CASES) {
    if (!/^(?:AR\d{2}|EN\d{2})$/u.test(item.id) || ids.has(item.id)) {
      throw new Error('invalid_case_id');
    }
    ids.add(item.id);

    if (
      item.synthetic !== true ||
      !/^[a-z_]+$/u.test(item.category) ||
      !['ar', 'en'].includes(item.language) ||
      typeof item.prompt !== 'string' ||
      item.prompt.length < 12 ||
      item.prompt.length > 240 ||
      !Array.isArray(item.signals) ||
      item.signals.length === 0 ||
      unsafePromptPatterns.some((pattern) => pattern.test(item.prompt))
    ) {
      throw new Error('invalid_case_definition');
    }
  }

  return true;
}

function emptyMetrics() {
  return {
    firstContentMs: null,
    completionMs: 0,
    chunks: 0,
    responseSizeBytes: 0,
  };
}

function safeStatus(value) {
  const candidate = String(value ?? 'evaluation_error').toLowerCase();
  return /^[a-z][a-z0-9_]{0,47}$/u.test(candidate)
    ? candidate
    : 'evaluation_error';
}

function parseRetryAfter(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    return 0;
  }

  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.min(MAX_RETRY_DELAY_MS, Math.round(seconds * 1000));
  }

  const absoluteTime = Date.parse(value);
  if (!Number.isFinite(absoluteTime)) {
    return 0;
  }
  return Math.min(
    MAX_RETRY_DELAY_MS,
    Math.max(0, absoluteTime - Date.now()),
  );
}

function isTransientHttpStatus(status) {
  return [408, 425, 429, 500, 502, 503, 504].includes(status);
}

function metricsSnapshot(startedAt, firstContentMs, chunks, responseSizeBytes) {
  return {
    firstContentMs,
    completionMs: Math.max(0, Date.now() - startedAt),
    chunks,
    responseSizeBytes,
  };
}

function evaluateRubrics(item, content, responseSizeBytes) {
  const trimmed = content.trim();
  const arabicCharacters = (trimmed.match(/[\u0600-\u06ff]/gu) ?? []).length;
  const latinCharacters = (trimmed.match(/[A-Za-z]/gu) ?? []).length;
  const languageMatch =
    item.language === 'ar'
      ? arabicCharacters >= 12 && arabicCharacters >= latinCharacters
      : latinCharacters >= 20 && latinCharacters > arabicCharacters * 2;

  return {
    nonempty: trimmed.length > 0,
    languageMatch,
    relevance: item.signals.some((pattern) => pattern.test(trimmed)),
    bounded:
      responseSizeBytes > 0 && responseSizeBytes <= MAX_CONTENT_BYTES,
  };
}

function csvCell(value) {
  if (value === null || value === undefined) {
    return '';
  }
  const text = String(value);
  return /[",\r\n]/u.test(text)
    ? `"${text.replaceAll('"', '""')}"`
    : text;
}

function csvLine(values) {
  return `${values.map(csvCell).join(',')}\n`;
}

function resultToCsv(result) {
  return csvLine([
    result.caseId,
    result.category,
    result.language,
    result.modelId,
    result.status,
    result.firstContentMs,
    result.completionMs,
    result.chunks,
    result.responseSizeBytes,
    result.rubricNonempty,
    result.rubricLanguageMatch,
    result.rubricRelevance,
    result.rubricBounded,
  ]);
}

function makeResult(item, modelId, status, metrics, rubrics = null) {
  return {
    caseId: item.id,
    category: item.category,
    language: item.language,
    modelId,
    status: safeStatus(status),
    firstContentMs: metrics.firstContentMs,
    completionMs: metrics.completionMs,
    chunks: metrics.chunks,
    responseSizeBytes: metrics.responseSizeBytes,
    rubricNonempty: rubrics?.nonempty ?? false,
    rubricLanguageMatch: rubrics?.languageMatch ?? false,
    rubricRelevance: rubrics?.relevance ?? false,
    rubricBounded: rubrics?.bounded ?? false,
  };
}

function makeDryRunResult(item, modelId) {
  return {
    caseId: item.id,
    category: item.category,
    language: item.language,
    modelId,
    status: 'dry_run',
    firstContentMs: null,
    completionMs: null,
    chunks: null,
    responseSizeBytes: null,
    rubricNonempty: null,
    rubricLanguageMatch: null,
    rubricRelevance: null,
    rubricBounded: null,
  };
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function cancelBody(response) {
  try {
    await response?.body?.cancel();
  } catch {
    // Cancellation failures contain no useful evaluation evidence.
  }
}

async function runAttempt(item, apiKey, modelId, caseStartedAt, timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  let reader = null;
  let streamFinished = false;
  let firstContentMs = null;
  let chunks = 0;
  let responseSizeBytes = 0;
  let totalStreamBytes = 0;
  const contentParts = [];

  const snapshot = () =>
    metricsSnapshot(
      caseStartedAt,
      firstContentMs,
      chunks,
      responseSizeBytes,
    );

  const failure = (code, transient, retryAfterMs = 0) =>
    new EvaluationFailure(code, {
      transient,
      sawContent: firstContentMs !== null,
      retryAfterMs,
      metrics: snapshot(),
    });

  try {
    const response = await fetch(GROQ_CHAT_COMPLETIONS_URL, {
      method: 'POST',
      headers: {
        Accept: 'text/event-stream',
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(evaluationRequestBody(item, modelId)),
      signal: controller.signal,
    });

    if (!response.ok) {
      const retryAfterMs = parseRetryAfter(response.headers.get('retry-after'));
      const status = Number.isInteger(response.status)
        ? `http_${response.status}`
        : 'http_error';
      await cancelBody(response);
      throw failure(status, isTransientHttpStatus(response.status), retryAfterMs);
    }

    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().includes('text/event-stream')) {
      await cancelBody(response);
      throw failure('unexpected_content_type', false);
    }
    if (!response.body) {
      throw failure('missing_stream', true);
    }

    reader = response.body.getReader();
    const decoder = new TextDecoder('utf-8', { fatal: true });
    let pendingText = '';
    let eventData = [];
    let sawDone = false;

    const processEvent = () => {
      if (eventData.length === 0) {
        return;
      }
      const payload = eventData.join('\n');
      eventData = [];
      if (Buffer.byteLength(payload, 'utf8') > MAX_SSE_EVENT_BYTES) {
        throw failure('sse_event_too_large', false);
      }
      if (payload.trim() === '[DONE]') {
        sawDone = true;
        return;
      }

      let decoded;
      try {
        decoded = JSON.parse(payload);
      } catch {
        throw failure('malformed_stream', false);
      }

      const delta = decoded?.choices?.[0]?.delta?.content;
      if (delta === null || delta === undefined || delta === '') {
        return;
      }
      if (typeof delta !== 'string') {
        throw failure('malformed_stream', false);
      }

      const deltaBytes = Buffer.byteLength(delta, 'utf8');
      if (responseSizeBytes + deltaBytes > MAX_CONTENT_BYTES) {
        throw failure('response_too_large', false);
      }
      if (firstContentMs === null) {
        firstContentMs = Math.max(0, Date.now() - caseStartedAt);
      }
      chunks += 1;
      responseSizeBytes += deltaBytes;
      contentParts.push(delta);
    };

    const processLine = (rawLine) => {
      const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine;
      if (Buffer.byteLength(line, 'utf8') > MAX_SSE_LINE_BYTES) {
        throw failure('sse_line_too_large', false);
      }
      if (line === '') {
        processEvent();
        return;
      }
      if (line.startsWith(':')) {
        return;
      }
      if (line === 'data') {
        eventData.push('');
        return;
      }
      if (line.startsWith('data:')) {
        const value = line.slice(5);
        eventData.push(value.startsWith(' ') ? value.slice(1) : value);
        if (
          Buffer.byteLength(eventData.join('\n'), 'utf8') >
          MAX_SSE_EVENT_BYTES
        ) {
          throw failure('sse_event_too_large', false);
        }
      }
    };

    while (!sawDone) {
      const { done, value } = await reader.read();
      if (done) {
        streamFinished = true;
        break;
      }
      totalStreamBytes += value.byteLength;
      if (totalStreamBytes > MAX_STREAM_BYTES) {
        throw failure('stream_too_large', false);
      }

      pendingText += decoder.decode(value, { stream: true });
      let newlineIndex = pendingText.indexOf('\n');
      while (newlineIndex >= 0) {
        processLine(pendingText.slice(0, newlineIndex));
        pendingText = pendingText.slice(newlineIndex + 1);
        if (sawDone) {
          break;
        }
        newlineIndex = pendingText.indexOf('\n');
      }
      if (Buffer.byteLength(pendingText, 'utf8') > MAX_SSE_LINE_BYTES) {
        throw failure('sse_line_too_large', false);
      }
    }

    if (sawDone && !streamFinished) {
      try {
        await reader.cancel();
      } catch {
        // The completion is already final; cancellation details are not evidence.
      }
      streamFinished = true;
    }

    if (!sawDone) {
      pendingText += decoder.decode();
      if (pendingText !== '') {
        processLine(pendingText);
      }
      processEvent();
    }

    if (!sawDone) {
      throw failure('incomplete_stream', true);
    }

    streamFinished = true;
    const content = contentParts.join('');
    if (content.trim() === '') {
      throw failure('empty_response', true);
    }

    const metrics = snapshot();
    return makeResult(
      item,
      modelId,
      'ok',
      metrics,
      evaluateRubrics(item, content, responseSizeBytes),
    );
  } catch (error) {
    if (error instanceof EvaluationFailure) {
      throw error;
    }
    if (controller.signal.aborted) {
      throw failure('timeout', true);
    }
    throw failure('network_error', true);
  } finally {
    clearTimeout(timeout);
    if (!streamFinished) {
      controller.abort();
      try {
        await reader?.cancel();
      } catch {
        // Never serialize reader errors because provider content may be attached.
      }
    }
    try {
      reader?.releaseLock();
    } catch {
      // The lock may already have been released during cancellation.
    }
  }
}

function evaluationRequestBody(item, modelId) {
  return {
    model: modelId,
    stream: true,
    temperature: 0.1,
    max_completion_tokens: 512,
    reasoning_effort: 'low',
    reasoning_format: 'hidden',
    messages: [{ role: 'user', content: item.prompt }],
  };
}

async function runCase(item, apiKey, modelId = MODEL_ID) {
  if (!ALLOWED_MODEL_IDS.includes(modelId)) {
    throw new Error('invalid_model');
  }
  const caseStartedAt = Date.now();
  let lastFailure = null;

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt += 1) {
    const elapsed = Date.now() - caseStartedAt;
    const remaining = CASE_TIMEOUT_MS - elapsed;
    if (remaining <= 0) {
      lastFailure = new EvaluationFailure('timeout', {
        transient: true,
        metrics: metricsSnapshot(caseStartedAt, null, 0, 0),
      });
      break;
    }

    try {
      return await runAttempt(
        item,
        apiKey,
        modelId,
        caseStartedAt,
        Math.min(ATTEMPT_TIMEOUT_MS, remaining),
      );
    } catch (error) {
      const normalized =
        error instanceof EvaluationFailure
          ? error
          : new EvaluationFailure('evaluation_error', {
              metrics: metricsSnapshot(caseStartedAt, null, 0, 0),
            });
      lastFailure = normalized;

      const canRetry =
        attempt + 1 < MAX_ATTEMPTS &&
        normalized.transient &&
        !normalized.sawContent;
      if (!canRetry) {
        break;
      }

      const delayMs = Math.max(150, normalized.retryAfterMs);
      if (Date.now() - caseStartedAt + delayMs >= CASE_TIMEOUT_MS) {
        break;
      }
      await sleep(delayMs);
    }
  }

  const failure =
    lastFailure ??
    new EvaluationFailure('evaluation_error', {
      metrics: metricsSnapshot(caseStartedAt, null, 0, 0),
    });
  return makeResult(item, modelId, failure.code, failure.metrics);
}

function parseArguments(argv) {
  let dryRun = false;
  let outputPath = null;
  let modelId = MODEL_ID;
  let betweenCaseDelayMs = DEFAULT_BETWEEN_CASE_DELAY_MS;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--dry-run') {
      dryRun = true;
      continue;
    }
    if (argument === '--output') {
      index += 1;
      if (argv[index] === undefined) {
        throw new Error('invalid_output');
      }
      outputPath = argv[index];
      continue;
    }
    if (argument.startsWith('--output=')) {
      outputPath = argument.slice('--output='.length);
      continue;
    }
    if (argument === '--model') {
      index += 1;
      if (argv[index] === undefined) {
        throw new Error('invalid_model');
      }
      modelId = argv[index];
      continue;
    }
    if (argument.startsWith('--model=')) {
      modelId = argument.slice('--model='.length);
      continue;
    }
    if (argument === '--between-case-delay-ms') {
      index += 1;
      if (argv[index] === undefined) {
        throw new Error('invalid_between_case_delay');
      }
      betweenCaseDelayMs = parseBetweenCaseDelay(argv[index]);
      continue;
    }
    if (argument.startsWith('--between-case-delay-ms=')) {
      betweenCaseDelayMs = parseBetweenCaseDelay(
        argument.slice('--between-case-delay-ms='.length),
      );
      continue;
    }
    throw new Error('invalid_argument');
  }

  if (
    outputPath !== null &&
    (typeof outputPath !== 'string' ||
      outputPath.trim() === '' ||
      !outputPath.toLowerCase().endsWith('.csv'))
  ) {
    throw new Error('invalid_output');
  }
  if (!ALLOWED_MODEL_IDS.includes(modelId)) {
    throw new Error('invalid_model');
  }

  return { dryRun, outputPath, modelId, betweenCaseDelayMs };
}

function parseBetweenCaseDelay(value) {
  if (!/^\d+$/u.test(value)) {
    throw new Error('invalid_between_case_delay');
  }
  const parsed = Number(value);
  if (
    !Number.isSafeInteger(parsed) ||
    parsed < DEFAULT_BETWEEN_CASE_DELAY_MS ||
    parsed > MAX_BETWEEN_CASE_DELAY_MS
  ) {
    throw new Error('invalid_between_case_delay');
  }
  return parsed;
}

function createWriter(outputPath) {
  if (outputPath === null) {
    return {
      write: (value) => process.stdout.write(value),
      close: () => {},
    };
  }

  // "wx" is intentional: sprint evidence must never replace an earlier run.
  const descriptor = fs.openSync(outputPath, 'wx', 0o600);
  return {
    write: (value) => fs.writeSync(descriptor, value, null, 'utf8'),
    close: () => fs.closeSync(descriptor),
  };
}

async function main(argv = process.argv.slice(2)) {
  validateCases();
  const { dryRun, outputPath, modelId, betweenCaseDelayMs } =
    parseArguments(argv);
  const apiKey = process.env.GROQ_API_KEY;

  if (!dryRun && (typeof apiKey !== 'string' || apiKey.trim() === '')) {
    throw new Error('missing_api_key');
  }

  const writer = createWriter(outputPath);
  let failed = false;
  try {
    writer.write(csvLine(CSV_HEADER));
    for (let index = 0; index < CASES.length; index += 1) {
      const item = CASES[index];
      const result = dryRun
        ? makeDryRunResult(item, modelId)
        : await runCase(item, apiKey, modelId);
      writer.write(resultToCsv(result));
      if (!dryRun && result.status !== 'ok') {
        failed = true;
      }
      if (!dryRun && index + 1 < CASES.length) {
        await sleep(betweenCaseDelayMs);
      }
    }
  } finally {
    writer.close();
  }

  if (failed) {
    process.exitCode = 1;
  }
}

function runCli() {
  return main().catch(() => {
    // Keep diagnostics fixed: exception messages can carry provider content.
    process.stderr.write('groq_text_evaluation_failed\n');
    process.exitCode = 1;
  });
}

if (require.main === module) {
  void runCli();
}

const publicApi = Object.freeze({
  ALLOWED_MODEL_IDS,
  CASES,
  CSV_HEADER,
  DEFAULT_BETWEEN_CASE_DELAY_MS,
  MODEL_ID,
  evaluationRequestBody,
  evaluateRubrics,
  parseArguments,
  resultToCsv,
  runCase,
  validateCases,
});

module.exports = Object.freeze({ publicApi, runCli });
