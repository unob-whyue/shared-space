/// 统一应用错误：携带可直接展示给用户的文案（UI_SPEC.md §19）。
class AppError implements Exception {
  const AppError(this.userMessage, {this.code});

  final String userMessage;
  final String? code;

  @override
  String toString() => 'AppError(code: $code, message: $userMessage)';
}

enum SpaceJoinErrorKind { invalidCode, alreadyMember, spaceFull }

class SpaceJoinError extends AppError {
  const SpaceJoinError(super.userMessage, {required this.kind});

  final SpaceJoinErrorKind kind;
}
