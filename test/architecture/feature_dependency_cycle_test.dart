import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FeatureCycleScan scan;

  setUpAll(() {
    scan = _scanFeatureCycles(_findRepositoryRoot());
  });

  test('feature dependencies add no cycle edge beyond the exact baseline', () {
    final unexpected = scan.cycleEdges.difference(_knownCycleEdgeBaseline);
    expect(
      unexpected,
      isEmpty,
      reason:
          'New cross-feature cycle edges were found. Depend on a public '
          'contract owned by the lower-level capability instead.\n'
          '${_formatCycleScan(scan, unexpected)}',
    );
  });

  test('the feature-cycle edge baseline contains no stale entries', () {
    final stale = _knownCycleEdgeBaseline.difference(scan.cycleEdges);
    expect(
      stale,
      isEmpty,
      reason:
          'These cycle edges no longer participate in a cycle. Remove them '
          'from the ratchet baseline:\n${(stale.toList()..sort()).join('\n')}',
    );
  });

  test('the remaining cycle component and edge count match the exact debt', () {
    expect(scan.components, _knownCycleComponents);
    expect(scan.cycleEdges, hasLength(_knownCycleEdgeBaseline.length));
  });
}

const List<List<String>> _knownCycleComponents = [
  [
    'accounts',
    'ai_assistant',
    'budgets',
    'dashboard',
    'income_sources',
    'insights',
    'payees',
    'receipts',
    'transactions',
  ],
];

/// Exact feature-level cycle edges remaining after the Goals linked-account
/// composition was corrected: one 9-feature component with 29 directed edges.
/// Never add an entry to make this test green; refactors may only remove them.
const Set<String> _knownCycleEdgeBaseline = {
  'accounts->transactions',
  'ai_assistant->accounts',
  'ai_assistant->budgets',
  'ai_assistant->dashboard',
  'ai_assistant->income_sources',
  'ai_assistant->insights',
  'ai_assistant->payees',
  'ai_assistant->receipts',
  'ai_assistant->transactions',
  'budgets->transactions',
  'dashboard->accounts',
  'dashboard->income_sources',
  'dashboard->transactions',
  'income_sources->accounts',
  'income_sources->payees',
  'income_sources->transactions',
  'insights->budgets',
  'insights->transactions',
  'payees->accounts',
  'payees->transactions',
  'receipts->accounts',
  'receipts->ai_assistant',
  'receipts->income_sources',
  'receipts->payees',
  'receipts->transactions',
  'transactions->accounts',
  'transactions->income_sources',
  'transactions->payees',
  'transactions->receipts',
};

final class _FeatureCycleScan {
  const _FeatureCycleScan({required this.components, required this.cycleEdges});

  final List<List<String>> components;
  final Set<String> cycleEdges;
}

_FeatureCycleScan _scanFeatureCycles(Directory repositoryRoot) {
  final edges = <String>{};
  final nodes = <String>{};
  final lib = Directory('${repositoryRoot.path}/lib');
  final files = lib
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_isGenerated(file.path));

  for (final file in files) {
    final sourcePath = _relativePath(repositoryRoot, file);
    final sourceFeature = _featureForPath(sourcePath);
    if (sourceFeature == null) continue;
    nodes.add(sourceFeature);
    final source = file.readAsStringSync();
    for (final match in _directiveDeclaration.allMatches(source)) {
      final declaration = match.group(2) ?? '';
      final uriMatch = _quotedUri.firstMatch(declaration);
      if (uriMatch == null) continue;
      final targetPath = _resolveTarget(
        repositoryRoot,
        file,
        uriMatch.group(1)!,
      );
      final targetFeature = _featureForPath(targetPath);
      if (targetFeature == null || targetFeature == sourceFeature) continue;
      nodes.add(targetFeature);
      edges.add('$sourceFeature->$targetFeature');
    }
  }

  final adjacency = <String, Set<String>>{
    for (final node in nodes) node: <String>{},
  };
  for (final edge in edges) {
    final parts = edge.split('->');
    adjacency[parts[0]]!.add(parts[1]);
  }
  final components =
      _stronglyConnectedComponents(adjacency)
          .where((component) => component.length > 1)
          .map((component) => component..sort())
          .toList()
        ..sort((left, right) => left.join(',').compareTo(right.join(',')));
  final componentByFeature = <String, int>{};
  for (var index = 0; index < components.length; index++) {
    for (final feature in components[index]) {
      componentByFeature[feature] = index;
    }
  }
  final cycleEdges = edges.where((edge) {
    final parts = edge.split('->');
    final sourceComponent = componentByFeature[parts[0]];
    return sourceComponent != null &&
        sourceComponent == componentByFeature[parts[1]];
  }).toSet();
  return _FeatureCycleScan(components: components, cycleEdges: cycleEdges);
}

