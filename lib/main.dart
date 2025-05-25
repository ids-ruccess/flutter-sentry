import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/sentry_config.dart';
import 'utils/sentry_logger.dart' as logger;
import 'services/error_handler.dart';

void main() async {
  // 1. Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 전역 에러 핸들러 설정
  ErrorHandler();

  // 3. Sentry 초기화
  await SentryConfig.init(flavor: Flavor.dev);

  // 4. 앱 실행
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Sentry Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Sentry Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  // Flutter 에러 발생
  void _throwFlutterError() {
    throw FlutterError('This is a test Flutter error');
  }

  // Native 에러 발생
  void _throwNativeError() {
    throw PlatformException(
      code: 'TEST_ERROR',
      message: 'This is a test Native error',
    );
  }

  // 일반 로그 전송
  void _sendGeneralLog() {
    logger.SentryLogger.log(
      'This is a general log message',
      tags: {'action': 'test_general_log'},
    );
  }

  // 경고 로그 전송
  void _sendWarningLog() {
    logger.SentryLogger.log(
      'This is a warning message',
      tags: {'action': 'test_warning_log'},
      level: SentryLevel.warning,
    );
  }

  // 사용자 정보 설정
  void _setUserInfo() {
    logger.SentryLogger.setUser(
      userId: 1111,
      nickName: 'Test User',
      data: {'role': 'tester'},
    );
  }

  // 사용자 정보 초기화
  void _clearUserInfo() {
    logger.SentryLogger.clearUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _throwFlutterError,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Flutter Error'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _throwNativeError,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Native Error'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _sendGeneralLog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('General Log'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _sendWarningLog,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: const Text('Warning Log'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _setUserInfo,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Set User Info'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _clearUserInfo,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('Clear User Info'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
