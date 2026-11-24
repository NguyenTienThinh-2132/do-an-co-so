import 'package:finai/dev/tasks_api_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final url in [
    '/relative',
    'http://example.test',
    'https://127.0.0.1:3000',
    'http://user:pass@127.0.0.1:3000',
    'http://127.0.0.1:3000/tasks',
    'http://127.0.0.1:3000?x=1',
    'http://127.0.0.1:3000#fragment',
  ]) {
    test('Probe từ chối đích ngoài hợp đồng: $url', () async {
      await expectLater(runTasksApiProbe(Uri.parse(url)), throwsArgumentError);
    });
  }
}
