import 'dart:io';

import 'package:finai/dev/tasks_api_probe.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Dùng: dart run tool/check_task_http_repository.dart http://127.0.0.1:3000',
    );
    exitCode = 64;
    return;
  }
  try {
    for (final message in await runTasksApiProbe(Uri.parse(args.single))) {
      stdout.writeln(message);
    }
  } catch (_) {
    stderr.writeln('FAIL: API probe chưa đạt; không in dữ liệu hoặc lỗi thô.');
    exitCode = 1;
  }
}
