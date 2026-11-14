import 'dart:async';
import 'dart:convert';

class BufferedSseFrame {
  const BufferedSseFrame({this.event, this.id, required this.data});

  final String? event;
  final String? id;
  final String data;
}

/// Decodes SSE by event frames rather than assuming a network chunk or a line
/// is a complete event. UTF-8 is decoded before line framing, so a multibyte
/// Arabic character may be split across arbitrary byte chunks safely.
class BufferedSseDecoder
    extends StreamTransformerBase<List<int>, BufferedSseFrame> {
  const BufferedSseDecoder({
    this.maxLineCharacters = 128 * 1024,
    this.maxEventCharacters = 128 * 1024,
    this.maxStreamBytes = 2 * 1024 * 1024,
  }) : assert(maxLineCharacters > 0),
       assert(maxEventCharacters > 0),
       assert(maxStreamBytes > 0);

  final int maxLineCharacters;
  final int maxEventCharacters;
  final int maxStreamBytes;

  @override
  Stream<BufferedSseFrame> bind(Stream<List<int>> stream) async* {
    var pending = '';
    var eventName = '';
    var eventId = '';
    var dataLines = <String>[];
    var eventCharacters = 0;
    var streamBytes = 0;

    BufferedSseFrame? dispatch() {
      if (dataLines.isEmpty) {
        eventName = '';
        eventId = '';
        eventCharacters = 0;
        return null;
      }
      final frame = BufferedSseFrame(
        event: eventName.isEmpty ? null : eventName,
        id: eventId.isEmpty ? null : eventId,
        data: dataLines.join('\n'),
      );
      eventName = '';
      eventId = '';
      dataLines = <String>[];
      eventCharacters = 0;
      return frame;
    }

    BufferedSseFrame? consumeLine(String rawLine) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (line.isEmpty) {
        return dispatch();
      }
      if (line.length > maxLineCharacters) {
        throw const FormatException('SSE line exceeded the safe limit.');
      }
      eventCharacters += line.length + 1;
      if (eventCharacters > maxEventCharacters) {
        throw const FormatException('SSE event exceeded the safe limit.');
      }
      if (line.startsWith(':')) {
        return null;
      }
      final separator = line.indexOf(':');
      final field = separator < 0 ? line : line.substring(0, separator);
      var value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
      switch (field) {
        case 'event':
          eventName = value;
        case 'id':
          eventId = value;
        case 'data':
          dataLines.add(value);
      }
      return null;
    }

    final boundedStream = stream.map((bytes) {
      streamBytes += bytes.length;
      if (streamBytes > maxStreamBytes) {
        throw const FormatException('SSE stream exceeded the safe limit.');
      }
      return bytes;
    });
    await for (final text in boundedStream.transform(utf8.decoder)) {
      pending += text;
      for (;;) {
        final newline = pending.indexOf('\n');
        if (newline < 0) {
          break;
        }
        final line = pending.substring(0, newline);
        pending = pending.substring(newline + 1);
        final frame = consumeLine(line);
        if (frame != null) {
          yield frame;
        }
      }
      if (pending.length > maxLineCharacters) {
        throw const FormatException('SSE line exceeded the safe limit.');
      }
    }

    if (pending.isNotEmpty) {
      final frame = consumeLine(pending);
      if (frame != null) {
        yield frame;
      }
    }
    final finalFrame = dispatch();
    if (finalFrame != null) {
      yield finalFrame;
    }
  }
}
