import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import '../controllers/project_controller.dart';
import '../utils/app_logger.dart';
import 'sidecar_manager.dart';

class OpenCodeClient {
  static final OpenCodeClient _instance = OpenCodeClient._internal();
  factory OpenCodeClient() => _instance;

  /// 全局凭据失效信号：HTTP 侧任意请求收到 401/403 时置 true。
  /// 消费端是 OpenCodeApp（lib/app.dart）：提示用户检查凭据后调用
  /// [resetUnauthorized] 复位；SSE 侧凭据失败见 SseClient.isCredentialFailed，
  /// 两者作用域不同。
  static final RxBool unauthorized = false.obs;

  static void resetUnauthorized() => unauthorized.value = false;

  final Dio dio;

  String? activeDirectory;

  OpenCodeClient._internal()
    : dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final manager = SidecarManager.instance;
          options.baseUrl = manager.baseUrl;
          if (manager.password.isNotEmpty) {
            final token = base64Encode(
              utf8.encode('${manager.username}:${manager.password}'),
            );
            options.headers['Authorization'] = 'Basic $token';
          }

          if (options.extra['noAutoDirectory'] == true) {
            return handler.next(options);
          }

          String? dir = options.headers['x-opencode-directory']?.toString();
          if (dir == null || dir.isEmpty) dir = activeDirectory;
          if (dir == null || dir.isEmpty) {
            try {
              if (Get.isRegistered<ProjectController>()) {
                dir =
                    Get.find<ProjectController>().activeProject.value?.worktree;
              }
            } catch (e) {
              AppLogger.e('Failed to resolve active directory: $e');
            }
          }

          if (dir != null && dir.isNotEmpty) {
            dir = dir.replaceAll('\\', '/').replaceAll(RegExp(r'/$'), '');
            if (options.method.toUpperCase() == 'GET') {
              options.queryParameters = {
                ...options.queryParameters,
                'directory': dir,
              };
            } else {
              options.headers['x-opencode-directory'] = dir;
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // 凭据失效（401/403）给出全局信号，供 UI 引导回连接页；
          // 与 SseClient 的 401/403 停连语义保持一致。
          final code = error.response?.statusCode;
          if (code == 401 || code == 403) {
            unauthorized.value = true;
            AppLogger.e('OpenCode API returned $code — credentials invalid');
          }
          handler.next(error);
        },
      ),
    );

    // dio.interceptors.add(
    //   LogInterceptor(
    //     requestHeader: false,
    //     responseHeader: false,
    //     requestBody: true,
    //     responseBody: true,
    //   ),
    // );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? directory,
    bool skipDirectory = false,
    CancelToken? cancelToken,
  }) async {
    return dio.get(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(
        headers: directory != null ? {'x-opencode-directory': directory} : null,
        extra: skipDirectory ? {'noAutoDirectory': true} : null,
      ),
    );
  }

  Future<Response> post(
    String path, {
    dynamic data,
    String? directory,
    Map<String, dynamic>? headers,
    Options? options,
  }) async {
    final opts = options ?? Options();
    final combinedHeaders = <String, dynamic>{
      ...?opts.headers,
      if (directory?.isNotEmpty == true) 'x-opencode-directory': directory,
      ...?headers,
    };
    opts.headers = combinedHeaders;
    return dio.post(path, data: data, options: opts);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return dio.patch(path, data: data);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    String? directory,
    Options? options,
  }) async {
    final opts = options ?? Options();
    if (directory?.isNotEmpty == true) {
      opts.headers = {...?opts.headers, 'x-opencode-directory': directory};
    }
    return dio.put(path, data: data, options: opts);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    String? directory,
    Options? options,
  }) async {
    final opts = options ?? Options();
    if (directory?.isNotEmpty == true) {
      opts.headers = {...?opts.headers, 'x-opencode-directory': directory};
    }
    return dio.delete(path, data: data, options: opts);
  }
}
