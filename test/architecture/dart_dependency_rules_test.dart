import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<_ArchitectureViolation> violations;

  setUpAll(() {
    final repositoryRoot = _findRepositoryRoot();
    violations = _DartArchitectureScanner(repositoryRoot).scan();
  });

  test('handwritten Dart dependencies add no violations beyond the exact '
      'strict baseline', () {
    final unexpected = violations
        .where(
          (violation) => !_knownStrictArchitectureViolationBaseline.contains(
            violation.edgeKey,
          ),
        )
        .toList();

    expect(
      unexpected,
      isEmpty,
      reason:
          'New architecture violations were found. Do not expand the '
          'baseline; route dependencies through a stable contract instead.'
          '${_formatViolations(unexpected)}',
    );
  });

  test('the strict violation baseline contains no stale entries', () {
    final detectedEdges = violations
        .map((violation) => violation.edgeKey)
        .toSet();
    final stale =
        _knownStrictArchitectureViolationBaseline
            .difference(detectedEdges)
            .toList()
          ..sort();

    expect(
      stale,
      isEmpty,
      reason:
          'These known violations no longer exist. Remove their entries so '
          'the baseline can only ratchet downward:\n${stale.join('\n')}',
    );
  });
}

/// The initial audit on 2026-08-17 found 44 strict dependency edges.
///
/// This set contains only the remaining known debt and is reduced after each
/// independently verified refactor batch.
///
/// This is deliberately an edge allowlist, not a count. A moved or replaced
/// violation therefore fails the first test, while a fixed violation fails the
/// stale-entry test until its entry is removed. Never add a new edge here to
/// make the guard green.
const Set<String> _knownStrictArchitectureViolationBaseline = {};

final class _DartArchitectureScanner {
  _DartArchitectureScanner(this.repositoryRoot);

  final Directory repositoryRoot;

  List<_ArchitectureViolation> scan() {
    final byEdge = <String, _ArchitectureViolation>{};
    final libDirectory = Directory('${repositoryRoot.path}/lib');
    final files =
        libDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) => !_isGeneratedSource(_relativePath(file)))
            .where((file) => !_isExcludedCompositionRoot(_relativePath(file)))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    for (final file in files) {
      final sourcePath = _relativePath(file);
      final sourceLocation = _LayerLocation.parse(sourcePath);
      final source = file.readAsStringSync();

      for (final directive in _directives(source)) {
        final targetPath = _resolveProjectTarget(file, directive.uri);
        final targetLocation = targetPath == null
            ? const _LayerLocation()
            : _LayerLocation.parse(targetPath);

        if (sourceLocation.layer == 'domain') {
          if (_isForbiddenDomainPackage(directive.uri) ||
              _isForbiddenDomainProjectTarget(targetPath, targetLocation)) {
            _register(
              byEdge,
              sourcePath: sourcePath,
              directive: directive,
              rule: _ArchitectureRule.domainPurity,
            );
          }
        }

        if (sourceLocation.layer == 'presentation') {
          if (_isForbiddenPresentationPackage(directive.uri) ||
              targetLocation.layer == 'data' ||
              _isFirebaseProviderImplementation(targetPath)) {
            _register(
              byEdge,
              sourcePath: sourcePath,
              directive: directive,
              rule: _ArchitectureRule.presentationInfrastructure,
            );
          }
        }

        if (sourceLocation.layer == 'data' &&
            (targetLocation.layer == 'presentation' ||
                (targetLocation.layer == 'application' &&
                    sourceLocation.feature != targetLocation.feature))) {
          _register(
            byEdge,
            sourcePath: sourcePath,
            directive: directive,
            rule: _ArchitectureRule.dataReverseDependency,
          );
        }

        // Compatibility-only exports remain visible to the scanner, but they
        // are not runtime consumption from one feature's private layer by
        // another. Layer-direction checks above still apply to exports.
        if (directive.kind == 'import' &&
            sourceLocation.feature != null &&
            targetLocation.feature != null &&
            sourceLocation.feature != targetLocation.feature) {
          if (targetLocation.layer == 'data') {
            _register(
              byEdge,
              sourcePath: sourcePath,
              directive: directive,
              rule: _ArchitectureRule.crossFeaturePrivateData,
            );
          }
          if (targetLocation.layer == 'presentation') {
            _register(
              byEdge,
              sourcePath: sourcePath,
              directive: directive,
              rule: _ArchitectureRule.crossFeaturePrivatePresentation,
            );
          }
        }
      }

      if (sourceLocation.layer == 'presentation') {
        for (final match in _repositoryImplementationConstruction.allMatches(
          source,
        )) {
          final expression = match.group(1)!;
          _register(
            byEdge,
            sourcePath: sourcePath,
            directive: _DartDirective(
              kind: 'instantiation',
              uri: '$expression(...)',
              line: _lineNumber(source, match.start),
            ),
            rule: _ArchitectureRule.presentationRepositoryConstruction,
          );
        }
      }
    }

    return byEdge.values.toList()
      ..sort((left, right) => left.edgeKey.compareTo(right.edgeKey));
  }

  void _register(
    Map<String, _ArchitectureViolation> byEdge, {
    required String sourcePath,
    required _DartDirective directive,
    required _ArchitectureRule rule,
  }) {
    final edgeKey = '$sourcePath|${directive.kind}|${directive.uri}';
    final existing = byEdge[edgeKey];
    if (existing == null) {
      byEdge[edgeKey] = _ArchitectureViolation(
        sourcePath: sourcePath,
        directive: directive,
        rules: {rule},
      );
      return;
    }
    existing.rules.add(rule);
  }

  String _relativePath(File file) {
    final rootPath = _normalizePath(repositoryRoot.absolute.path);
    final filePath = _normalizePath(file.absolute.path);
    final rootPrefix = '$rootPath/';
    if (!filePath.toLowerCase().startsWith(rootPrefix.toLowerCase())) {
      throw StateError('$filePath is outside $rootPath.');
    }
    return filePath.substring(rootPrefix.length);
  }

  String? _resolveProjectTarget(File sourceFile, String uri) {
    const packagePrefix = 'package:cashpilot_ai/';
    if (uri.startsWith(packagePrefix)) {
      return 'lib/${uri.substring(packagePrefix.length)}';
    }
    if (Uri.parse(uri).hasScheme) return null;

    final target = File.fromUri(sourceFile.parent.uri.resolve(uri));
    final rootPath = _normalizePath(repositoryRoot.absolute.path);
    final targetPath = _normalizePath(target.absolute.path);
    final rootPrefix = '$rootPath/';
    if (!targetPath.toLowerCase().startsWith(rootPrefix.toLowerCase())) {
      return null;
    }
    return targetPath.substring(rootPrefix.length);
  }
}

