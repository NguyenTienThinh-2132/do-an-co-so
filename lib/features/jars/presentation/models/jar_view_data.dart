import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/jar_repository.dart';

(IconData, Color, String) jarStyle(String key) => switch (key) {
  'home' => (Icons.home_outlined, AppColors.primary, 'Nhà ở'),
  'savings' => (Icons.savings_outlined, const Color(0xFF4C80C9), 'Tiết kiệm'),
  'education' => (Icons.school_outlined, const Color(0xFFCE8734), 'Học tập'),
  'enjoyment' => (
    Icons.sports_esports_outlined,
    const Color(0xFFC65E9B),
    'Giải trí',
  ),
  'investment' => (
    Icons.trending_up_rounded,
    const Color(0xFF218D77),
    'Đầu tư',
  ),
  'giving' => (
    Icons.volunteer_activism_outlined,
    const Color(0xFF7666CF),
    'Cho đi',
  ),
  _ => (Icons.flag_outlined, AppColors.primary, 'Mục tiêu'),
};

class JarViewData {
  JarViewData(this.jar);
  final Jar jar;
  String get id => jar.id;
  String get title => jar.title;
  String get subtitle => jar.subtitle;
  int get allocationBps => jar.allocationBps;
  int get allocatedAmount => jar.allocatedAmount;
  int get spentAmount => jar.spentAmount;
  int get remainingAmount => jar.remainingAmount;
  bool get isDefault => jar.isDefault;
  bool get isLocked => false;
  bool get isOverspent => remainingAmount < 0;
  IconData get icon => jarStyle(jar.styleKey).$1;
  Color get color => jarStyle(jar.styleKey).$2;
  double get usageProgress =>
      allocatedAmount > 0 ? (spentAmount / allocatedAmount).clamp(0.0, 1.0) : 0;
  String get allocationLabel => formatBps(allocationBps);
}

String formatBps(int value) => value % 100 == 0
    ? '${value ~/ 100}%'
    : '${value ~/ 100},${(value % 100).toString().padLeft(2, '0')}%';
