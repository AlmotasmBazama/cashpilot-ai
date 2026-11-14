export function textDeltas(text: string, maxChunkLength = 180): string[] {
  const result: string[] = [];
  for (let offset = 0; offset < text.length; offset += maxChunkLength) {
    result.push(text.slice(offset, offset + maxChunkLength));
  }
  return result;
}
