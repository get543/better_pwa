import 'dart:io';
import 'dart:async';

// NEW: Import services to control System UI (Status/Nav bars)
import 'package:flutter/services.dart';

import 'package:better_pwa/constants/app_constants.dart';
import 'package:better_pwa/models/webview_settings.dart';
import 'package:better_pwa/widgets/webview_bottom_appbar.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CommonWebView extends StatefulWidget {
  final String url;
  final String title;

  const CommonWebView({super.key, required this.url, required this.title});

  @override
  State<CommonWebView> createState() => _CommonWebViewState();
}

class _CommonWebViewState extends State<CommonWebView> {
  InAppWebViewSettings? _webViewSettings;
  InAppWebViewController? _webViewController;

  double _progress = 0;
  double _lastScrollY = 0.0;
  bool _isAppBarVisible = true;
  Timer? _hideTimer;
  bool _isTouching = false;

  // NEW: State variable to track if we allow the system to pop the screen
  bool _canPop = false;

  @override
  void initState() {
    super.initState();

    // NEW: Hide system status bar and bottom navigation bar (Immersive Mode)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadSettings();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();

    // NEW: Restore system status bar and bottom navigation bar when going back to home.dart
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await WebviewSettingsHelper.getDefaultSettings();
    if (mounted) {
      setState(() {
        _webViewSettings = settings;
      });
    }
  }

  //! --- HELPER TO CHECK PERMISSIONS ---
  Future<bool> _checkPermission() async {
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (notifStatus != PermissionStatus.granted) {
        await Permission.notification.request();
      }

      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) return true;

      final storageStatus = await Permission.storage.status;
      if (storageStatus != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        return result == PermissionStatus.granted;
      }
      return true;
    }
    return false;
  }

  //! --- HELPER TO PERFORM DOWNLOAD ---
  void _downloadFile(DownloadStartRequest request) async {
    bool hasPermission = await _checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied. Cannot download.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${request.suggestedFilename ?? "file"}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: request.url);
    final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');

    final Map<String, String> headers = {};
    if (cookieString.isNotEmpty) headers['Cookie'] = cookieString;
    if (request.userAgent != null) headers['User-Agent'] = request.userAgent!;
    headers['Referer'] = request.url.toString();
    headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8';

    Directory? externalDir = await getExternalStorageDirectory();
    String fileName = request.suggestedFilename ?? "downloaded_file_${DateTime.now().millisecondsSinceEpoch}";

    await FlutterDownloader.enqueue(
      url: request.url.toString(),
      savedDir: externalDir!.path,
      fileName: fileName,
      headers: headers,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
      allowCellular: true,
    );
  }

  //! --- Build Scaffold Widgets ---
  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();

    // NEW: Wrap the entire screen output in a PopScope to handle the system back swipe
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // If the system already popped it, do nothing

        // Check if the WebView can go back
        if (_webViewController != null && await _webViewController!.canGoBack()) {
          // Go back in the website's history
          await _webViewController!.goBack();
        } else {
          // If we can't go back anymore, allow the screen to pop back to home.dart
          setState(() => _canPop = true);
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: _webViewSettings == null
          ? _buildLoadingScaffold(backgroundColor)
          : Scaffold(
              backgroundColor: backgroundColor,
              extendBody: true,
              body: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _handlePointerDown(),
                onPointerUp: (_) => _handlePointerUp(),
                onPointerCancel: (_) => _handlePointerUp(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildWebViewStack(),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        top: false,
                        left: false,
                        right: false,
                        child: _buildAnimatedAppBar(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  //! ===========================================================
  //! TIMER & INTERACTION LOGIC
  //! ===========================================================

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(AppConstants.hideDuration, () {
      if (_isAppBarVisible && mounted && !_isTouching) {
        setState(() => _isAppBarVisible = false);
      }
    });
  }

  void _handlePointerDown() {
    _isTouching = true;
    _hideTimer?.cancel();
  }

  void _handlePointerUp() {
    _isTouching = false;
    if (_isAppBarVisible) {
      _startHideTimer();
    }
  }

  void _handleScrollLogic(int y) {
    if (y <= 0) {
      if (!_isAppBarVisible) setState(() => _isAppBarVisible = true);
      if (!_isTouching) _startHideTimer();
      _lastScrollY = 0;
      return;
    }

    final double scrollDelta = y - _lastScrollY;

    if (scrollDelta > 15 && y > 50) {
      if (_isAppBarVisible) setState(() => _isAppBarVisible = false);
      _hideTimer?.cancel();
      _lastScrollY = y.toDouble();
    } else if (scrollDelta < -15) {
      if (!_isAppBarVisible) setState(() => _isAppBarVisible = true);
      if (!_isTouching) _startHideTimer();
      _lastScrollY = y.toDouble();
    }
  }

  //! ===========================================================
  //! UI WIDGET BUILDERS (Tightly coupled to WebView State)
  //! ===========================================================

  Color _getBackgroundColor() {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? Colors.black : Colors.white;
  }

  Widget _buildLoadingScaffold(Color backgroundColor) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: WebViewBottomAppBar(
                title: widget.title,
                // NEW: Handle the force-close from the "X" button
                onClose: () {
                  setState(() => _canPop = true);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _isAppBarVisible
          ? WebViewBottomAppBar(
              title: widget.title,
              webViewController: _webViewController,
              // NEW: Handle the force-close from the "X" button
              onClose: () {
                setState(() => _canPop = true);
                Navigator.pop(context);
              },
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildWebViewStack() {
    return Stack(
      children: [
        _buildInAppWebView(),
        if (_progress < 1.0)
          LinearProgressIndicator(
            value: _progress,
            color: AppConstants.accentColor,
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }

  Widget _buildInAppWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
      initialSettings: _webViewSettings,
      onWebViewCreated: (controller) => _webViewController = controller,
      onProgressChanged: (controller, progress) => setState(() => _progress = progress / 100),
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        debugPrint("SSL Error detected for: ${challenge.protectionSpace.host}");
        return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
      },
      onDownloadStartRequest: (controller, request) => _downloadFile(request),
      onScrollChanged: (controller, x, y) {
        _handleScrollLogic(y);
        _lastScrollY = y.toDouble();
      },
    );
  }
}
