'use strict';

const maxUiXmlBytes = 2 * 1024 * 1024;

function decodeXmlAttribute(value) {
  return value
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
}

function nodeAttributes(fragment) {
  const attributes = Object.create(null);
  for (const match of fragment.matchAll(/([A-Za-z0-9_-]+)="([^"]*)"/g)) {
    attributes[match[1]] = decodeXmlAttribute(match[2]);
  }
  return attributes;
}

function rectFromBounds(bounds) {
  const match = /^\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]$/.exec(
    bounds || '',
  );
  if (!match) {
    return null;
  }
  const left = Number(match[1]);
  const top = Number(match[2]);
  const right = Number(match[3]);
  const bottom = Number(match[4]);
  if (right <= left || bottom <= top) {
    return null;
  }
  return Object.freeze({ left, top, right, bottom });
}

function pointFromRect(rect) {
  return Object.freeze({
    x: Math.floor((rect.left + rect.right) / 2),
    y: Math.floor((rect.top + rect.bottom) / 2),
  });
}

function pointFromBounds(bounds) {
  const rect = rectFromBounds(bounds);
  return rect === null ? null : pointFromRect(rect);
}

function assertBoundedUiXml(xml, invalidSnapshotError) {
  if (
    typeof xml !== 'string' ||
    Buffer.byteLength(xml, 'utf8') > maxUiXmlBytes
  ) {
    throw invalidSnapshotError();
  }
}

function resourceIdMatches(resourceId, identifier) {
  return (
    resourceId === identifier ||
    resourceId.endsWith(`/${identifier}`) ||
    resourceId.endsWith(`:${identifier}`)
  );
}

module.exports = {
  assertBoundedUiXml,
  decodeXmlAttribute,
  maxUiXmlBytes,
  nodeAttributes,
  pointFromBounds,
  pointFromRect,
  rectFromBounds,
  resourceIdMatches,
};
