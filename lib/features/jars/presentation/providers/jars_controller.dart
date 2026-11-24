import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/jar_repository.dart';

class JarsController extends ChangeNotifier {
  JarsController(this.repository) {
    reload();
  }
  final JarRepository repository;
  StreamSubscription<JarOverview>? _subscription;
  JarOverview? overview;
  String? error;
  bool loading = true;
  void reload() {
    _subscription?.cancel();
    loading = true;
    error = null;
    notifyListeners();
    _subscription = repository.watchJars().listen(
      (value) {
        overview = value;
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object failure) {
        loading = false;
        error = 'Chưa tải được các hũ. Bạn thử lại nhé.';
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
