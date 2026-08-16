/// profile / 邀请码 表单规则（纯函数，单测覆盖；TEST_PLAN.md §2）。
/// 客户端校验之外，服务端 RLS/RPC 仍兜底（AGENTS.md 规则 8）。
library;

/// 昵称：必填；去首尾空白后 1–20 个字符。返回 null 表示合法。
String? validateNickname(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '昵称不能为空';
  if (trimmed.length > 20) return '昵称最多 20 个字符';
  return null;
}

/// 邀请码：去空白、转大写；8 位大写字母数字为合法格式。
String normalizeInviteCode(String input) => input.trim().toUpperCase();

bool isValidInviteCodeFormat(String code) =>
    RegExp(r'^[A-Z0-9]{8}$').hasMatch(code);

/// 空间名称：必填；去首尾空白后 1–30 个字符。返回 null 表示合法。
String? validateSpaceName(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '空间名称不能为空';
  if (trimmed.length > 30) return '空间名称最多 30 个字符';
  return null;
}
