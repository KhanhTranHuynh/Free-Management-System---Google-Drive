// Tương ứng TAB_CONFIG / XAC_NHAN / useCoQuyen trong DetailAlbum.jsx

import '../../../stores/auth_store.dart';

class AlbumConfig {
  /// TODO: điền domain FE thật (config.CLIENT_URL bên React) để tạo link
  /// chia sẻ / QR: {clientUrl}/chi-tiet-album/{ma_truy_cap_cong_khai}
  static const String clientUrl = 'https://TODO-domain-fe';
}

class AlbumTab {
  static const anh = 'anh';
  static const yeuCau = 'yeu_cau';
  static const chotYeuCau = 'chot_yeu_cau';
  static const daSua = 'da_sua';

  static const all = [anh, yeuCau, chotYeuCau, daSua];

  static const labels = {
    anh: 'Tất cả ảnh',
    yeuCau: 'Chưa chốt',
    chotYeuCau: 'Đã chốt',
    daSua: 'Đã chỉnh sửa',
  };

  static const titles = {
    anh: 'Danh sách Tất cả ảnh Album',
    yeuCau: 'Danh sách ảnh đã yêu cầu chỉnh sửa (chưa chốt)',
    chotYeuCau: 'Danh sách ảnh yêu cầu chỉnh sửa đã chốt',
    daSua: 'Danh sách ảnh đã chỉnh sửa',
  };

  static const emptyMessages = {
    anh: 'Album chưa có ảnh nào khớp với bộ lọc này.',
    yeuCau: 'Chưa có ảnh nào đang yêu cầu chỉnh sửa (chưa chốt).',
    chotYeuCau: 'Chưa có ảnh yêu cầu chỉnh sửa nào được chốt.',
    daSua: 'Chưa có ảnh nào được chỉnh sửa.',
  };
}

/// Quyền của phiên hiện tại — khớp các useCoQuyen(...) trong DetailAlbum.jsx.
/// Dựng từ [AuthStore.coQuyen], KHÔNG hard-code.
class AlbumQuyen {
  const AlbumQuyen({
    required this.laNhanVien,
    required this.xemMatKhau,
    required this.suaAlbum,
    required this.chonAnh,
    required this.taoYeuCau,
    required this.huyYeuCau,
    required this.suaYeuCau,
    required this.chotTatCa,
    required this.xoaCungTatCa,
  });

  factory AlbumQuyen.tuAuth(AuthStore auth) => AlbumQuyen(
        // App Flutter là app nhân viên (loaiPhien == NHAN_VIEN bên React).
        laNhanVien: auth.isLoggedIn,
        xemMatKhau: auth.coQuyen('ALBUM', 'dat_mat_khau'),
        suaAlbum: auth.coQuyen('ALBUM', 'sua'),
        chonAnh: auth.coQuyen('TEP_ANH', 'chon'),
        taoYeuCau: auth.coQuyen('YEU_CAU_CHINH_SUA', 'them'),
        huyYeuCau: auth.coQuyen('YEU_CAU_CHINH_SUA', 'huy'),
        suaYeuCau: auth.coQuyen('YEU_CAU_CHINH_SUA', 'sua'),
        chotTatCa: auth.coQuyen('YEU_CAU_CHINH_SUA', 'chot'),
        xoaCungTatCa: auth.coQuyen('YEU_CAU_CHINH_SUA', 'huy'),
      );

  final bool laNhanVien;
  final bool xemMatKhau;
  final bool suaAlbum;
  final bool chonAnh;
  final bool taoYeuCau;
  final bool huyYeuCau;
  final bool suaYeuCau;
  final bool chotTatCa;
  final bool xoaCungTatCa;
}
