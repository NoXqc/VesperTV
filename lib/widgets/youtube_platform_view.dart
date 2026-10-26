import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/youtube_embed.dart';

typedef YouTubeViewBuilder = Widget Function(
    YouTubeEmbedDocument document,
    void Function(Future<void> Function(String)) onController,
    void Function(Object?) onEvent);

/// Supplies our tiny wrapper locally at a real HTTPS origin on both platforms.
/// Windows loadData ignores baseUrl, so intercept only this exact app-owned URL
/// instead of NavigateToString/about:blank. YouTube requests pass through intact.
class YouTubePlatformView extends StatefulWidget {
  const YouTubePlatformView(
      {super.key,
      required this.document,
      required this.onController,
      required this.onEvent});
  final YouTubeEmbedDocument document;
  final void Function(Future<void> Function(String)) onController;
  final void Function(Object?) onEvent;
  @override
  State<YouTubePlatformView> createState() => _YouTubePlatformViewState();
}

class _YouTubePlatformViewState extends State<YouTubePlatformView> {
  static Future<WebViewEnvironment>? _windowsEnvironment;
  static Future<bool>? _amazon;
  WebViewEnvironment? _environment;
  bool _ready = false;
  bool _hybrid = true;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (Platform.isWindows) {
        if (await WebViewEnvironment.getAvailableVersion() == null) {
          throw StateError('WebView2 unavailable');
        }
        _windowsEnvironment ??= (() async {
          final root = await getApplicationSupportDirectory();
          return WebViewEnvironment.create(
              settings: WebViewEnvironmentSettings(
                  userDataFolder:
                      '${root.path}${Platform.pathSeparator}youtube_webview'));
        })();
        _environment = await _windowsEnvironment;
      }
      if (Platform.isAndroid) {
        // Fire OS's WebView puts <video> on its own native layer. Under hybrid
        // composition that layer sat behind the opaque page (black, audio only);
        // texture composition shows it, but on top of everything: Fire TV plays
        // trailers full screen (Settings > Playback > Trailers says so).
        _amazon ??= Process.run('getprop', ['ro.product.manufacturer']).then(
            (r) => '${r.stdout}'.trim().toLowerCase() == 'amazon',
            onError: (_) => false);
        _hybrid = !await _amazon!;
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _windowsEnvironment = null;
      if (mounted) widget.onEvent({'type': 'error', 'code': -1});
    }
  }

  Future<void> _openLink(InAppWebViewController controller, WebUri? url) async {
    if (url == null ||
        !['https', 'http'].contains(url.scheme) ||
        url.host.isEmpty) {
      return;
    }
    try {
      await controller.evaluateJavascript(
          source: YouTubeEmbedDocument.command('pause'));
      await launchUrl(Uri.parse(url.toString()),
          mode: LaunchMode.externalApplication);
    } catch (_) {/* Do not navigate the embed into another site. */}
  }

  @override
  Widget build(BuildContext context) => !_ready
      ? const SizedBox.shrink()
      : InAppWebView(
          webViewEnvironment: _environment,
          initialUrlRequest:
              URLRequest(url: WebUri(YouTubeEmbedDocument.url.toString())),
          initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              needInitialFocus: false,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldInterceptRequest: true,
              useShouldOverrideUrlLoading: true,
              supportMultipleWindows: true,
              useHybridComposition: _hybrid,
              isInspectable: false),
          onWebViewCreated: (controller) {
            controller.addJavaScriptHandler(
                handlerName: 'YouTubeEvent',
                callback: (args) {
                  if (args.isNotEmpty) widget.onEvent(args.first);
                  return null;
                });
            widget.onController((script) async {
              await controller.evaluateJavascript(source: script);
            });
          },
          shouldInterceptRequest: (_, request) async =>
              request.url.toString() == YouTubeEmbedDocument.url.toString()
                  ? WebResourceResponse(
                      data:
                          Uint8List.fromList(utf8.encode(widget.document.html)),
                      contentType: 'text/html',
                      contentEncoding: 'utf-8',
                      statusCode: 200,
                      reasonPhrase: 'OK',
                      headers: {
                          'Cache-Control': 'no-store',
                          'Referrer-Policy': 'strict-origin-when-cross-origin'
                        })
                  : null,
          onLoadStop: (controller, url) async {
            if (url.toString() == YouTubeEmbedDocument.url.toString()) {
              try {
                await controller.evaluateJavascript(
                    source: 'window.vesperBridgeConnected();');
              } catch (_) {/* Page may be closing. */}
            }
          },
          shouldOverrideUrlLoading: (controller, action) async {
            if (!action.isForMainFrame ||
                action.request.url.toString() ==
                    YouTubeEmbedDocument.url.toString()) {
              return NavigationActionPolicy.ALLOW;
            }
            if (action.hasGesture == true) {
              await _openLink(controller, action.request.url);
            }
            return NavigationActionPolicy.CANCEL;
          },
          onCreateWindow: (controller, action) async {
            if (action.hasGesture == true) {
              await _openLink(controller, action.request.url);
            }
            return false;
          },
          onPermissionRequest: (_, request) async => PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.DENY),
          onReceivedError: (_, request, error) {
            if (request.isForMainFrame == true) {
              widget.onEvent({'type': 'error', 'code': -1});
            }
          },
        );
}
