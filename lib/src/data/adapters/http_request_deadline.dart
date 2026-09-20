import 'dart:async';
import 'dart:io';

/// 单次请求的总期限，覆盖连接、响应头和正文；迟到的连接也立即中止。
class HttpRequestDeadline {
  HttpClientRequest? _request;
  bool _expired = false;

  void attach(HttpClientRequest request) {
    _request = request;
    if (_expired) request.abort();
    check();
  }

  void check() {
    if (_expired) throw TimeoutException('HTTP request deadline exceeded');
  }

  static Future<T> run<T>(Duration timeout,
      Future<T> Function(HttpRequestDeadline deadline) operation) {
    final deadline = HttpRequestDeadline();
    return operation(deadline).timeout(timeout, onTimeout: () {
      deadline._expired = true;
      deadline._request?.abort();
      throw TimeoutException('HTTP request deadline exceeded', timeout);
    });
  }
}
