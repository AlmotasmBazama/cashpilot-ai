import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class GoogleSearchEntryPoint extends StatefulWidget {
  const GoogleSearchEntryPoint({
    required this.renderedContent,
    required this.unavailableLabel,
    super.key,
  });

  final String renderedContent;
  final String unavailableLabel;

  @override
  State<GoogleSearchEntryPoint> createState() => _GoogleSearchEntryPointState();
}

class _GoogleSearchEntryPointState extends State<GoogleSearchEntryPoint> {
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'cashpilot-google-search-entry-${identityHashCode(this).toRadixString(16)}';
    final content = widget.renderedContent;
    if (content.isEmpty || content.length > 100000) {
      return;
    }
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final frame = web.HTMLIFrameElement()
        ..srcdoc = content.toJS
        ..setAttribute(
          'sandbox',
          'allow-scripts allow-popups allow-popups-to-escape-sandbox allow-forms',
        )
        ..setAttribute('title', 'Google Search')
        ..style.width = '100%'
        ..style.height = '72px'
        ..style.border = '0';
      return frame;
    });
    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return Text(
        widget.unavailableLabel,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return SizedBox(height: 72, child: HtmlElementView(viewType: _viewType));
  }
}
