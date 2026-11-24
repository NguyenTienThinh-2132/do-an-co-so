import 'package:flutter/material.dart';

import '../../features/dashboard/domain/dashboard_repository.dart';
import '../../features/dashboard/presentation/providers/dashboard_controller.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/finance/presentation/screens/cash_flow_screen.dart';
import '../../features/jars/presentation/screens/jars_screen.dart';
import '../../features/jars/domain/jar_repository.dart';
import '../../features/jars/presentation/providers/jars_controller.dart';
import '../theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.dashboardReader,
    required this.expenseWriter,
    required this.jarRepository,
    required this.tasksBuilder,
    required this.assistantBuilder,
    this.clock,
  });
  final DashboardReader dashboardReader;
  final ExpenseWriter expenseWriter;
  final JarRepository jarRepository;
  final WidgetBuilder tasksBuilder;
  final WidgetBuilder assistantBuilder;
  final DateTime Function()? clock;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late final DashboardController _dashboard = DashboardController(
    reader: widget.dashboardReader,
    writer: widget.expenseWriter,
    clock: widget.clock,
  );
  int _index = 0;
  late final JarsController _jars = JarsController(widget.jarRepository);
  @override
  void dispose() {
    _dashboard.dispose();
    _jars.dispose();
    super.dispose();
  }

  void selectTab(int index) => setState(() => _index = index);
  void _openAssistant([String? prompt]) => selectTab(2);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(
                controller: _dashboard,
                onAssistantRequested: _openAssistant,
              ),
              ListenableBuilder(
                listenable: _dashboard,
                builder: (context, _) => JarsScreen(
                  controller: _jars,
                  moneyVisible: _dashboard.balanceVisible,
                ),
              ),
              Builder(builder: widget.assistantBuilder),
              Builder(builder: widget.tasksBuilder),
              CashFlowScreen(controller: _dashboard),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Row(
              children: [
                _navItem(
                  0,
                  'Trang chủ',
                  Icons.home_outlined,
                  Icons.home_rounded,
                ),
                _navItem(
                  1,
                  'Quản lý hũ',
                  Icons.savings_outlined,
                  Icons.savings_rounded,
                ),
                _navItem(
                  2,
                  'Trợ lý AI',
                  Icons.auto_awesome_rounded,
                  Icons.auto_awesome_rounded,
                ),
                _navItem(
                  3,
                  'Công việc',
                  Icons.checklist_outlined,
                  Icons.checklist_rounded,
                ),
                _navItem(
                  4,
                  'Dòng tiền',
                  Icons.calendar_month_outlined,
                  Icons.calendar_month_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _navItem(int index, String label, IconData icon, IconData activeIcon) {
    final selected = _index == index;
    final isAssistant = index == 2;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: ValueKey('tab-$index'),
          onTap: () => setState(() => _index = index),
          child: SizedBox(
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isAssistant)
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9F5AFF), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  )
                else
                  SizedBox(
                    height: 43,
                    child: Icon(
                      selected ? activeIcon : icon,
                      size: 25,
                      color: selected ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
