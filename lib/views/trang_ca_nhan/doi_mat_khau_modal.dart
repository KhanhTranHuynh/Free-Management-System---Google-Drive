import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/ca_nhan_api.dart';
import '../../components/app_modal.dart';
import '../../components/app_text_input.dart';

/// Modal đổi mật khẩu — hành động TỰ THÂN, khớp DoiMatKhau.jsx bên React
/// (POST /tai-khoan/doi-mat-khau, không có field id nào — BE lấy tài
/// khoản mục tiêu từ JWT của người đang đăng nhập).
Future<void> showDoiMatKhauModal(BuildContext context) {
  final controller = _DoiMatKhauController();
  final ketQua = showAppModal(
    context,
    title: 'Đổi mật khẩu',
    type: AppModalType.bottomSheet,
    builder: (ctx) => _DoiMatKhauForm(controller: controller),
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

  // QUAN TRỌNG: KHÔNG dispose ngay khi Future trả về (Navigator.pop() làm
  // Future này hoàn tất gần như tức thì), vì lúc đó widget của modal vẫn
  // còn đang chạy animation đóng (transitionDuration ~250ms) và vẫn còn
  // tham chiếu tới `controller`/các TextEditingController bên trong nó.
  // Dispose quá sớm gây lỗi "_dependents.isEmpty" (Failed assertion).
  // -> đợi thêm 1 khoảng đủ dài hơn thời gian animation rồi mới dispose.
  return ketQua.whenComplete(() async {
    await Future.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  });
}

/// Yêu cầu mật khẩu tối thiểu — TODO: thay 2 hằng số này bằng config dùng
/// chung của app (giống config.MIN_PASSWORD_LENGTH / MAX_PASSWORD_LENGTH
/// bên React) nếu đã có, để không lệch với validate phía BE.
const _doDaiMin = 6;
const _doDaiMax = 32;

class _DoiMatKhauController extends ChangeNotifier {
  _DoiMatKhauController() {
    matKhauCuCtrl.addListener(_xoaLoiKhiGoLai);
    matKhauMoiCtrl.addListener(_xoaLoiKhiGoLai);
    xacNhanCtrl.addListener(_xoaLoiKhiGoLai);
  }

  final matKhauCuCtrl = TextEditingController();
  final matKhauMoiCtrl = TextEditingController();
  final xacNhanCtrl = TextEditingController();

  String? loiMatKhauCu;
  String? loiMatKhauMoi;
  String? loiXacNhan;
  bool isPending = false;

  void _xoaLoiKhiGoLai() {
    loiMatKhauCu = null;
    loiMatKhauMoi = null;
    loiXacNhan = null;
    notifyListeners();
  }

  /// Checklist yêu cầu mật khẩu mới — chỉ để hiển thị, không thay đổi
  /// logic validate thật (giống `requirements` bên React).
  List<({String label, bool met})> get yeuCau {
    final moi = matKhauMoiCtrl.text.trim();
    final cu = matKhauCuCtrl.text.trim();
    final xacNhan = xacNhanCtrl.text.trim();
    return [
      (label: 'Tối thiểu $_doDaiMin ký tự', met: moi.length >= _doDaiMin),
      (
        label: 'Khác mật khẩu hiện tại',
        met: moi.isNotEmpty && cu.isNotEmpty && moi != cu,
      ),
      (
        label: 'Khớp với xác nhận mật khẩu',
        met: moi.isNotEmpty && xacNhan.isNotEmpty && moi == xacNhan,
      ),
    ];
  }

  /// Thanh độ mạnh mật khẩu — chỉ derive để hiển thị (giống `strength`).
  ({int score, String label, Color color}) get doManh {
    final moi = matKhauMoiCtrl.text.trim();
    if (moi.isEmpty) {
      return (score: 0, label: '', color: const Color(0xFFE2E8F0));
    }

    var score = 0;
    if (moi.length >= 8) score += 1;
    if (moi.length >= 12) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(moi)) score += 1;
    if (RegExp(r'[0-9]').hasMatch(moi)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(moi)) score += 1;

    if (score <= 1) {
      return (score: 1, label: 'Yếu', color: const Color(0xFFFB7185));
    }
    if (score <= 2) {
      return (score: 2, label: 'Trung bình', color: const Color(0xFFFBBF24));
    }
    if (score <= 3) {
      return (score: 3, label: 'Khá', color: const Color(0xFFFACC15));
    }
    if (score <= 4) {
      return (score: 4, label: 'Mạnh', color: const Color(0xFF34D399));
    }
    return (score: 5, label: 'Rất mạnh', color: const Color(0xFF10B981));
  }

  bool _validate() {
    loiMatKhauCu = matKhauCuCtrl.text.trim().isEmpty
        ? 'Vui lòng nhập mật khẩu hiện tại'
        : null;

    final moi = matKhauMoiCtrl.text.trim();
    final cu = matKhauCuCtrl.text.trim();
    if (moi.isEmpty) {
      loiMatKhauMoi = 'Vui lòng nhập mật khẩu mới';
    } else if (moi.length < _doDaiMin) {
      loiMatKhauMoi = 'Mật khẩu mới phải có ít nhất $_doDaiMin ký tự';
    } else if (moi.length > _doDaiMax) {
      loiMatKhauMoi = 'Mật khẩu mới không được quá $_doDaiMax ký tự';
    } else if (moi == cu) {
      loiMatKhauMoi = 'Mật khẩu mới phải khác mật khẩu hiện tại';
    } else {
      loiMatKhauMoi = null;
    }

    final xacNhan = xacNhanCtrl.text.trim();
    if (xacNhan.isEmpty) {
      loiXacNhan = 'Vui lòng xác nhận mật khẩu mới';
    } else if (xacNhan != moi) {
      loiXacNhan = 'Mật khẩu xác nhận không khớp';
    } else {
      loiXacNhan = null;
    }

    notifyListeners();
    return loiMatKhauCu == null && loiMatKhauMoi == null && loiXacNhan == null;
  }

  Future<void> submit(BuildContext context) async {
    if (isPending) return;
    if (!_validate()) return;

    isPending = true;
    notifyListeners();

    try {
      await CaNhanApi(ApiRequestManager.instance).doiMatKhau(
        matKhauCu: matKhauCuCtrl.text.trim(),
        matKhauMoi: matKhauMoiCtrl.text.trim(),
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đổi mật khẩu thất bại. Vui lòng thử lại.')),
        );
      }
    } finally {
      isPending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    matKhauCuCtrl.dispose();
    matKhauMoiCtrl.dispose();
    xacNhanCtrl.dispose();
    super.dispose();
  }
}

