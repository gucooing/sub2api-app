import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Cloudflare Turnstile 人机验证组件。
///
/// 用内嵌 WebView 渲染官方挑战页;以服务器 origin 作为 baseUrl,
/// 使站点密钥的域名校验通过(与 Web 前端同域)。验证成功回调 token。
class TurnstileWidget extends StatefulWidget {
  const TurnstileWidget({
    super.key,
    required this.siteKey,
    required this.origin,
    required this.onToken,
    this.onExpire,
    this.onError,
  });

  /// Turnstile 站点密钥。
  final String siteKey;

  /// 服务器 origin(如 https://ai.alsl.xyz),作为 WebView 文档来源域。
  final String origin;

  final ValueChanged<String> onToken;
  final VoidCallback? onExpire;
  final VoidCallback? onError;

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final theme = WidgetsBinding
                .instance.platformDispatcher.platformBrightness ==
            Brightness.dark
        ? 'dark'
        : 'light';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('Turnstile', onMessageReceived: _onMessage)
      ..loadHtmlString(_html(theme), baseUrl: widget.origin);
  }

  void _onMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'verify':
          final token = data['token'] as String?;
          if (token != null && token.isNotEmpty) widget.onToken(token);
        case 'expire':
          widget.onExpire?.call();
        case 'error':
          widget.onError?.call();
      }
    } catch (_) {
      // 忽略非预期消息
    }
  }

  String _html(String theme) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTSLoad" async defer></script>
<style>
  html,body{margin:0;padding:0;background:transparent;}
  #c{display:flex;justify-content:center;align-items:center;min-height:70px;}
</style>
</head>
<body>
<div id="c"></div>
<script>
function post(o){ if(window.Turnstile&&window.Turnstile.postMessage){ window.Turnstile.postMessage(JSON.stringify(o)); } }
function onTSLoad(){
  try{
    turnstile.render('#c',{
      sitekey:'${widget.siteKey}',
      theme:'$theme',
      size:'flexible',
      callback:function(t){ post({type:'verify',token:t}); },
      'expired-callback':function(){ post({type:'expire'}); },
      'error-callback':function(){ post({type:'error'}); }
    });
  }catch(e){ post({type:'error'}); }
}
</script>
</body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: WebViewWidget(controller: _controller),
    );
  }
}
