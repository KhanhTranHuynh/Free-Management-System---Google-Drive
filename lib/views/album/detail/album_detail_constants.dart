// Tương ứng TAB_CONFIG / XAC_NHAN / useCoQuyen trong DetailAlbum.jsx

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

/// Quyền của phiên hiện tại (tương ứng useCoQuyen + loaiPhien bên React).
/// TODO: nối với hệ thống phân quyền thật của app Flutter.
class AlbumQuyen {
  const AlbumQuyen({
    this.laNhanVien = false,
    this.xemMatKhau = false,
    this.suaAlbum = false,
    this.chonAnh = true,
    this.taoYeuCau = true,
    this.huyYeuCau = true,
    this.suaYeuCau = false,
    this.chotTatCa = false,
    this.xoaCungTatCa = false,
  });

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
