/// 跨页面统一的数值/日期格式化工具(避免各页面各写一套)。
library;

/// Token 等大整数压缩:1.2B / 3.4M / 5.6K / 789。
String formatCompact(num n) {
  final v = n.abs();
  if (v >= 1000000000) return '${(n / 1000000000).toStringAsFixed(2)}B';
  if (v >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
  if (v >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// 金额($)。decimals 为空时自动:>=1 用 2 位,否则 4 位(小额更精确)。
String formatCost(num value, {int? decimals}) {
  final d = decimals ?? (value.abs() >= 1 ? 2 : 4);
  return '\$${value.toStringAsFixed(d)}';
}

/// 千分位整数(请求数等):1,204。
String formatInt(num n) {
  final s = n.toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _two(int v) => v.toString().padLeft(2, '0');

/// yyyy-MM-dd
String formatDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// MM-dd
String formatMonthDay(DateTime d) => '${_two(d.month)}-${_two(d.day)}';

/// yyyy-MM-dd HH:mm
String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

/// HH:mm:ss
String formatTime(DateTime d) =>
    '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

/// 相对“多久之前”的粗粒度展示(列表里比绝对时间更易读)。
/// 需要本地化的单位由调用方传入(秒/分/时/天/刚刚),保持 i18n 一致。
String formatRelative(
  DateTime time,
  DateTime now, {
  required String justNow,
  required String Function(int) minutesAgo,
  required String Function(int) hoursAgo,
  required String Function(int) daysAgo,
}) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return justNow;
  if (diff.inMinutes < 60) return minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return hoursAgo(diff.inHours);
  return daysAgo(diff.inDays);
}

/// 计算涨跌幅(百分比)。基准为 0 时返回 null(无法计算)。
double? deltaPercent(num current, num previous) {
  if (previous == 0) return null;
  return (current - previous) / previous.abs() * 100;
}
