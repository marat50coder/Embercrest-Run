import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'permit.dart';
import 'quiet.dart';
import '../hold/chest.dart';
import '../net/face.dart';
import '../net/pipe.dart';
import '../net/probe.dart';

/// Full-screen in-app browser. WebView stays; only the host scripts changed.
class SheetHost extends StatefulWidget {
  const SheetHost({
    super.key,
    required this.url,
    required this.locker,
    required this.pulse,
    required this.ping,
    required this.mask,
    this.coldLaunch = false,
  });

  final String url;
  final AshChest locker;
  final ReachProbe pulse;
  final AlertPipe ping;
  final AgentFace mask;
  final bool coldLaunch;

  @override
  State<SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<SheetHost> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;
  bool _offeringNotice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.mask.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.ping.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.pulse.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    await Future<void>.delayed(const Duration(milliseconds: 340));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(const [55, 190, 380, 610, 920]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(_reflowScript).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      _paintHostScripts();
    });
  }

  static const String _reflowScript = r'''
(function(){
  var w = window;
  var ev = function(name, target){
    var e = document.createEvent('Event');
    e.initEvent(name, true, true);
    (target || w).dispatchEvent(e);
  };
  ev('orientationchange');
  ev('resize');
  if (w.visualViewport) ev('resize', w.visualViewport);
})();
''';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
      _maybeOfferNotice();
    }
  }

  Future<void> _maybeOfferNotice() async {
    if (!mounted || _offlineShown || _offeringNotice) return;
    if (!widget.locker.shouldOfferNotice) return;
    bool canOffer = false;
    try {
      canOffer = await widget.ping.canOfferPermission();
    } catch (_) {
      return;
    }
    if (!canOffer || !mounted || _offeringNotice) return;
    _offeringNotice = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) {
      _offeringNotice = false;
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PermitCard(
          locker: widget.locker,
          ping: widget.ping,
          nextBuilder: (_) => SheetHost(
            url: current,
            locker: widget.locker,
            pulse: widget.pulse,
            ping: widget.ping,
            mask: widget.mask,
          ),
        ),
      ),
    );
  }

  Future<void> _consumePending() async {
    final value = await widget.locker.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _paintHostScripts();
        Future<void>.delayed(const Duration(milliseconds: 920), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(_reflowScript);
          _paintHostScripts();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return;
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 3) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (<String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.pulse.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuietLink(
          pulse: widget.pulse,
          retryBuilder: (_) => SheetHost(
            url: current,
            locker: widget.locker,
            pulse: widget.pulse,
            ping: widget.ping,
            mask: widget.mask,
          ),
        ),
      ),
    );
  }

  void _paintHostScripts() {
    _controller.runJavaScript(_hostBundle);
    if (Platform.isIOS) {
      _controller.runJavaScript(_iosTypeSize);
    }
  }

  static const String _hostBundle = r'''
(function(scope){
  var root = document.documentElement;
  if (root.getAttribute('data-cv-paint') === '1') return;
  root.setAttribute('data-cv-paint', '1');

  var KEYBOARD_RATIO = 0.68;
  var REFRESH_A = 210;
  var REFRESH_B = 780;
  var LOOP_MS = 3400;
  var STYLE_ID = 'cv-pad-sheet';
  var GHOST_ID = 'cv-ghost-tap';

  function keyboardOpen(){
    var vis = scope.visualViewport;
    return !!vis && vis.height < scope.innerHeight * KEYBOARD_RATIO;
  }

  function ensureMeta(fit){
    var host = document.head || document.documentElement;
    if (!host) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      host.appendChild(meta);
    }
    var raw = (meta.getAttribute('content') || '').replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
    meta.setAttribute('content',
      (raw ? raw + ', ' : '') +
      'width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=no, viewport-fit=' + fit
    );
  }

  function paintPad(){
    if (keyboardOpen()) return;
    var host = document.head || document.documentElement;
    if (!host) return;
    ensureMeta('contain');
    var sheet = document.getElementById(STYLE_ID);
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = STYLE_ID;
      host.appendChild(sheet);
    }
    sheet.textContent = [
      ':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;',
      '--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;',
      '--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;',
      '--safe-top:0px!important;--safe-right:0px!important;--safe-bottom:0px!important;--safe-left:0px!important;}',
      'html,body{overscroll-behavior:none!important;overscroll-behavior-y:none!important;}'
    ].join('');
  }

  function paintGhost(){
    var host = document.head || document.documentElement;
    if (!host || document.getElementById(GHOST_ID)) return;
    var style = document.createElement('style');
    style.id = GHOST_ID;
    style.textContent =
      '*{-webkit-tap-highlight-color:transparent!important;}' +
      '*:not(input):not(textarea):not([contenteditable="true"]){-webkit-touch-callout:none!important;}';
    host.appendChild(style);
  }

  function bindHistory(fn){
    ['pushState','replaceState'].forEach(function(name){
      var orig = history[name];
      history[name] = function(){
        var result = orig.apply(this, arguments);
        fn();
        return result;
      };
    });
    scope.addEventListener('popstate', fn);
  }

  function schedulePad(){
    scope.setTimeout(paintPad, REFRESH_A);
    scope.setTimeout(paintPad, REFRESH_B);
  }

  var halt = function(e){ e.preventDefault(); };
  ['gesturestart','gesturechange','gestureend'].forEach(function(t){
    document.addEventListener(t, halt, {passive:false});
  });
  document.addEventListener('touchmove', function(e){
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive:false});
  var lastTap = 0;
  document.addEventListener('touchend', function(e){
    var now = Date.now();
    if (now - lastTap <= 280) e.preventDefault();
    lastTap = now;
  }, {passive:false});

  function isField(node){
    return !!node && node.matches && node.matches('input, textarea, select, [contenteditable="true"]');
  }
  document.addEventListener('focusin', function(event){
    if (!isField(event.target)) return;
    scope.setTimeout(function(){
      var active = document.activeElement;
      if (isField(active) && active.scrollIntoView) {
        active.scrollIntoView({behavior:'auto', block:'nearest'});
      }
    }, 380);
  }, true);

  function awaken(video){
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline','');
    video.setAttribute('webkit-playsinline','');
    video.playsInline = true;
    video.autoplay = true;
    var play = video.play();
    if (play && play.catch) play.catch(function(){});
  }
  function scan(node){
    if (node instanceof HTMLVideoElement) awaken(node);
    if (node.querySelectorAll) node.querySelectorAll('video').forEach(awaken);
  }
  scan(document);
  new MutationObserver(function(records){
    records.forEach(function(record){
      record.addedNodes.forEach(scan);
    });
  }).observe(document.documentElement, {childList:true, subtree:true});

  paintPad();
  paintGhost();
  bindHistory(schedulePad);
  bindHistory(function(){ scope.setTimeout(function(){ ensureMeta('contain'); }, 160); });
  scope.setInterval(paintPad, LOOP_MS);
})(window);
''';

  static const String _iosTypeSize = r'''
(function(scope){
  var root = document.documentElement;
  if (root.getAttribute('data-cv-type') === '1') return;
  root.setAttribute('data-cv-type', '1');
  var style = document.createElement('style');
  style.setAttribute('data-cv','type');
  style.textContent = 'input,textarea,select,[contenteditable="true"]{font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(style);
})(window);
''';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.ping.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
