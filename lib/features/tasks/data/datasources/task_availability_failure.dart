import '../../../../core/types/app_failure.dart';

/// Remote connection/timeout/5xx failure that permits a cached LIST read.
/// Validation, authorization and malformed responses never use this subtype.
class TaskAvailabilityFailure extends AppFailure {
  const TaskAvailabilityFailure({required super.message})
    : super(code: AppFailureCode.unavailable);
}
