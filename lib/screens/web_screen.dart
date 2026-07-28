import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/palette.dart';

/// Fullscreen in-app web view for Privacy Policy / Support pages.
class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Pal.ash,
        foregroundColor: Pal.bone,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Pal.bone),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title,
            style: Pal.label(15, color: Pal.bone)),
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Pal.basalt,
                  color: Pal.ember,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
