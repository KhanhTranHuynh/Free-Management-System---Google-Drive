import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/ca_nhan_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_field.dart';

/// Modal sửa thông tin cá nhân (họ tên + màu hiển thị trên lịch) — hành
/// động TỰ THÂN, khớp SuaThongTin.jsx bên React (POST/PUT /tai-khoan/cap-nhat,
/// không có field id — BE lấy tài khoản mục tiêu từ JWT).
///
/// [onUpdated] nhận về map dữ liệu vừa lưu (tối thiểu: ho_ten, mau_sac) để
/// nơi gọi (TrangCaNhanView) tự cập nhật lại AuthStore.
Future<void> showSuaThongTinModal(
  BuildContext context, {
  required String hoTenBanDau,
  String? mauSacBanDau,
  required String vaiTroHienThi,
  String? soDienThoai,
  String? email,
  required void Function(Map<String, dynamic> ketQua) onUpdated,
}) {
  final controller = _SuaThongTinController(
    hoTenBanDau: hoTenBanDau,
    mauSacBanDau: mauSacBanDau,
    onSuccess: onUpdated,
  );

  final ketQua = showAppModal(
    context,
    title: 'Sửa thông tin cá nhân',
    type: AppModalType.bottomSheet,
    builder: (ctx) => _SuaThongTinForm(
      controller: controller,
      vaiTroHienThi: vaiTroHienThi,
      soDienThoai: soDienThoai,
      email: email,
    ),
    footerBuilder: (ctx) => ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed:
                controller.isPending ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed:
                controller.isPending ? null : () => controller.submit(ctx),
            child: controller.isPending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    ),
  );

  // Xem giải thích chi tiết ở doi_mat_khau_modal.dart: KHÔNG dispose ngay
  // khi Future trả về, phải đợi hết animation đóng modal rồi mới dispose,
  // tránh lỗi "_dependents.isEmpty" (Failed assertion) khi widget con vẫn
  // còn tham chiếu tới controller/TextEditingController lúc đang unmount.
  return ketQua.whenComplete(() async {
    await Future.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  });
}

/// Bảng màu preset để chọn nhanh (thay cho ColorPicker tuỳ biến bên
/// React mà mình chưa có source). Vẫn cho phép nhập hex tuỳ ý qua ô
/// "Mã màu khác" bên dưới bảng preset, HOẶC bấm nút "+" để mở bánh xe
/// màu (flutter_colorpicker) chọn tự do như <input type="color"> bên web.
const _bangMauPreset = [
  '#6366F1', // indigo
  '#0EA5E9', // sky
  '#10B981', // emerald
  '#F59E0B', // amber
  '#EF4444', // red
  '#EC4899', // pink
  '#8B5CF6', // violet
  '#14B8A6', // teal
];

class _SuaThongTinController extends ChangeNotifier {
  _SuaThongTinController({
    required String hoTenBanDau,
    required String? mauSacBanDau,
    required this.onSuccess,
  })  : hoTenCtrl = TextEditingController(text: hoTenBanDau),
        mauSacCtrl = TextEditingController(
          text: (mauSacBanDau ?? _mauSacMacDinh).toUpperCase(),
        ) {
    hoTenCtrl.addListener(() {
      loiHoTen = null;
      notifyListeners();
    });
    mauSacCtrl.addListener(() {
      loiMauSac = null;
      notifyListeners();
    });
  }

  // TODO: thay bằng config màu mặc định dùng chung của app nếu đã có.
  static const _mauSacMacDinh = '#6366F1';

  final TextEditingController hoTenCtrl;
  final TextEditingController mauSacCtrl;
  final void Function(Map<String, dynamic> ketQua) onSuccess;

  String? loiHoTen;
  String? loiMauSac;
  bool isPending = false;

  void chonMauPreset(String hex) {
    mauSacCtrl.text = hex.toUpperCase();
  }

