import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MockWebViewController extends Mock implements WebViewController {
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setNavigationDelegate(NavigationDelegate delegate) async {}

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String>? headers,
    Uint8List? body,
  }) async {}

  @override
  Future<void> loadHtmlString(
    String html, {
    String? baseUrl,
  }) async {}

  @override
  Future<void> loadFile(String filePath) async {}

  @override
  Future<void> loadFlutterAsset(String key) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearLocalStorage() async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage) onConsoleMessage,
  ) async {}
} 