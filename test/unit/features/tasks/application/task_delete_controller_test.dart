import 'dart:async';

import 'package:finai/core/types/app_failure.dart';
import 'package:finai/core/types/result.dart';
import 'package:finai/features/tasks/application/task_delete_controller.dart';
import 'package:finai/features/tasks/domain/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class DeleteStub implements TaskRepository {
  final calls = <String>[];
  final pending = <Completer<Result<void>>>[];
  bool throwOnCall = false;
  @override
  Future<Result<void>> delete(String id) {
    calls.add(id);
    if (throwOnCall) throw StateError('private details');
    final result = Completer<Result<void>>();
    pending.add(result);
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DeleteStub repo;
  late TaskDeleteController controller;
  setUp(() {
    repo = DeleteStub();
    controller = TaskDeleteController(repository: repo);
  });
  tearDown(() {
    controller.dispose();
  });
  test('khóa gửi trùng cùng ID, thành công mở khóa', () async {
    final pending = controller.delete('one');
    expect(controller.isDeleting('one'), isTrue);
    expect(await controller.delete('one'), isFalse);
    expect(repo.calls, ['one']);
    repo.pending.single.complete(const Success<void>(null));
    expect(await pending, isTrue);
    expect(controller.isDeleting('one'), isFalse);
  });
  test('Failure giữ nguyên, lần thử sau có thể thành công', () async {
    const error = AppFailure(code: AppFailureCode.notFound, message: 'Missing');
    final pending = controller.delete('one');
    repo.pending.single.complete(const Failure(error));
    expect(await pending, isFalse);
    expect(controller.failureFor('one'), same(error));
    final retry = controller.delete('one');
    expect(controller.failureFor('one'), isNull);
    repo.pending.last.complete(const Success<void>(null));
    expect(await retry, isTrue);
  });
  test('ID khác không bị khóa chung và exception an toàn', () async {
    final a = controller.delete('a');
    repo.throwOnCall = true;
    expect(await controller.delete('b'), isFalse);
    expect(controller.failureFor('b')!.code, AppFailureCode.unavailable);
    expect(controller.failureFor('b')!.message, isNot(contains('private')));
    expect(controller.isDeleting('a'), isTrue);
    repo.pending.single.complete(const Success<void>(null));
    await a;
  });
  test('dispose không notify kết quả muộn hoặc nhận lệnh mới', () async {
    var count = 0;
    controller.addListener(() {
      count++;
    });
    final pending = controller.delete('one');
    controller.dispose();
    repo.pending.single.complete(const Success<void>(null));
    expect(await pending, isFalse);
    expect(await controller.delete('two'), isFalse);
    expect(repo.calls, hasLength(1));
    expect(count, 1);
  });
}
