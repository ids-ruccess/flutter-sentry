import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// 앱 실행 환경(Flavor) 정의함!
/// - dev: 개발용. 터미널에만 로그 출력 (Sentry 전송 X)
/// - qa: QA(테스트) 환경. 터미널에도 출력하고 Sentry로도 전송
/// - prod: 운영 환경. Sentry로만 전송 (터미널 출력 X)
enum Flavor { dev, qa, prod }

class SentryConfig {
  static Flavor? appFlavor;
  static bool isInitialized = false;

  /// main.dart에서 호출 (앱 시작 시 Sentry 초기화함)
  static Future<void> init({
    required Flavor flavor,
  }) async {
    try {
      appFlavor = flavor;

      // Sentry 초기화 (옵션 구성 함수 전달함)
      await SentryFlutter.init(_configureOptions);
      isInitialized = true;
    } catch (e) {
      isInitialized = false;
      print('Sentry 초기화 실패: $e');
      // 로컬 로깅 설정
      _setupLocalLogging();
    }
  }

  /// 로컬 로깅 설정
  static void _setupLocalLogging() {
    // 로컬 로깅 설정
    print('''
📋 로컬 로깅 설정
- 환경: ${appFlavor?.name ?? 'unknown'}
- 시간: ${DateTime.now()}
- 플랫폼: ${Platform.operatingSystem}
''');
  }

  /// Sentry 옵션 구성 함수
  static void _configureOptions(SentryOptions options) {
    final flavor = appFlavor!;

    //===================== 1) 기본 설정 =====================
    // https://docs.sentry.io/product/sentry-basics/dsn-explainer/
    options.dsn = '';
    // release: 앱 버전. 어떤 버전에서 에러가 났는지 추적할 수 있음! (릴리즈 헬스)
    // https://docs.sentry.io/product/releases/
    options.release = '1.0.0';
    // environment: 대시보드 필터 하면 깔껌쓰
    // https://docs.sentry.io/product/sentry-basics/environments/
    options.environment = flavor.name;
    // sendDefaultPii: 개인정보(PII) 전송 여부 (GDPR) 
    // https://docs.sentry.io/platforms/flutter/configuration/options/#send-default-pii
    options.sendDefaultPii = false;
    // debug: Sentry SDK 내부 로그 볼 수 있음! 운영에서는 false 권장
    options.debug = (flavor != Flavor.prod); // dev, qa 환경에서만 터미널에 로그 출력
    // attachStacktrace: 에러 발생 시 자동으로 스택 트레이스를 첨부함 (에러 발생 위치 추적에 필수)
    options.attachStacktrace = true;
    // attachThreads: 에러 발생 시점의 모든 스레드 정보를 첨부함 (멀티스레드 디버깅에 유용)
    options.attachThreads = true;
    // tracesSampleRate: 퍼포먼스(트랜잭션) 샘플링 비율임! 0.0이면 퍼포먼스 데이터 안 보냄 (비용 절감)
    // https://docs.sentry.io/platforms/flutter/performance/
    options.tracesSampleRate = 0.0;

    //================== 2) 에러 무시 필터 ====================
    // beforeSend: 이벤트 전송 전에 마지막으로 가공/필터링 가능
    // 실무에서는 네트워크 타임아웃, HTTP 에러 등은 sentry에 굳이 안 보냄 (노이즈/비용)
    // https://docs.sentry.io/platforms/flutter/configuration/filtering/
    options.beforeSend = (event, {hint}) {
      // 환경 및 레벨에 따라 수집 여부 결정함!
      if (!_shouldCapture(event, flavor)) return null;

      // 네트워크 타임아웃, HTTP 에러는 무시 (백엔드가 처리하고 있기도 함)
      final errorMessage = event.exceptions?.firstOrNull?.value?.toString().toLowerCase() ?? '';
      if (errorMessage.contains('timeoutexception') ||
          errorMessage.contains('httpexception')) {
        return null;
      }

      // 로그 출력 (개발 환경에서만)
      if (flavor != Flavor.prod) {
        final now = DateTime.now();
        final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
        
        // 기본 정보
        final level = event.level ?? SentryLevel.info;
        final levelStr = _getLogLevelString(level);
        final message = event.message?.formatted ?? '';
        print('$timestamp ${_getLogLevelEmoji(level)} [$levelStr] $message');
        
        // 사용자 정보
        if (event.user != null) {
          final userData = event.user?.data?.entries
              .map((e) => '${e.key}:${e.value}')
              .join(', ');
          print('  User: ${event.user?.username ?? 'Unknown'} (${event.user?.id}) ${userData != null ? '| $userData' : ''}');
        }
        
        // 예외 정보
        if (event.exceptions?.isNotEmpty ?? false) {
          final ex = event.exceptions!.first;
          print('  Error: ${ex.type}');
          print('  Message: ${ex.value}');
          if (ex.stackTrace?.frames?.isNotEmpty ?? false) {
            final frame = ex.stackTrace!.frames!.first;
            print('  Stack: ${frame.module}.${frame.function}');
            print('  Location: ${frame.absPath}:${frame.lineNo}');
          }
        }

        // 태그 정보
        if (event.tags?.isNotEmpty ?? false) {
          final tags = event.tags!.entries
              .map((e) => '${e.key}:${e.value}')
              .join(', ');
          print('  Tags: $tags');
        }
        print(''); // 빈 줄 추가
      }else {
        // 태그 추가: 에러 유형, 플랫폼, 위치 정보 등 (immutable 방식!)
        return _addTags(event);
      }

    };

    //============= 3) 사용자 행동 기록 필터(브레드크럼) ============= 
    // beforeBreadcrumb: 브레드크럼(사용자 행동 로그) 너무 많으면 비용 증대! (특히 ui.click은 주로 사용하지 않는다고 합니다.)
    // https://docs.sentry.io/platforms/flutter/configuration/filtering/#beforebreadcrumb
    options.beforeBreadcrumb = (breadcrumb, {hint}) {
      // UI 클릭 이벤트 너무 잦으면 제거해서 스토리지/비용 절감함!
      if (breadcrumb?.category == 'ui.click' &&
          breadcrumb?.level == SentryLevel.debug) {
        return null;
      }
      return breadcrumb;
    };
  }

