import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewBottomAppBar extends StatelessWidget {
  final String title;
  final InAppWebViewController? webViewController;

  // NEW: Add a callback so the parent can handle the close logic
  final VoidCallback onClose;

  const WebViewBottomAppBar({
    super.key,
    required this.title,
    this.webViewController,
    required this.onClose, // NEW: Require the callback
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose, // NEW: Use the callback instead of Navigator.pop
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (webViewController != null && await webViewController!.canGoBack()) {
                await webViewController!.goBack();
              } else {
                _showSnackBar(messenger, "Can't go back");
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (webViewController != null && await webViewController!.canGoForward()) {
                await webViewController!.goForward();
              } else {
                _showSnackBar(messenger, "No forward history item");
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => webViewController?.reload(),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 200),
        content: Text(
          message,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