final class _ArchitectureViolation {
  _ArchitectureViolation({
    required this.sourcePath,
    required this.directive,
    required this.rules,
  });

  final String sourcePath;
  final _DartDirective directive;
  final Set<_ArchitectureRule> rules;

  String get edgeKey => '$sourcePath|${directive.kind}|${directive.uri}';
}

final class _DartDirective {
  const _DartDirective({
    required this.kind,
    required this.uri,
    required this.line,
  });

  final String kind;
  final String uri;
  final int line;
}

final class _LayerLocation {
  const _LayerLocation({this.feature, this.layer});

  factory _LayerLocation.parse(String path) {
    final segments = _normalizePath(path).split('/');
    if (segments.length < 4 ||
        segments[0] != 'lib' ||
        segments[1] != 'features') {
      return const _LayerLocation();
    }
    final candidateLayer = segments[3];
    return _LayerLocation(
      feature: segments[2],
      layer:
          const {
            'domain',
            'application',
            'data',
            'presentation',
          }.contains(candidateLayer)
          ? candidateLayer
          : null,
    );
  }

  final String? feature;
  final String? layer;
}

enum _ArchitectureRule {
  domainPurity(
    description:
        'Domain code cannot depend on Flutter, Riverpod, Drift, Firebase, '
        'Hive, go_router, image_picker, HTTP, localization, application, '
        'presentation, or data implementations.',
    expectedDirection: 'presentation/application/data -> domain',
    suggestedLayer:
        'Move framework adaptation to application or data and expose a pure '
        'domain value or contract.',
  ),
  presentationInfrastructure(
    description:
        'Presentation cannot import data implementations or Firebase, Drift, '
        'or Hive infrastructure.',
    expectedDirection:
        'presentation -> application controller/provider -> domain contract '
        '<- data implementation',
    suggestedLayer:
        'Inject an application-facing provider or controller backed by a data '
        'adapter.',
  ),
  presentationRepositoryConstruction(
    description:
        'Presentation cannot instantiate a class ending in RepositoryImpl.',
    expectedDirection:
        'presentation -> application provider -> repository contract <- '
        'repository implementation',
    suggestedLayer:
        'Construct the repository implementation in application composition '
        'and expose only its contract.',
  ),
  dataReverseDependency(
    description: 'Data code cannot depend on presentation or application UI.',
    expectedDirection: 'presentation -> application -> domain <- data',
    suggestedLayer:
        'Move the shared contract to domain, or compose the dependency in the '
        'application layer.',
  ),
  crossFeaturePrivateData(
    description:
        "Feature code cannot import another feature's private data layer.",
    expectedDirection:
        'feature -> other feature public domain/application contract',
    suggestedLayer:
        'Expose a narrow public domain contract or application service from '
        'the owning feature.',
  ),
  crossFeaturePrivatePresentation(
    description:
        "Feature code cannot import another feature's private presentation "
        'layer.',
    expectedDirection:
        'app-shell composition -> feature presentation, or feature -> shared '
        'presentation',
    suggestedLayer:
        'Compose the widgets in app-shell, expose an intentional public '
        'feature facade, or move genuinely shared UI to shared/presentation.',
  );