class _DoiMatKhauForm extends StatelessWidget {
  const _DoiMatKhauForm({required this.controller});
  final _DoiMatKhauController controller;

  static const _tieuDeNho = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: Color(0xFF94A3B8),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final doManh = controller.doManh;
        final hienThiKiemTra = controller.matKhauMoiCtrl.text.isNotEmpty;
        final hienThiChecklist = controller.matKhauMoiCtrl.text.isNotEmpty ||
            controller.xacNhanCtrl.text.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BanngonThongBao(
              icon: Icons.shield_outlined,
              title: 'Bảo mật tài khoản',
              subtitle:
                  'Nhập mật khẩu hiện tại và đặt một mật khẩu mới đủ mạnh để bảo vệ tài khoản của bạn.',
            ),
            const SizedBox(height: 20),
            const Text('MẬT KHẨU HIỆN TẠI', style: _tieuDeNho),
            const SizedBox(height: 8),
            // Trước dùng AppTextField (obscureText: true, tự set icon
            // ẩn/hiện) -> chuyển sang AppTextInput với
            // `type: AppTextInputType.password`, đã có sẵn đúng hành vi
            // đó (obscure mặc định + icon toggle) nên không cần khai báo
            // thêm gì cho việc ẩn/hiện mật khẩu.
            AppTextInput(
              controller: controller.matKhauCuCtrl,
              label: 'Mật khẩu hiện tại',
              type: AppTextInputType.password,
              hint: 'Nhập mật khẩu hiện tại',
              prefixIcon: Icons.lock_outline,
              errorText: controller.loiMatKhauCu,
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text('MẬT KHẨU MỚI', style: _tieuDeNho),
            const SizedBox(height: 8),
            AppTextInput(
              controller: controller.matKhauMoiCtrl,
              label: 'Mật khẩu mới',
              type: AppTextInputType.password,
              hint: 'Tối thiểu $_doDaiMin ký tự',
              prefixIcon: Icons.key_outlined,
              errorText: controller.loiMatKhauMoi,
              minPasswordLength: _doDaiMin,
              maxPasswordLength: _doDaiMax,
            ),
            if (hienThiKiemTra) ...[
              const SizedBox(height: 8),
              _ThanhDoManh(doManh: doManh),
            ],
            const SizedBox(height: 12),
            AppTextInput(
              controller: controller.xacNhanCtrl,
              label: 'Xác nhận mật khẩu mới',
              type: AppTextInputType.password,
              hint: 'Nhập lại mật khẩu mới',
              prefixIcon: Icons.key_outlined,
              errorText: controller.loiXacNhan,
            ),
            if (hienThiChecklist) ...[
              const SizedBox(height: 12),
              _ChecklistYeuCau(items: controller.yeuCau),
            ],
          ],
        );
      },
    );
  }
}

class _BanngonThongBao extends StatelessWidget {
  const _BanngonThongBao({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
            child: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThanhDoManh extends StatelessWidget {
  const _ThanhDoManh({required this.doManh});
  final ({int score, String label, Color color}) doManh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(5, (i) {
            final active = i < doManh.score;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                height: 5,
                decoration: BoxDecoration(
                  color: active ? doManh.color : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Độ mạnh: ${doManh.label}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: doManh.color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistYeuCau extends StatelessWidget {
  const _ChecklistYeuCau({required this.items});
  final List<({String label, bool met})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    item.met ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 15,
                    color: item.met
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.met
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
