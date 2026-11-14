import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../../../core/storage/settings_keys.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';

class InMemoryAiAgentMemoryStore implements AiAgentMemoryStore {
  AiAgentSessionMemory _memory = const AiAgentSessionMemory();

  @override
  Future<AiAgentSessionMemory> read({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    return _memory;
  }

  @override
  Future<void> save(
    AiAgentSessionMemory memory, {
    AiAgentMemoryAccess? access,
  }) async {
    access?.assertActive();
    _memory = memory;
  }

  @override
  Future<void> clear({AiAgentMemoryAccess? access}) async {
    access?.assertActive();
    _memory = const AiAgentSessionMemory();
  }
}

class HiveAiAgentMemoryStore implements AiAgentMemoryStore {
  const HiveAiAgentMemoryStore({
    required Box<dynamic> settingsBox,
    required bool persistenceEnabled,
    required String accountScope,
  }) : _settingsBox = settingsBox,
       _persistenceEnabled = persistenceEnabled,
       _accountScope = accountScope;

  final Box<dynamic> _settingsBox;
  final bool _persistenceEnabled;
  final String _accountScope;

  @override
  Future<AiAgentSessionMemory> read({AiAgentMemoryAccess? access}) async {
    _assertAccess(access);
    if (!_persistenceEnabled) {
      return const AiAgentSessionMemory();
    }
    final value = _settingsBox.get(
      SettingsKeys.aiAgentMemoryForScopeHash(_accountScope),
    );
    if (value is! String || value.length > 16000) {
      return const AiAgentSessionMemory();
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map ||
          decoded['accountScope'] != _accountScope ||
          !decoded.containsKey('memory')) {
        return const AiAgentSessionMemory();
      }
      final memory = AiAgentSessionMemory.fromSafeJson(decoded['memory']);
      _assertAccess(access);
      return memory;
    } on Object {
      _assertAccess(access);
      return const AiAgentSessionMemory();
    }
  }

  @override
  Future<void> save(
    AiAgentSessionMemory memory, {
    AiAgentMemoryAccess? access,
  }) async {
    _assertAccess(access);
    if (!_persistenceEnabled) {
      return;
    }
    final encoded = jsonEncode(<String, Object?>{
      'accountScope': _accountScope,
      'memory': memory.toSafeJson(),
    });
    _assertAccess(access);
    await _settingsBox.put(
      SettingsKeys.aiAgentMemoryForScopeHash(_accountScope),
      encoded,
    );
    _assertAccess(access);
  }

  @override
  Future<void> clear({AiAgentMemoryAccess? access}) async {
    _assertAccess(access);
    await _settingsBox.delete(
      SettingsKeys.aiAgentMemoryForScopeHash(_accountScope),
    );
    _assertAccess(access);
  }

  void _assertAccess(AiAgentMemoryAccess? access) {
    final binding = access?.ownerScope;
    if (binding != null &&
        OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
              binding.accountScope,
            ).assistantScopeHash !=
            _accountScope) {
      throw const AiAgentMemoryOwnerBindingChangedException();
    }
    access?.assertActive();
  }
}

/// A writer lease captured for one AI memory operation. It combines the
/// immutable owner/session binding with the shared deletion quarantine fence.
final class AiAgentMemoryOwnerLease {
  AiAgentMemoryOwnerLease._({
    required this.binding,
    required AiToolOwnerScopeReader? currentOwnerScope,
    required BackupWriterLease? writer,
  }) : _currentOwnerScope = currentOwnerScope,
       _writer = writer {
    access = AiAgentMemoryAccess(
      ownerScope: binding,
      assertActive: assertActive,
    );
  }

  static AiAgentMemoryOwnerLease? tryAcquire({
    required AiToolOwnerScopeBinding? binding,
    required AiToolOwnerScopeReader? currentOwnerScope,
    required BackupOperationFence? operationFence,
  }) {
    if (binding == null) {
      return AiAgentMemoryOwnerLease._(
        binding: null,
        currentOwnerScope: null,
        writer: null,
      );
    }

    if (currentOwnerScope == null || operationFence == null) {
      return null;
    }
    if (currentOwnerScope() != binding) {
      return null;
    }
    final writer = operationFence.tryAcquireWriter(binding.accountScope);
    if (writer == null) {
      return null;
    }
    final result = AiAgentMemoryOwnerLease._(
      binding: binding,
      currentOwnerScope: currentOwnerScope,
      writer: writer,
    );
    try {
      result.assertActive();
      return result;
    } on Object {
      writer.release();
      return null;
    }
  }

  final AiToolOwnerScopeBinding? binding;
  final AiToolOwnerScopeReader? _currentOwnerScope;
  final BackupWriterLease? _writer;
  late final AiAgentMemoryAccess access;
  bool _released = false;

  void assertActive() {
    if (_released) {
      throw const AiAgentMemoryOwnerBindingChangedException();
    }
    _writer?.assertActive();
    final current = _currentOwnerScope;
    if (current != null && current() != binding) {
      throw const AiAgentMemoryOwnerBindingChangedException();
    }
  }

  void release() {
    if (_released) return;
    _released = true;
    _writer?.release();
  }
}

final class AiAgentMemoryOwnerBindingChangedException implements Exception {
  const AiAgentMemoryOwnerBindingChangedException();

  @override
  String toString() => 'AI memory owner/session binding changed.';
}

class DefaultAiAgentMemoryCompactor implements AiAgentMemoryCompactor {
  const DefaultAiAgentMemoryCompactor({
    this.maxTurns = 8,
    this.maxMessageCharacters = 1000,
  });

  final int maxTurns;
  final int maxMessageCharacters;

  @override
  AiAgentSessionMemory append(
    AiAgentSessionMemory memory,
    AiAgentMessage message,
  ) {
    final safeMessage = AiAgentMessage(
      role: message.role,
      content: _sanitize(message.content),
      createdAt: message.createdAt.toUtc(),
    );
    final messages = <AiAgentMessage>[...memory.messages, safeMessage];
    var summary = memory.compactedSummary;
    if (messages.length > maxTurns) {
      final removed = messages.removeRangeAndReturn(
        0,
        messages.length - maxTurns,
      );
      final compacted = removed
          .map(
            (item) =>
                '${item.role == AiAgentMessageRole.user ? 'User' : 'Assistant'}: ${item.content}',
          )
          .join(' | ');
      summary = _bounded(<String>[?summary, compacted].join(' | '), 1800);
    }
    return memory.copyWith(
      messages: messages,
      compactedSummary: summary,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  String _sanitize(String value) {
    final withoutControl = value.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
      ' ',
    );
    return _bounded(withoutControl.trim(), maxMessageCharacters);
  }

  String _bounded(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';
}

extension<T> on List<T> {
  List<T> removeRangeAndReturn(int start, int end) {
    final removed = sublist(start, end);
    removeRange(start, end);
    return removed;
  }
}
