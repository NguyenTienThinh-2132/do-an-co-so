/// Local queue lifecycle, independent of the business TaskStatus.
enum TaskOutboxStatus {
  /// Not acknowledged; may be waiting for an earlier operation or a retry.
  pending,

  /// Request frozen and in flight. After a crash retry the identical request.
  sending,

  /// A server acknowledgement has been stored locally.
  synced,

  /// Server changed/deleted the record; wait for explicit resolution.
  conflict,

  /// Non-retryable validation/protocol error. Keep the operation for review.
  failed,
}