  /// Set màu từ bánh xe màu tự do (Color object -> chuỗi hex #RRGGBB).
  void chonMauTuyChinh(Color mau) {
    final hex = '#'
        '${mau.red.toRadixString(16).padLeft(2, '0')}'
        '${mau.green.toRadixString(16).padLeft(2, '0')}'
        '${mau.blue.toRadixString(16).padLeft(2, '0')}';
    mauSacCtrl.text = hex.toUpperCase();
  }

  bool _validate() {
    loiHoTen = hoTenCtrl.text.trim().isEmpty ? 'Vui lòng nhập họ tên' : null;

    final mau = mauSacCtrl.text.trim();
    final hexHopLe = RegExp(r'^#[0-9A-Fa-f]{6}$');
    loiMauSac = (mau.isNotEmpty && !hexHopLe.hasMatch(mau))
        ? 'Mã màu không hợp lệ'
        : null;

    notifyListeners();
    return loiHoTen == null && loiMauSac == null;
  }

  Future<void> submit(BuildContext context) async {
    if (isPending) return;
    if (!_validate()) return;

    isPending = true;
    notifyListeners();

    final payload = <String, dynamic>{
      'ho_ten': hoTenCtrl.text.trim(),
      'mau_sac': mauSacCtrl.text.trim(),
    };

    try {
      final ketQua =
          await CaNhanApi(ApiRequestManager.instance).capNhat(payload);

      if (!context.mounted) return;

      final ketQuaCuoi = ketQua.isNotEmpty ? ketQua : payload;

      // ⚠️ FIX "_dependents.isEmpty" (Failed assertion) khi đóng modal:
      // đóng modal trước, rồi dời việc cập nhật AuthStore sang sau khi
      // frame hiện tại đã render xong (addPostFrameCallback), để 2 việc
      // "đóng UI" và "cập nhật global state" không tranh chấp trong
      // cùng một frame (chi tiết xem lịch sử chat / commit trước).
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSuccess(ketQuaCuoi);
      });
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cập nhật thông tin thất bại. Vui lòng thử lại.')),
        );
      }
    } finally {
      isPending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    hoTenCtrl.dispose();
    mauSacCtrl.dispose();
    super.dispose();
  }
}

class _SuaThongTinForm extends StatelessWidget {
  const _SuaThongTinForm({
    required this.controller,
    required this.vaiTroHienThi,
    this.soDienThoai,
    this.email,
  });

  final _SuaThongTinController controller;
  final String vaiTroHienThi;
  final String? soDienThoai;
  final String? email;

