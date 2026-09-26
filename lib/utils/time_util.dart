String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '--';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '--';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}

String formatNgayGio(String? iso) {
  if (iso == null || iso.isEmpty) return '--';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '--';
  final gio = '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
  return '$gio ${formatDate(iso)}';
}

String formatGio(String? iso) {
  final dt = DateTime.tryParse(iso ?? '');
  if (dt == null) return '--';
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

String nhomNgay(DateTime dt) {
  bool cungNgay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final now = DateTime.now();
  final ngayStr = formatDate(dt.toIso8601String());
  if (cungNgay(dt, now)) return 'HÔM NAY, $ngayStr';
  if (cungNgay(dt, now.subtract(const Duration(days: 1)))) {
    return 'HÔM QUA, $ngayStr';
  }
  return ngayStr;
}
