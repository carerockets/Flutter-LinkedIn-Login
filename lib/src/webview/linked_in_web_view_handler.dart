import 'package:flutter/material.dart';
import 'package:linkedin_login/src/utils/configuration.dart';
import 'package:linkedin_login/src/utils/logger.dart';
import 'package:linkedin_login/src/utils/startup/graph.dart';
import 'package:linkedin_login/src/utils/startup/injector.dart';
import 'package:linkedin_login/src/webview/actions.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Class will fetch code and access token from the user
/// It will show web view so that we can access to linked in auth page
/// Please take into consideration to use [onWebViewCreated] only in testing
/// purposes
@immutable
class LinkedInWebViewHandler extends StatefulWidget {
  const LinkedInWebViewHandler({
    required this.onUrlMatch,
    this.appBar,
    this.destroySession = false,
    this.onCookieClear,
    this.onWebViewCreated,
    this.useVirtualDisplay = false,
    this.showLoading = false,
    final Key? key,
  }) : super(key: key);

  final bool? destroySession;
  final PreferredSizeWidget? appBar;
  final ValueChanged<WebViewController>? onWebViewCreated;
  final ValueChanged<DirectionUrlMatch> onUrlMatch;
  final ValueChanged<bool>? onCookieClear;
  final bool useVirtualDisplay;
  final bool showLoading;

  @override
  State createState() => _LinkedInWebViewHandlerState();
}

class _LinkedInWebViewHandlerState extends State<LinkedInWebViewHandler> {
  late final WebViewController _controller;
  late final WebViewCookieManager cookieManager = WebViewCookieManager();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    // ..loadRequest(Uri.parse('https://flutter.dev'));

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    if (widget.destroySession!) {
      log('LinkedInAuth-steps: cache clearing... ');
      cookieManager.clearCookies().then((final value) {
        widget.onCookieClear?.call(true);
        log('LinkedInAuth-steps: cache clearing... DONE');
      });
    }

    _controller = controller;
  }

  @override
  Widget build(final BuildContext context) {
    final viewModel = _ViewModel.from(context);
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(viewModel.initialUrl()))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) async {
            debugPrint('Page finished loading: $url');
            if (widget.showLoading == true && isLoading == true) {
              //show until ui build
              await Future.delayed(const Duration(seconds: 2));
              setState(() {
                isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            log('LinkedInAuth-steps: navigationDelegate ... ');
            final isMatch = viewModel.isUrlMatchingToRedirection(
              context,
              request.url,
            );
            log(
              'LinkedInAuth-steps: navigationDelegate '
              '[currentUrL: ${request.url}, isCurrentMatch: $isMatch]',
            );

            if (isMatch) {
              widget.onUrlMatch(viewModel.getUrlConfiguration(request.url));
              log('Navigation delegate prevent... done');
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );
    // ..addJavaScriptChannel(
    //   'Toaster',
    //   onMessageReceived: (JavaScriptMessage message) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text(message.message)),
    //     );
    //   },
    // );

    return Scaffold(
      appBar: widget.appBar,
      body: Stack(
        children: [
          Builder(
            builder: (final BuildContext context) {
              return WebViewWidget(
                controller: _controller,
                // initialUrl: viewModel.initialUrl(),
                // javascriptMode: JavascriptMode.unrestricted,
                // onWebViewCreated: (final WebViewController webViewController) async {
                //   log('LinkedInAuth-steps: onWebViewCreated ... ');
                //
                //   widget.onWebViewCreated?.call(webViewController);
                //
                //   log('LinkedInAuth-steps: onWebViewCreated ... DONE');
                // },
                // navigationDelegate: (final NavigationRequest request) async {
                //   log('LinkedInAuth-steps: navigationDelegate ... ');
                //   final isMatch = viewModel.isUrlMatchingToRedirection(
                //     context,
                //     request.url,
                //   );
                //   log(
                //     'LinkedInAuth-steps: navigationDelegate '
                //     '[currentUrL: ${request.url}, isCurrentMatch: $isMatch]',
                //   );
                //
                //   if (isMatch) {
                //     widget.onUrlMatch(viewModel.getUrlConfiguration(request.url));
                //     log('Navigation delegate prevent... done');
                //     return NavigationDecision.prevent;
                //   }
                //
                //   return NavigationDecision.navigate;
                // },
              );
            },
          ),
          if (widget.showLoading == true && isLoading == true)
            const Center(
              child: CircularProgressIndicator(),
            )
        ],
      ),
    );
  }
}

@immutable
class _ViewModel {
  const _ViewModel._({
    required this.graph,
  });

  factory _ViewModel.from(final BuildContext context) => _ViewModel._(
        graph: InjectorWidget.of(context),
      );

  final Graph? graph;

  DirectionUrlMatch getUrlConfiguration(final String url) {
    final type = graph!.linkedInConfiguration is AccessCodeConfiguration ? WidgetType.fullProfile : WidgetType.authCode;
    return DirectionUrlMatch(url: url, type: type);
  }

  String initialUrl() => graph!.linkedInConfiguration.initialUrl;

  bool isUrlMatchingToRedirection(
    final BuildContext context,
    final String url,
  ) {
    return graph!.linkedInConfiguration.isCurrentUrlMatchToRedirection(url);
  }
}
