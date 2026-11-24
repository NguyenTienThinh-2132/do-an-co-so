import '../../../core/types/result.dart';
import 'native_event.dart';

abstract interface class NativeInboxPort {
  Future<Result<bool>> isAccessGranted();
  Future<Result<void>> openAccessSettings();
  Stream<NativeEvent> watchIncoming();
  Future<Result<List<NativeEvent>>> getPending();
  Future<Result<void>> acknowledge(List<String> ids);
  Future<Result<void>> setAllowedPackages(List<String> packages);
}