List<List<String>> _stronglyConnectedComponents(
  Map<String, Set<String>> adjacency,
) {
  var nextIndex = 0;
  final indices = <String, int>{};
  final lowLinks = <String, int>{};
  final stack = <String>[];
  final onStack = <String>{};
  final result = <List<String>>[];

  void visit(String node) {
    indices[node] = nextIndex;
    lowLinks[node] = nextIndex;
    nextIndex++;
    stack.add(node);
    onStack.add(node);

    for (final target in adjacency[node] ?? const <String>{}) {
      if (!indices.containsKey(target)) {
        visit(target);
        lowLinks[node] = lowLinks[node]!.clamp(0, lowLinks[target]!);
      } else if (onStack.contains(target)) {
        lowLinks[node] = lowLinks[node]!.clamp(0, indices[target]!);
      }
    }
    if (lowLinks[node] != indices[node]) return;

    final component = <String>[];
    while (stack.isNotEmpty) {
      final member = stack.removeLast();
      onStack.remove(member);
      component.add(member);
      if (member == node) break;
    }
    result.add(component);
  }

  for (final node in adjacency.keys) {
    if (!indices.containsKey(node)) visit(node);
  }
  return result;
}

String _formatCycleScan(_FeatureCycleScan scan, Set<String> edges) {
  final sortedEdges = edges.toList()..sort();
  return 'components: ${scan.components.map((value) => value.join(' <-> ')).join('; ')}\n'
      'cycle edges:\n${sortedEdges.join('\n')}';
}

String? _resolveTarget(Directory repositoryRoot, File sourceFile, String uri) {
  const packagePrefix = 'package:cashpilot_ai/';
  if (uri.startsWith(packagePrefix)) {
    return 'lib/${uri.substring(packagePrefix.length)}';
  }
  if (Uri.parse(uri).hasScheme) return null;
  final target = File.fromUri(sourceFile.parent.uri.resolve(uri));
  return _relativePath(repositoryRoot, target);
}

String? _featureForPath(String? path) {
  if (path == null) return null;
  final parts = path.replaceAll('\\', '/').split('/');
  if (parts.length < 3 || parts[0] != 'lib' || parts[1] != 'features') {
    return null;
  }
  return parts[2];
}

bool _isGenerated(String path) {
  final normalized = path.replaceAll('\\', '/');
  final name = normalized.substring(normalized.lastIndexOf('/') + 1);
  return name.endsWith('.g.dart') ||
      name.endsWith('.freezed.dart') ||
      normalized.contains('/lib/l10n/generated/');
}

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path.replaceAll('\\', '/');
  final filePath = file.absolute.path.replaceAll('\\', '/');
  return filePath.substring(rootPath.length + 1);
}

Directory _findRepositoryRoot() {
  var candidate = Directory.current.absolute;
  while (true) {
    if (File('${candidate.path}/pubspec.yaml').existsSync() &&
        Directory('${candidate.path}/lib').existsSync()) {
      return candidate;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError('Could not locate the repository root.');
    }
    candidate = parent;
  }
}

final RegExp _directiveDeclaration = RegExp(
  r'''^\s*(import|export)\s+([^;]+);''',
  multiLine: true,
);
final RegExp _quotedUri = RegExp(r'''[\"']([^\"']+)[\"']''');
