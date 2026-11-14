import 'dart:convert';

import 'package:cashpilot_ai/features/ai_assistant/data/gateway/buffered_sse_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bounds accumulated multiline event data', () async {
    const decoder = BufferedSseDecoder(
      maxLineCharacters: 32,
      maxEventCharacters: 20,
      maxStreamBytes: 256,
    );

    await expectLater(
      Stream<List<int>>.value(
        utf8.encode('data: 12345678\ndata: 12345678\n\n'),
      ).transform(decoder).toList(),
      throwsA(isA<FormatException>()),
    );
  });

  test('bounds a line even when it arrives across chunks', () async {
    const decoder = BufferedSseDecoder(
      maxLineCharacters: 12,
      maxEventCharacters: 64,
      maxStreamBytes: 256,
    );

    await expectLater(
      Stream<List<int>>.fromIterable(<List<int>>[
        utf8.encode('data: 1234'),
        utf8.encode('567890\n\n'),
      ]).transform(decoder).toList(),
      throwsA(isA<FormatException>()),
    );
  });

  test('bounds total bytes including comments and optional fields', () async {
    const decoder = BufferedSseDecoder(
      maxLineCharacters: 64,
      maxEventCharacters: 128,
      maxStreamBytes: 20,
    );

    await expectLater(
      Stream<List<int>>.fromIterable(<List<int>>[
        utf8.encode(': keepalive\n\n'),
        utf8.encode('retry: 1000\n\n'),
      ]).transform(decoder).toList(),
      throwsA(isA<FormatException>()),
    );
  });

  test('comments and optional fields remain safe and ignorable', () async {
    const decoder = BufferedSseDecoder(
      maxLineCharacters: 64,
      maxEventCharacters: 128,
      maxStreamBytes: 256,
    );
    final frames = await Stream<List<int>>.value(
      utf8.encode(
        ': keepalive\n'
        'retry: 1000\n'
        'event: cashpilot\n'
        'id: request_1\n'
        'data: {"type":"started"}\n\n',
      ),
    ).transform(decoder).toList();

    expect(frames, hasLength(1));
    expect(frames.single.event, 'cashpilot');
    expect(frames.single.id, 'request_1');
    expect(frames.single.data, '{"type":"started"}');
  });
}
