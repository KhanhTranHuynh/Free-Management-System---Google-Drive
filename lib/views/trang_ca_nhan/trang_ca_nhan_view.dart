import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../stores/auth_store.dart';
import 'doi_mat_khau_modal.dart';
import 'sua_thong_tin_modal.dart';

/// Trang cá nhân (self-service): xem thông tin tài khoản + 2 thao tác
/// nhanh (đổi mật khẩu / sửa thông tin). Khớp Profile.jsx bên React.
///
/// ⚠️ LƯU Ý: `nguoiDung` đang để kiểu `dynamic` (đọc field qua
/// `nguoiDung?.hoTen`, `nguoiDung?.mauSac`...) vì mình CHƯA có định nghĩa
/// thật của model `NhanVien` (apis/models/user.dart). Đây là cách viết
/// tạm để không đoán sai tên field gây lỗi biên dịch. Sau khi bạn xác
/// nhận đúng tên field của NhanVien, đổi `final dynamic nguoiDung = ...`
/// thành `final NhanVien? nguoiDung = ...` (bỏ dynamic) để có full type
/// safety trở lại.
class TrangCaNhanView extends StatelessWidget {
  const TrangCaNhanView({super.key});

  // TODO: thay bằng config màu mặc định dùng chung của app nếu đã có
  // (giống config.MAU_SAC_MAC_DINH bên React).
  static const _mauSacMacDinh = '#6366F1';

  String _layChuCaiDau(String? hoTen) {
    if (hoTen == null || hoTen.trim().isEmpty) return '?';
    final words = hoTen.trim().split(RegExp(r'\s+'));
    final haiTuCuoi =
        words.length <= 2 ? words : words.sublist(words.length - 2);
    return haiTuCuoi.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
  }

  Color _blend(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  Color _hex(String hex) {
    final v = hex.replaceFirst('#', '').padLeft(6, '0');
    return Color(int.parse('FF$v', radix: 16));
  }

  String _roleNames(dynamic nguoiDung) {
    final list = nguoiDung?.tenVaiTro;
    if (list is List && list.isNotEmpty) {
      return list.whereType<String>().where((e) => e.isNotEmpty).join(', ');
    }
    return 'Chưa có vai trò';
  }

  void _moDoiMatKhau(BuildContext context) {
    showDoiMatKhauModal(context);
  }

  void _moSuaThongTin(BuildContext context, dynamic nguoiDung) {
    showSuaThongTinModal(
      context,
      hoTenBanDau: (nguoiDung?.hoTen as String?) ?? '',
      mauSacBanDau: nguoiDung?.mauSac as String?,
      vaiTroHienThi: _roleNames(nguoiDung),
      soDienThoai: nguoiDung?.soDienThoai as String?,
      email: nguoiDung?.email as String?,
      onUpdated: (ketQua) {
        context.read<AuthStore>().capNhatThongTinCoBan(ketQua);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamic nguoiDung = context.watch<AuthStore>().nguoiDung;

    final tenHienThi = (nguoiDung?.hoTen as String?) ?? 'Người dùng';
    final chuCaiDau = _layChuCaiDau(tenHienThi);
    final roleNames = _roleNames(nguoiDung);
    final trangThaiHoatDong = nguoiDung?.trangThai == true;
    final mauSac = _hex((nguoiDung?.mauSac as String?) ?? _mauSacMacDinh);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----- Header -----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.6, 1],
                colors: [
                  _blend(mauSac, Colors.black, 0.25),
                  mauSac,
                  _blend(mauSac, Colors.white, 0.35),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chuCaiDau,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tenHienThi,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: trangThaiHoatDong
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFF87171),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              trangThaiHoatDong ? 'Đang hoạt động' : 'Đã khoá',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ----- I. Thông tin cá nhân -----
          const _SectionTitle(
            icon: Icons.account_circle_outlined,
            number: 'I',
            title: 'Thông tin cá nhân',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Họ và tên',
                    value: nguoiDung?.hoTen as String?,
                  ),
                  _InfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Vai trò',
                    value: roleNames,
                  ),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Số điện thoại',
                    value: nguoiDung?.soDienThoai as String?,
                  ),
                  _InfoRow(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: nguoiDung?.email as String?,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ----- II. Thao tác nhanh -----
          const _SectionTitle(
            icon: Icons.bolt_outlined,
            number: 'II',
            title: 'Thao tác nhanh',
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.lock_outline,
            title: 'Đổi mật khẩu',
            subtitle: 'Thay đổi mật khẩu đăng nhập',
            onTap: () => _moDoiMatKhau(context),
          ),
          const SizedBox(height: 12),
          _QuickActionCard(
            icon: Icons.edit_outlined,
            title: 'Sửa thông tin',
            subtitle: 'Cập nhật họ tên, màu hiển thị trên lịch',
            onTap: () => _moSuaThongTin(context, nguoiDung),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.number,
    required this.title,
  });

  final IconData icon;
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          '$number. ${title.toUpperCase()}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: hint),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: hint)),
          const Spacer(),
          Flexible(
            child: Text(
              (value == null || value!.isEmpty) ? 'Chưa cập nhật' : value!,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