  const _ArchitectureRule({
    required this.description,
    required this.expectedDirection,
    required this.suggestedLayer,
  });

  final String description;
  final String expectedDirection;
  final String suggestedLayer;
}

Iterable<_DartDirective> _directives(String source) sync* {
  for (final match in _directiveDeclaration.allMatches(source)) {
    final kind = match.group(1)!;
    final body = match.group(2)!;
    final bodyOffset = source.indexOf(body, match.start);
    for (final uriMatch in _quotedUri.allMatches(body)) {
      yield _DartDirective(
        kind: kind,
        uri: uriMatch.group(1)!,
        line: _lineNumber(source, bodyOffset + uriMatch.start),
      );
    }
  }
}

bool _isGeneratedSource(String path) {
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return true;
  return RegExp(
    r'^lib/l10n/app_localizations(?:_[a-z]+)?\.dart$',
  ).hasMatch(path);
}

bool _isExcludedCompositionRoot(String path) {
  return path == 'lib/core/database/app_database.dart' ||
      path == 'lib/app/router/app_router.dart';
}

bool _isForbiddenDomainPackage(String uri) {
  final packageName = _packageName(uri);
  if (packageName == null) return false;
  return packageName == 'flutter' ||
      packageName == 'flutter_riverpod' ||
      packageName == 'riverpod' ||
      packageName == 'riverpod_annotation' ||
      packageName == 'hooks_riverpod' ||
      packageName == 'drift' ||
      packageName == 'drift_flutter' ||
      packageName.startsWith('firebase_') ||
      packageName == 'hive' ||
      packageName == 'hive_flutter' ||
      packageName == 'go_router' ||
      packageName == 'image_picker' ||
      packageName == 'http';
}

bool _isForbiddenDomainProjectTarget(
  String? targetPath,
  _LayerLocation targetLocation,
) {
  if (targetPath == null) return false;
  return const {
        'application',
        'data',
        'presentation',
      }.contains(targetLocation.layer) ||
      targetPath.startsWith('lib/core/firebase/') ||
      targetPath == 'lib/l10n/app_localizations.dart';
}

bool _isForbiddenPresentationPackage(String uri) {
  final packageName = _packageName(uri);
  if (packageName == null) return false;
  return packageName == 'drift' ||
      packageName == 'drift_flutter' ||
      packageName.startsWith('firebase_') ||
      packageName == 'hive' ||
      packageName == 'hive_flutter';
}

bool _isFirebaseProviderImplementation(String? targetPath) {
  return targetPath != null &&
      targetPath.startsWith('lib/core/firebase/') &&
      targetPath.endsWith('_providers.dart');
}

String? _packageName(String uri) {
  const prefix = 'package:';
  if (!uri.startsWith(prefix)) return null;
  final slash = uri.indexOf('/', prefix.length);
  return slash == -1
      ? uri.substring(prefix.length)
      : uri.substring(prefix.length, slash);
}

int _lineNumber(String source, int offset) {
  var line = 1;
  for (var index = 0; index < offset; index++) {
    if (source.codeUnitAt(index) == 10) line++;
  }
  return line;
}

String _formatViolations(List<_ArchitectureViolation> violations) {
  if (violations.isEmpty) return '';
  final buffer = StringBuffer('\n');
  for (final violation in violations) {
    final rules = violation.rules.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    buffer
      ..writeln('- source: ${violation.sourcePath}:${violation.directive.line}')
      ..writeln(
        '  forbidden ${violation.directive.kind}: '
        "'${violation.directive.uri}'",
      )
      ..writeln('  rule: ${rules.map((rule) => rule.description).join(' ')}')
      ..writeln(
        '  expected direction: '
        '${rules.map((rule) => rule.expectedDirection).toSet().join('; ')}',
      )
      ..writeln(
        '  suggested layer: '
        '${rules.map((rule) => rule.suggestedLayer).toSet().join(' ')}',
      );
  }
  return buffer.toString();
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

String _normalizePath(String path) => path.replaceAll('\\', '/');

final RegExp _directiveDeclaration = RegExp(
  r'''^\s*(import|export)\s+([^;]+);''',
  multiLine: true,
);
final RegExp _quotedUri = RegExp(r'''[\"']([^\"']+)[\"']''');
final RegExp _repositoryImplementationConstruction = RegExp(
  r'\b([A-Z][A-Za-z0-9_]*RepositoryImpl)(?:<[^>{};()]+>)?\s*\(',
);
