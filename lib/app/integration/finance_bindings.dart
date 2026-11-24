import '../../features/dashboard/domain/dashboard_repository.dart';
import '../../features/jars/domain/jar_repository.dart';

class FinanceBindings {
  const FinanceBindings({
    required this.dashboardReader,
    required this.expenseWriter,
    required this.jars,
  });
  final DashboardReader dashboardReader;
  final ExpenseWriter expenseWriter;
  final JarRepository jars;
}
