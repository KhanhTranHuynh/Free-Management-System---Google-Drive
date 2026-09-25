import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../apis/models/user.dart';
import '../configs/menu_role.dart';
import '../stores/auth_store.dart';
import '../utils/lay_ma_vai_tro.dart';

class QuyenRouteGuard extends StatelessWidget {
  const QuyenRouteGuard({
    super.key,
    required this.menuKey,
    required this.child,
    this.duongDanKhongCoQuyen = '/404',
    this.trangKhongCoQuyen,
  });

  final String menuKey;

  final Widget child;

  final String duongDanKhongCoQuyen;

  final Widget? trangKhongCoQuyen;

  @override
  Widget build(BuildContext context) {
    final nguoiDung = context.watch<AuthStore>().nguoiDung;
    final vaiTro = layMaVaiTro(nguoiDung);
    final duocPhep = coQuyenTruyCapMenu(menuKey, vaiTro);

    if (duocPhep) return child;

    if (trangKhongCoQuyen != null) return trangKhongCoQuyen!;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(duongDanKhongCoQuyen);
      }
    });
    return const SizedBox.shrink();
  }
}

String? quyenRedirect({
  required String menuKey,
  required NhanVien? nguoiDung,
  String duongDanKhongCoQuyen = '/404',
}) {
  final vaiTro = layMaVaiTro(nguoiDung);
  final duocPhep = coQuyenTruyCapMenu(menuKey, vaiTro);
  return duocPhep ? null : duongDanKhongCoQuyen;
}
