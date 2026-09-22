import 'package:flutter/material.dart';

/// Model gọn nhẹ cho 1 mục trong thanh điều hướng dưới cùng.
///
/// KHÔNG dùng chung `MenuItem` (cây menu có `children`/`coCon` cho Drawer)
/// vì thanh dưới cùng luôn phẳng, cố định số lượng item, không có submenu.
/// Tách riêng model giúp widget này không phụ thuộc cấu trúc menu phân quyền
/// đầy đủ — chỉ cần key/tiêu đề/icon/link là đủ để hiển thị + điều hướng.
class ThanhDieuHuongItem {
  const ThanhDieuHuongItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.link,
    this.coBaoHieu = false,
  });

  /// Định danh duy nhất, dùng để so khớp active — KHÔNG dùng `link` để so
  /// khớp vì nhiều key có thể trỏ nhiều path con (vd "đơn hàng" gồm cả
  /// trang danh sách lẫn trang chi tiết).
  final String key;

  final String title;
  final IconData icon;

  /// Route name dùng khi điều hướng (Navigator.pushReplacementNamed).
  final String link;

  /// Có hiển thị chấm báo hiệu (vd: có yêu cầu/nhân viên mới chờ duyệt) hay
  /// không. Widget này KHÔNG tự tính giá trị này — trang cha (nơi được phép
  /// đụng tới store/api) tính rồi truyền vào, giữ đúng nguyên tắc
  /// "component không import stores/apis; UI không tự gọi API".
  final bool coBaoHieu;
}

/// Thanh điều hướng dưới cùng, dùng chung cho MỌI trang.
///
/// Widget THUẦN UI (stateless, không side-effect): nhận `items`,
/// `activeKey` (mục nào đang được chọn) và `onChon` (callback khi bấm) từ
/// bên ngoài. Nơi gọi (thường là 1 Scaffold khung dùng chung — xem
/// `MainScaffold` bên dưới) chịu trách nhiệm biết trang hiện tại là gì và
/// xử lý điều hướng khi người dùng bấm.
///
/// Cách dùng:
/// ```dart
/// ThanhDieuHuongDuoi(
///   items: dsMucDieuHuong,
///   activeKey: 'nhan_vien',
///   onChon: (item) => Navigator.of(context)
///       .pushReplacementNamed(item.link),
/// )
/// ```
class ThanhDieuHuongDuoi extends StatelessWidget {
  const ThanhDieuHuongDuoi({
    super.key,
    required this.items,
    required this.activeKey,
    required this.onChon,
  });

  final List<ThanhDieuHuongItem> items;

  /// `key` của item đang active. Nơi gọi tự xác định (vd từ tên route hiện
  /// tại), widget này không tự đoán từ pathname để tránh phụ thuộc router.
  final String activeKey;

  final ValueChanged<ThanhDieuHuongItem> onChon;

  @override
  Widget build(BuildContext context) {
    // Không hardcode màu — lấy thẳng từ ColorScheme của app (giống
    // AppButton dựa vào ElevatedButtonTheme), nhờ vậy tự đổi theo
    // theme sáng/tối có sẵn mà không cần code riêng cho từng mode.
    // Nếu bộ theme của app định nghĩa `secondary`/`tertiary` là màu vàng
    // đồng thương hiệu thay vì `primary`, đổi `mauDong` bên dưới cho khớp.
    final colorScheme = Theme.of(context).colorScheme;
    final mauNen = colorScheme.surface;
    final mauDong = colorScheme.primary;
    final mauKhongDong = colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: mauNen,
        border: Border(
          top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: items.map((item) {
              final active = item.key == activeKey;
              return Expanded(
                child: _MucDieuHuong(
                  item: item,
                  active: active,
                  mauNen: mauNen,
                  mauDong: mauDong,
                  mauKhongDong: mauKhongDong,
                  onTap: () => onChon(item),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MucDieuHuong extends StatelessWidget {
  const _MucDieuHuong({
    required this.item,
    required this.active,
    required this.mauNen,
    required this.mauDong,
    required this.mauKhongDong,
    required this.onTap,
  });

  final ThanhDieuHuongItem item;
  final bool active;
  final Color mauNen;
  final Color mauDong;
  final Color mauKhongDong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = active ? mauDong : mauKhongDong;

    return InkWell(
      onTap: onTap,
      // Không cần splash/màu nền khi bấm — icon+chữ đổi màu là đủ phản hồi,
      // giữ thanh điều hướng gọn giống thiết kế.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(item.icon, color: mau, size: 24),
                if (item.coBaoHieu)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: mauDong,
                        shape: BoxShape.circle,
                        border: Border.all(color: mauNen, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.title,
              style: TextStyle(
                color: mau,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
