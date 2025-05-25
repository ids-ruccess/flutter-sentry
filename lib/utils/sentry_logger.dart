import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry 로깅을 위한 유틸리티 클래스
/// - 기본 Sentry API를 래핑해서 자주 쓰는 패턴(태그 추가, 스코프 관리 등)을 편리하게 사용할 수 있어요?
/// 공식문서: https://docs.sentry.io/platforms/flutter/
class SentryLogger {
  /// 일반 로그 메시지 전송함!
  /// - message: 보낼 메시지
  /// - tags: 추가할 태그 (선택)
  /// - extra: 추가할 extra 데이터 (선택)
  /// - level: 로그 레벨 (기본값: info)
  static Future<void> log(
    String message, {
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    SentryLevel level = SentryLevel.info,
  }) async {
    await _withScope(
      tags: tags,
      extra: extra,
      action: () async {
        await Sentry.captureEvent(
          SentryEvent(
            level: level,
            message: SentryMessage(message),
          ),
        );
      },
    );
  }

  /// Flutter 에러 로깅
  /// - exception: 발생한 예외
  /// - stackTrace: 스택 트레이스
  /// - tags: 추가할 태그 (선택)
  /// - extra: 추가할 extra 데이터 (선택)
  static Future<void> logFlutterError(
    dynamic exception,
    StackTrace stackTrace, {
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
  }) async {
    final mergedTags = {...?tags, 'error_type': 'flutter'};
    await _withScope(
      tags: mergedTags,
      extra: extra,
      action: () async {
        await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.level = SentryLevel.error;
          },
        );
      },
    );
  }

  /// Native 에러 로깅
  /// - exception: 발생한 예외
  /// - stackTrace: 스택 트레이스
  /// - tags: 추가할 태그 (선택)
  /// - extra: 추가할 extra 데이터 (선택)
  static Future<void> logNativeError(
    dynamic exception,
    StackTrace stackTrace, {
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
  }) async {
    final mergedTags = {...?tags, 'error_type': 'native'};
    await _withScope(
      tags: mergedTags,
      extra: extra,
      action: () async {
        await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.level = SentryLevel.error;
          },
        );
      },
    );
  }

  /// 브레드크럼 추가함!
  /// - message: 브레드크럼 메시지
  /// - category: 카테고리 (선택)
  /// - data: 추가 데이터 (선택)
  /// - level: 로그 레벨 (기본값: info)
  static Future<void> addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) async {
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
      ),
    );
  }

  /// 사용자 정보 설정
  /// - userId: 사용자 ID
  /// - nickName: 닉네임 (선택)
  /// - data: 추가 데이터 (선택)
  static Future<void> setUser({
    required int userId,
    String? nickName,
    Map<String, dynamic>? data,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId.toString(),
        username: nickName,
        data: data,
      ));
    });
  }

  /// 사용자 정보 초기화
  static Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// 임시 태그/extra를 설정하고, action 실행 후 원상복구
  /// - tags: 추가할 태그 (선택)
  /// - extra: 추가할 extra 데이터 (선택)
  /// - action: 실행할 함수
  static Future<void> _withScope({
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    required Future<void> Function() action,
  }) async {
    final oldTags = <String, String>{};
    final oldExtras = <String, dynamic>{};
    await Sentry.configureScope((scope) {
      if (tags != null) {
        for (final entry in tags.entries) {
          oldTags[entry.key] = scope.tags[entry.key] ?? '';
          scope.setTag(entry.key, entry.value);
        }
      }
      if (extra != null) {
        for (final entry in extra.entries) {
          oldExtras[entry.key] = scope.extra[entry.key];
          scope.setExtra(entry.key, entry.value);
        }
      }
    });
    try {
      await action();
    } finally {
      await Sentry.configureScope((scope) {
        if (tags != null) {
          for (final entry in tags.entries) {
            if (oldTags[entry.key] != null && oldTags[entry.key]!.isNotEmpty) {
              scope.setTag(entry.key, oldTags[entry.key]!);
            } else {
              scope.removeTag(entry.key);
            }
          }
        }
        if (extra != null) {
          for (final entry in extra.entries) {
            if (oldExtras[entry.key] != null) {
              scope.setExtra(entry.key, oldExtras[entry.key]);
            } else {
              scope.removeExtra(entry.key);
            }
          }
        }
      });
    }
  }
} 