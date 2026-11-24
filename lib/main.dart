import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app/integration/finance_bindings.dart';
import 'dev/main_tasks_day_demo.dart';
import 'features/finance/data/fallback_finance_repository.dart';
import 'features/finance/data/remote_finance_repository.dart';

void main() => runApp(const FinAiApp());

class FinAiApp extends StatefulWidget {
  const FinAiApp({super.key});
  @override
  State<FinAiApp> createState() => _FinAiAppState();
}

class _FinAiAppState extends State<FinAiApp> with WidgetsBindingObserver {
  late final http.Client _client;
  late final RemoteFinanceRepository _remote;
  late final FallbackFinanceRepository _finance;
  @override
  void initState() {
    super.initState();
    _client = http.Client();
    const url = String.fromEnvironment(
      'TASKS_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    );
    _remote = RemoteFinanceRepository(
      client: _client,
      baseUrl: Uri.parse(url),
    );
    _finance = FallbackFinanceRepository(remote: _remote);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _remote.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_remote.dispose());
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TasksDemoApp(
    finance: FinanceBindings(
      dashboardReader: _finance,
      expenseWriter: _finance,
      jars: _finance,
    ),
  );
}
