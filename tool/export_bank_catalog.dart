import 'dart:convert';
import 'dart:io';

import 'package:finai/features/native_inbox/domain/bank_catalog.dart';

void main() {
  final file = File('android/app/src/main/assets/finai_bank_catalog.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    jsonEncode([
      for (final e in vietnamBankCatalog)
        {'id': e.id, 'name': e.name, 'aliases': e.aliases},
    ]),
  );
  stdout.writeln('Exported ${vietnamBankCatalog.length} entries');
}
