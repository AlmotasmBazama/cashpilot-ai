'use strict';

function safeCodeFor(error) {
  const candidate = error?.safeCode;
  return typeof candidate === 'string' && /^[a-z0-9_]+$/.test(candidate)
    ? candidate
    : 'runner_failure';
}

function serializeSafeMarkerFields(fields, invalidValueError) {
  return Object.entries(fields).map(([key, value]) => {
    const text = String(value);
    if (
      !/^[A-Za-z][A-Za-z0-9]*$/.test(key) ||
      !/^[A-Za-z0-9_.-]+$/.test(text)
    ) {
      throw invalidValueError();
    }
    return `${key}=${text}`;
  });
}

module.exports = {
  safeCodeFor,
  serializeSafeMarkerFields,
};