  static const _tieuDeNho = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: Color(0xFF94A3B8),
  );

  Color _hex(String hex) {
    final v = hex.replaceFirst('#', '').padLeft(6, '0');
    return Color(int.parse('FF$v', radix: 16));
  }

  /// Mở dialog bánh xe màu tự do (giống <input type="color"> bên web).
  /// Dùng package flutter_colorpicker (nhớ thêm vào pubspec.yaml:
  /// flutter_colorpicker: ^1.1.0).
  ///
  /// ⚠️ Dùng `HueRingPicker` thay vì `ColorPicker` (kiểu ô vuông HSV):
  /// ô vuông HSV của `ColorPicker` có lúc render sai khi nằm lồng trong
  /// AlertDialog + SingleChildScrollView — lớp gradient màu theo hue
  /// không lên đúng, chỉ còn lại gradient trắng-đen (nhìn như "mất
  /// màu"). `HueRingPicker` dùng cơ chế vẽ khác (vòng tròn hue +
  /// paint riêng), ổn định và không bị lỗi này.
  void _moBanhXeMau(BuildContext context) {
    final mauHienTai =
        RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(controller.mauSacCtrl.text.trim())
            ? _hex(controller.mauSacCtrl.text.trim())
            : _hex(_SuaThongTinController._mauSacMacDinh);

    Color mauDangChon = mauHienTai;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Chọn màu tuỳ chỉnh'),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 280,
            child: HueRingPicker(
              pickerColor: mauHienTai,
              onColorChanged: (mau) => mauDangChon = mau,
              displayThumbColor: true,
              enableAlpha: false,
              portraitOnly: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              controller.chonMauTuyChinh(mauDangChon);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BannerThongBao(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  _TruongChiXem(
                    icon: Icons.verified_user_outlined,
                    label: 'Vai trò',
                    value: vaiTroHienThi,
                  ),
                  _TruongChiXem(
                    icon: Icons.phone_outlined,
                    label: 'Số điện thoại',
                    value: soDienThoai,
                  ),
                  _TruongChiXem(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: email,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('HỌ TÊN', style: _tieuDeNho),
            const SizedBox(height: 8),
            AppTextField(
              controller: controller.hoTenCtrl,
              label: 'Họ tên',
              hintText: 'Nhập họ tên',
              prefixIcon: Icons.badge_outlined,
              errorText: controller.loiHoTen,
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text('MÀU HIỂN THỊ TRÊN LỊCH', style: _tieuDeNho),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _bangMauPreset)
                  _SwatchMau(
                    hex: hex,
                    dangChon: controller.mauSacCtrl.text.toUpperCase() ==
                        hex.toUpperCase(),
                    onTap: () => controller.chonMauPreset(hex),
                  ),
                // Nút mở bánh xe màu tự do — tương đương
                // <input type="color"> bên React, không giới hạn 8 màu
                // preset như trước.
                _NutMoBanhXeMau(onTap: () => _moBanhXeMau(context)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hex(
                      RegExp(r'^#[0-9A-Fa-f]{6}$')
                              .hasMatch(controller.mauSacCtrl.text.trim())
                          ? controller.mauSacCtrl.text.trim()
                          : '#6366F1',
                    ),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: controller.mauSacCtrl,
                    label: 'Mã màu (hex)',
                    hintText: '#RRGGBB',
                    prefixIcon: Icons.tag_outlined,
                    errorText: controller.loiMauSac,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Màu này sẽ hiển thị trên các sự kiện của bạn',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ],
        );
      },
    );
  }
}

class _BannerThongBao extends StatelessWidget {
  const _BannerThongBao();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E7FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.account_circle_outlined,
                size: 18, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Thông tin cá nhân',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(
                  'Cập nhật họ tên và màu hiển thị của bạn trên lịch làm việc.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TruongChiXem extends StatelessWidget {
  const _TruongChiXem({
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cột nhãn: tỉ lệ cố định (flex) thay vì co giãn tự do theo
          // độ dài chữ, để cột giá trị bên phải luôn bắt đầu tại cùng
          // một vị trí trên mọi dòng (không còn so le như trước).
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Cột giá trị: canh TRÁI trong phần không gian riêng của nó
          // -> mọi giá trị bắt đầu thẳng hàng nhau.
          Expanded(
            flex: 5,
            child: Text(
              (value == null || value!.isEmpty) ? 'Chưa cập nhật' : value!,
              textAlign: TextAlign.left,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchMau extends StatelessWidget {
  const _SwatchMau({
    required this.hex,
    required this.dangChon,
    required this.onTap,
  });

  final String hex;
  final bool dangChon;
  final VoidCallback onTap;

  Color _hex(String hex) {
    final v = hex.replaceFirst('#', '').padLeft(6, '0');
    return Color(int.parse('FF$v', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final mau = _hex(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: mau,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                dangChon ? Colors.black.withOpacity(0.6) : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: dangChon
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Nút tròn "+" cuối bảng preset — mở bánh xe màu tự do
/// (tương đương <input type="color"> bên web), không giới hạn 8 màu.
class _NutMoBanhXeMau extends StatelessWidget {
  const _NutMoBanhXeMau({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          gradient: const SweepGradient(
            colors: [
              Color(0xFFEF4444),
              Color(0xFFF59E0B),
              Color(0xFF10B981),
              Color(0xFF0EA5E9),
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
              Color(0xFFEF4444),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, size: 11, color: Color(0xFF475569)),
        ),
      ),
    );
  }
}
