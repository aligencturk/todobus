import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.back,
            color: Color(0xFF3498DB),
          ),
        ),
      ),
      child: SafeArea(
        child: hasError
            ? _buildErrorWidget()
            : Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.url),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
                      allowsInlineMediaPlayback: true,
                      mediaPlaybackRequiresUserGesture: false,
                      transparentBackground: true,
                    ),
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (mounted) {
                        setState(() {
                          isLoading = true;
                          hasError = false;
                        });
                      }
                    },
                    onLoadStop: (controller, url) async {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                          hasError = true;
                          errorMessage = error.description;
                        });
                      }
                    },
                    onReceivedHttpError: (controller, request, errorResponse) {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                          hasError = true;
                          errorMessage = 'HTTP Hatası: ${errorResponse.statusCode}';
                        });
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      if (mounted) {
                        setState(() {
                          this.progress = progress / 100;
                        });
                      }
                    },
                  ),
                  if (isLoading)
                    Container(
                      color: CupertinoColors.systemBackground,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(radius: 16),
                            const SizedBox(height: 16),
                            const Text(
                              'Sayfa yükleniyor...',
                              style: TextStyle(
                                color: Color(0xFF7F8C8D),
                                fontSize: 16,
                              ),
                            ),
                            if (progress > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 12, left: 40, right: 40),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: const Color(0xFFECF0F1),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: CupertinoColors.systemBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 64,
                color: Color(0xFFE74C3C),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sayfa Yüklenemedi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage.isNotEmpty ? errorMessage : 'Bilinmeyen bir hata oluştu',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: () {
                  setState(() {
                    hasError = false;
                    isLoading = true;
                  });
                  webViewController?.loadUrl(
                    urlRequest: URLRequest(url: WebUri(widget.url)),
                  );
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 