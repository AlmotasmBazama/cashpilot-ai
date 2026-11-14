import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  WebViewController? _controller;

  bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    if (!_isSupported ||
        widget.renderedContent.isEmpty ||
        widget.renderedContent.length > 100000) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                !<String>{'https', 'http'}.contains(uri.scheme)) {
              return NavigationDecision.navigate;
            }
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(widget.renderedContent);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Text(
        widget.unavailableLabel,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return SizedBox(
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
