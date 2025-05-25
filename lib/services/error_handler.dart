import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../utils/sentry_logger.dart';

/// 앱 전체에서 사용할 에러 핸들링 서비스
class ErrorHandler {
  /// 싱글톤 인스턴스
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  
  ErrorHandler._internal() {
    setupGlobalErrorHandlers();
  }

  /// 전역 에러 핸들러 설정
  void setupGlobalErrorHandlers() {
    // Flutter 프레임워크 에러 핸들러
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(details.exception, details.stack ?? StackTrace.current);
    };

    // 비동기 에러 핸들러
    runZonedGuarded(() {
      // 앱 실행
    }, (error, stack) {
      _logError(error, stack);
    });
  }

  /// 에러 핸들링 (앱 전체에서 사용)
  void handleError(dynamic error, StackTrace stack, {Map<String, String>? tags}) {
    _logError(error, stack, tags: tags);
  }

  /// 에러 로깅 (Flutter 에러와 Zone 에러 모두 처리)
  void _logError(dynamic error, StackTrace stack, {Map<String, String>? tags}) {
    if (error is FlutterError) {
      // Flutter 프레임워크 에러
      SentryLogger.logFlutterError(
        error,
        stack,
        tags: {...?tags, 'error_type': 'flutter_framework'},
      );
    } else if (error is PlatformException) {
      // Native 플랫폼 에러
      SentryLogger.logNativeError(
        error,
        stack,
        tags: {...?tags, 'error_type': 'native', 'error_code': error.code},
      );
    } else {
      // 기타 에러
      SentryLogger.logFlutterError(
        error,
        stack,
        tags: {...?tags, 'error_type': 'flutter'},
      );
    }
  }
}
 