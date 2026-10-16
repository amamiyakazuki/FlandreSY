import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Exercises production HTTP parsing without credentials or external services.
class LoopbackService {
  LoopbackService._(this.server);
  final HttpServer server;
  final client = _RealHttpOverrides().createHttpClient(null);
  final paths = <String>[];
  Object? response = <String, Object?>{'code': 0};
  int status = 200;
  String? raw;
  FutureOr<Object?> Function(String path)? respond;
  late StreamSubscription<HttpRequest> _subscription;

  String get url => 'http://127.0.0.1:${server.port}/';

  static Future<LoopbackService> start() async {
    final service = LoopbackService._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    service._subscription = service.server.listen((request) async {
      await request.drain<void>();
      final path = request.uri.path.substring(1);
      service.paths.add(path);
      final body = service.respond == null
          ? service.response
          : await service.respond!(path);
      request.response.statusCode = service.status;
      request.response.write(service.raw ?? jsonEncode(body));
      await request.response.close();
    });
    return service;
  }

  Future<void> close() async {
    client.close(force: true);
    await _subscription.cancel();
    await server.close(force: true);
  }
}

// Flutter widget bindings replace HttpClient with a fixed HTTP 400 client.
class _RealHttpOverrides extends HttpOverrides {}
