import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'tasks_api_probe.dart';

// Entry point kiểm tra mạng, không phải giao diện sản phẩm.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    throw StateError('API probe chỉ được chạy ở bản debug.');
  }
  runApp(const SizedBox.shrink());
  debugPrint('TV3_ANDROID_API_PROBE: START');
  const apiBaseUrl = String.fromEnvironment(
    'TASKS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );
  try {
    for (final message in await runTasksApiProbe(Uri.parse(apiBaseUrl))) {
      debugPrint('TV3_ANDROID_API_PROBE: $message');
    }
    debugPrint('TV3_ANDROID_API_PROBE_RESULT: PASS');
  } catch (_) {
    debugPrint('TV3_ANDROID_API_PROBE_RESULT: FAIL');
  }
}
