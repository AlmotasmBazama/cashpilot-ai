import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../../receipts/receipt_cleanup.dart';
import '../../domain/entities/data_deletion_operation_context.dart';

typedef BeforeReceiptFileDelete = Future<void> Function(String token);

abstract interface class ReceiptFileDeletionJournal {
  Future<void> stage(
    DataDeletionOperationContext context,
    Iterable<String?> references, {
    Iterable<String?> protectedLegacyReferences = const <String?>[],
  });

  Future<int> drain(DataDeletionOperationContext context);
}

/// Durable retry journal containing only opaque SHA-256 image tokens.
///
/// It is staged before the Drift transaction, but files are drained only after
/// that transaction commits. Chunks are committed before their small manifest,
/// so a crash always leaves either the previous complete generation or the new
/// complete generation readable.
final class HiveReceiptFileDeletionJournal
    implements ReceiptFileDeletionJournal {
  const HiveReceiptFileDeletionJournal(
    this._box, {
    required ReceiptImageCleanupPort receiptImageStore,
    BeforeReceiptFileDelete? beforeDelete,
  }) : _receiptImageStore = receiptImageStore,
       _beforeDelete = beforeDelete;

  final Box<dynamic> _box;
  final ReceiptImageCleanupPort _receiptImageStore;
  final BeforeReceiptFileDelete? _beforeDelete;

  static const int _journalVersion = 2;
  static const int _tokensPerChunk = 256;
  static const int _maximumTokenCount = 65536;
  static const int _maximumEncodedEntryLength = 64 * 1024;
  static const int _maximumLegacyJournalLength = 8 * 1024 * 1024;
  static final RegExp _tokenPattern = RegExp(
    r'^(?:legacy:)?[a-f0-9]{64}\.jpg$',
  );
  static final RegExp _generationPattern = RegExp(r'^[a-f0-9]{64}$');

  @override
  Future<void> stage(
    DataDeletionOperationContext context,
    Iterable<String?> references, {
    Iterable<String?> protectedLegacyReferences = const <String?>[],
  }) async {
    final tokens = <String>{..._readTokens(context)};
    // Only the final filenames explicitly owned by this scope are enumerated.
    // An unknown future staging/temp filename makes this pre-transaction step
    // fail closed instead of becoming a silent orphan.
    tokens.addAll(await _receiptImageStore.listDeletionTokens());
    for (final reference in references) {
      final token = await _receiptImageStore.deletionTokenForReference(
        reference,
      );
      if (token != null) {
        tokens.add(token);
      }
    }
    // Legacy files lived in one global directory. If any non-target owner row
    // still references the same exact legacy path, protection wins even when
    // an older retry journal had already staged that token for deletion.
    final protectedLegacyTokens = <String>{};
    for (final reference in protectedLegacyReferences) {
      final token = await _receiptImageStore.deletionTokenForReference(
        reference,
      );
      if (token != null && token.startsWith('legacy:')) {
        protectedLegacyTokens.add(token);
      }
    }
    tokens.removeAll(protectedLegacyTokens);
    final sortedTokens = tokens.toList(growable: false)..sort();
    _validateTokens(sortedTokens);
    final generation = _generationFor(sortedTokens);
    final encodedChunks = <String>[];
    for (
      var offset = 0;
      offset < sortedTokens.length;
      offset += _tokensPerChunk
    ) {
      final end = (offset + _tokensPerChunk).clamp(0, sortedTokens.length);
      final index = offset ~/ _tokensPerChunk;
      final encoded = jsonEncode(<String, Object>{
        'version': _journalVersion,
        'generation': generation,
        'index': index,
        'tokens': sortedTokens.sublist(offset, end),
      });
      _assertBoundedEntry(encoded);
      encodedChunks.add(encoded);
    }
    final manifest = jsonEncode(<String, Object>{
      'version': _journalVersion,
      'generation': generation,
      'chunkCount': encodedChunks.length,
      'tokenCount': sortedTokens.length,
    });
    _assertBoundedEntry(manifest);

    for (var index = 0; index < encodedChunks.length; index += 1) {
      await _box.put(
        _chunkKey(context, generation: generation, index: index),
        encodedChunks[index],
      );
    }
    await _box.put(_key(context), manifest);
    await _deleteStaleChunks(context, retainedGeneration: generation);
  }

  @override
  Future<int> drain(DataDeletionOperationContext context) async {
    if (!_box.containsKey(_key(context))) {
      if (await _receiptImageStore.isEmpty) {
        await _deleteAllJournalEntries(context);
        return 0;
      }
      throw StateError('Receipt deletion journal is missing.');
    }
    final tokens = _readTokens(context);
    var deleted = 0;
    for (final token in tokens) {
      await _beforeDelete?.call(token);
      if (await _receiptImageStore.deleteToken(token)) {
        deleted += 1;
      }
    }
    if (!await _receiptImageStore.isEmpty) {
      throw StateError('Receipt image deletion could not be verified.');
    }
    await _receiptImageStore.deleteAll();
    await _deleteAllJournalEntries(context);
    return deleted;
  }

  List<String> _readTokens(DataDeletionOperationContext context) {
    final value = _box.get(_key(context));
    if (value == null) {
      return const <String>[];
    }
    if (value is! String || value.length > _maximumLegacyJournalLength) {
      throw StateError('Receipt deletion journal is invalid.');
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Receipt deletion journal is invalid.');
      }
      if (decoded['version'] == 1) {
        return _readLegacyTokens(decoded);
      }
      if (decoded['version'] == _journalVersion) {
        if (value.length > _maximumEncodedEntryLength) {
          throw StateError('Receipt deletion journal is invalid.');
        }
        return _readChunkedTokens(context, decoded);
      }
      throw StateError('Receipt deletion journal is invalid.');
    } on StateError {
      rethrow;
    } on Object {
      throw StateError('Receipt deletion journal is invalid.');
    }
  }

  List<String> _readLegacyTokens(Map<String, dynamic> manifest) {
    final rawTokens = manifest['tokens'];
    if (rawTokens is! List || rawTokens.length > _maximumTokenCount) {
      throw StateError('Receipt deletion journal is invalid.');
    }
    if (rawTokens.any(
      (token) => token is! String || !_tokenPattern.hasMatch(token),
    )) {
      throw StateError('Receipt deletion journal is invalid.');
    }
    return rawTokens.cast<String>().toSet().toList(growable: false)..sort();
  }

  List<String> _readChunkedTokens(
    DataDeletionOperationContext context,
    Map<String, dynamic> manifest,
  ) {
    final generation = manifest['generation'];
    final chunkCount = manifest['chunkCount'];
    final tokenCount = manifest['tokenCount'];
    if (generation is! String ||
        !_generationPattern.hasMatch(generation) ||
        chunkCount is! int ||
        tokenCount is! int ||
        tokenCount < 0 ||
        tokenCount > _maximumTokenCount ||
        chunkCount != (tokenCount + _tokensPerChunk - 1) ~/ _tokensPerChunk) {
      throw StateError('Receipt deletion journal is invalid.');
    }

    final tokens = <String>[];
    for (var index = 0; index < chunkCount; index += 1) {
      final encoded = _box.get(
        _chunkKey(context, generation: generation, index: index),
      );
      if (encoded is! String || encoded.length > _maximumEncodedEntryLength) {
        throw StateError('Receipt deletion journal is invalid.');
      }
      Object? decoded;
      try {
        decoded = jsonDecode(encoded);
      } on Object {
        throw StateError('Receipt deletion journal is invalid.');
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _journalVersion ||
          decoded['generation'] != generation ||
          decoded['index'] != index ||
          decoded['tokens'] is! List) {
        throw StateError('Receipt deletion journal is invalid.');
      }
      final rawTokens = decoded['tokens'] as List;
      final expectedLength = index == chunkCount - 1
          ? tokenCount - (index * _tokensPerChunk)
          : _tokensPerChunk;
      if (rawTokens.length != expectedLength ||
          rawTokens.any(
            (token) => token is! String || !_tokenPattern.hasMatch(token),
          )) {
        throw StateError('Receipt deletion journal is invalid.');
      }
      tokens.addAll(rawTokens.cast<String>());
    }

    _validateTokens(tokens);
    if (tokens.length != tokenCount ||
        tokens.toSet().length != tokenCount ||
        _generationFor(tokens) != generation) {
      throw StateError('Receipt deletion journal is invalid.');
    }
    return tokens;
  }

  void _validateTokens(List<String> tokens) {
    if (tokens.length > _maximumTokenCount ||
        tokens.any((token) => !_tokenPattern.hasMatch(token))) {
      throw StateError('Receipt deletion journal is invalid.');
    }
  }

  String _generationFor(List<String> tokens) =>
      sha256.convert(utf8.encode(tokens.join('\u0000'))).toString();

  void _assertBoundedEntry(String encoded) {
    if (encoded.length > _maximumEncodedEntryLength) {
      throw StateError('Receipt deletion journal entry is oversized.');
    }
  }

  Future<void> _deleteStaleChunks(
    DataDeletionOperationContext context, {
    required String retainedGeneration,
  }) async {
    final prefix = _chunkPrefix(context);
    final retainedPrefix = '$prefix$retainedGeneration:';
    final staleKeys = _box.keys
        .whereType<String>()
        .where(
          (key) => key.startsWith(prefix) && !key.startsWith(retainedPrefix),
        )
        .toList(growable: false);
    if (staleKeys.isNotEmpty) {
      await _box.deleteAll(staleKeys);
    }
  }

  Future<void> _deleteAllJournalEntries(
    DataDeletionOperationContext context,
  ) async {
    final manifestKey = _key(context);
    final chunkPrefix = _chunkPrefix(context);
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key == manifestKey || key.startsWith(chunkPrefix))
        .toList(growable: false);
    if (keys.isNotEmpty) {
      await _box.deleteAll(keys);
    }
  }

  String _chunkPrefix(DataDeletionOperationContext context) =>
      '${_key(context)}:chunk:';

  String _chunkKey(
    DataDeletionOperationContext context, {
    required String generation,
    required int index,
  }) => '${_chunkPrefix(context)}$generation:$index';

  String _key(DataDeletionOperationContext context) =>
      OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        context.identity.ownerScope,
      ).receiptFileDeletionJournal(context.operationId);
}
