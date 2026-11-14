import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/services/receipt_image_cleanup_port.dart';

class ReceiptLocalImageStore implements ReceiptImageCleanupPort {
  const ReceiptLocalImageStore({
    required String ownerScopeValue,
    Future<Directory> Function()? baseDirectory,
  }) : _ownerScopeValue = ownerScopeValue,
       _baseDirectory = baseDirectory;

  final String _ownerScopeValue;
  final Future<Directory> Function()? _baseDirectory;

  static final RegExp _imageFilenamePattern = RegExp(r'^[a-f0-9]{64}\.jpg$');
  static const String _legacyTokenPrefix = 'legacy:';

  Future<String> write(String receiptId, List<int> bytes) async {
    final directory = await _receiptDirectory();
    await directory.create(recursive: true);
    final safeName = sha256.convert(receiptId.codeUnits).toString();
    final file = File(path.join(directory.path, '$safeName.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> deleteReference(String? reference) async {
    final token = await deletionTokenForReference(reference);
    if (token == null) {
      return;
    }
    await deleteToken(token);
  }

  /// Converts an absolute database reference into an opaque journal token.
  ///
  /// Current owner-scoped references and exact legacy global references are
  /// accepted. Legacy files are never enumerated: a token can only be created
  /// from the concrete reference captured from this owner's database row.
  /// Absolute paths are never persisted by the deletion journal.
  @override
  Future<String?> deletionTokenForReference(String? reference) async {
    if (reference == null || reference.trim().isEmpty) {
      return null;
    }
    _assertValidOwnerScope();
    final base = await (_baseDirectory ?? getApplicationSupportDirectory)();
    final legacyRoot = path.normalize(
      path.absolute(path.join(base.path, 'receipt_images')),
    );
    final ownerRoot = path.normalize(
      path.absolute(path.join(legacyRoot, _ownerScopeValue)),
    );
    final target = path.normalize(path.absolute(reference));
    final token = path.basename(target);
    if (!_imageFilenamePattern.hasMatch(token)) {
      return null;
    }
    final targetParent = path.dirname(target);
    if (targetParent == ownerRoot) {
      return token;
    }
    if (targetParent == legacyRoot) {
      return '$_legacyTokenPrefix$token';
    }
    return null;
  }

  @override
  Future<bool> deleteToken(String token) async {
    final isLegacy = token.startsWith(_legacyTokenPrefix);
    final filename = isLegacy
        ? token.substring(_legacyTokenPrefix.length)
        : token;
    if (!_imageFilenamePattern.hasMatch(filename)) {
      throw ArgumentError('Invalid receipt deletion token.');
    }
    final directory = isLegacy
        ? await _legacyReceiptDirectory()
        : await _receiptDirectory();
    final file = File(path.join(directory.path, filename));
    if (await file.exists()) {
      await file.delete();
      if (await file.exists()) {
        throw FileSystemException(
          'Receipt image deletion could not be verified.',
          file.path,
        );
      }
      return true;
    }
    return false;
  }

  @override
  Future<List<String>> listDeletionTokens() async {
    final directory = await _receiptDirectory();
    if (!await directory.exists()) {
      return const <String>[];
    }
    final tokens = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        throw StateError('Unexpected receipt image directory entry.');
      }
      final token = path.basename(entity.path);
      if (!_imageFilenamePattern.hasMatch(token)) {
        throw StateError('Unexpected receipt image filename.');
      }
      tokens.add(token);
    }
    tokens.sort();
    return List.unmodifiable(tokens);
  }

  @override
  Future<bool> get isEmpty async => (await listDeletionTokens()).isEmpty;

  @override
  Future<void> deleteAll() async {
    final directory = await _receiptDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _receiptDirectory() async {
    _assertValidOwnerScope();
    final legacyDirectory = await _legacyReceiptDirectory();
    return Directory(path.join(legacyDirectory.path, _ownerScopeValue));
  }

  void _assertValidOwnerScope() {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(_ownerScopeValue)) {
      throw StateError('A confirmed opaque owner scope is required.');
    }
  }

  Future<Directory> _legacyReceiptDirectory() async {
    final base = await (_baseDirectory ?? getApplicationSupportDirectory)();
    return Directory(path.join(base.path, 'receipt_images'));
  }
}