  /// 환경 및 이벤트 레벨에 따른 수집 여부!
  /// - dev: 개발 중에는 sentry에 전송하지 않음! (콘솔에서만 확인함)
  /// - qa: debug 레벨 로그는 무시하고, 주요 에러만 전송함!
  /// - prod: warning 이상만 전송해서 비용 최적화함!
  static bool _shouldCapture(SentryEvent event, Flavor flavor) {
    switch (flavor) {
      case Flavor.dev:
        return true; // dev 환경에서는 모든 이벤트를 전송 (beforeSend에서 필터링)
      case Flavor.qa:
        return true; // qa 환경에서는 모든 이벤트를 전송 (beforeSend에서 필터링)
      case Flavor.prod:
        return event.level == SentryLevel.warning || 
               event.level == SentryLevel.error || 
               event.level == SentryLevel.fatal; // prod 환경에서는 warning 이상만 Sentry로 전송... 이건 고민해볼 필요가 있음
    }
  }

  /// immutable 방식으로 태그 추가
  /// - error_type: 네이티브 크래시인지 Flutter 예외인지 구분함! (분석에 도움됨)
  /// - platform: 실행 플랫폼(android/ios/web/dart)
  /// - error_location: Flutter 에러의 경우 첫 프레임 위치
  /// 공식문서: https://docs.sentry.io/platforms/flutter/enriching-events/tags/
  static SentryEvent _addTags(SentryEvent event) {
    final isNative = event.exceptions?.any((ex) => ex.mechanism?.type == 'native') ?? false;
    final platform = event.platform?.toLowerCase() ?? 'unknown';
    final tags = Map<String, String>.from(event.tags ?? {});
    tags['error_type'] = isNative ? 'native' : 'flutter';
    tags['platform'] = platform;
    if (!isNative) {
      final frame = event.exceptions?.firstOrNull?.stackTrace?.frames?.firstOrNull;
      if (frame != null) {
        tags['error_location'] = '${frame.module}:${frame.function}';
      }
    }
    return event.copyWith(tags: tags);
  }

  /// 로그 레벨에 따른 이모지 반환
  static String _getLogLevelEmoji(SentryLevel level) {
    switch (level) {
      case SentryLevel.debug:
        return '🔍';
      case SentryLevel.info:
        return 'ℹ️';
      case SentryLevel.warning:
        return '⚠️';
      case SentryLevel.error:
        return '🚨';
      case SentryLevel.fatal:
        return '💀';
      default:
        return '📌';
    }
  }

  /// 로그 레벨을 문자열로 변환
  static String _getLogLevelString(SentryLevel level) {
    switch (level) {
      case SentryLevel.debug:
        return 'DEBUG';
      case SentryLevel.info:
        return 'INFO';
      case SentryLevel.warning:
        return 'WARN';
      case SentryLevel.error:
        return 'ERROR';
      case SentryLevel.fatal:
        return 'FATAL';
      default:
        return 'INFO';
    }
  }
}
