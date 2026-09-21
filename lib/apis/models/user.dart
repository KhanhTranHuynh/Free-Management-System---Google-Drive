/// Model dữ liệu người dùng (nhân viên) — khớp nguyên field `data` trả về
/// từ POST /public/xac-thuc/dang-nhap.
///
/// Đây là "thông tin đầy đủ của 1 người" sẽ được lưu nguyên vào
/// `AuthStore.nguoiDung` để tái sử dụng toàn app (ví dụ hiển thị tên,
/// avatar, vai trò ở AppBar/Drawer...).
class NhanVien {
  final String idTaiKhoanNhanVien;
  final String danhTinhId;
  final String email;
  final String soDienThoai;
  final String hoTen;
  final List<String> vaiTro;
  final List<String> tenVaiTro;
  final bool trangThai;
  final bool choPhepDangNhapPortal;
  final String? portalKichHoatLuc;
  final String? portalKichHoatBoi;
  final String idStudioLocal;
  final bool dangHoatDong;
  final bool xoa;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? deletedAt;
  final String? deletedBy;
  final String? mauSac;
  final String loaiDangNhap;

  /// Bản đồ quyền dạng { "TEN_MODULE": "xem,them,sua,xoa,..." }.
  /// Cũng được AuthStore tách ra lưu riêng ở 1 biến khác (`quyen`) để nơi
  /// khác dùng lại không cần đào sâu vào nguoiDung.quyen.
  final Map<String, String> quyen;

  const NhanVien({
    required this.idTaiKhoanNhanVien,
    required this.danhTinhId,
    required this.email,
    required this.soDienThoai,
    required this.hoTen,
    required this.vaiTro,
    required this.tenVaiTro,
    required this.trangThai,
    required this.choPhepDangNhapPortal,
    this.portalKichHoatLuc,
    this.portalKichHoatBoi,
    required this.idStudioLocal,
    required this.dangHoatDong,
    required this.xoa,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    this.deletedBy,
    this.mauSac,
    required this.loaiDangNhap,
    required this.quyen,
  });

  factory NhanVien.fromJson(Map<String, dynamic> json) {
    return NhanVien(
      idTaiKhoanNhanVien: json['id_tai_khoan_nhan_vien'] as String? ?? '',
      danhTinhId: json['danh_tinh_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      soDienThoai: json['so_dien_thoai'] as String? ?? '',
      hoTen: json['ho_ten'] as String? ?? '',
      vaiTro: _dsChuoi(json['vai_tro']),
      tenVaiTro: _dsChuoi(json['ten_vai_tro']),
      trangThai: json['trang_thai'] as bool? ?? false,
      choPhepDangNhapPortal: json['cho_phep_dang_nhap_portal'] as bool? ?? false,
      portalKichHoatLuc: json['portal_kich_hoat_luc'] as String?,
      portalKichHoatBoi: json['portal_kich_hoat_boi'] as String?,
      idStudioLocal: json['id_studio_local'] as String? ?? '',
      dangHoatDong: json['dang_hoat_dong'] as bool? ?? false,
      xoa: json['xoa'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      createdBy: json['created_by'] as String?,
      updatedAt: json['updated_at'] as String?,
      updatedBy: json['updated_by'] as String?,
      deletedAt: json['deleted_at'] as String?,
      deletedBy: json['deleted_by'] as String?,
      mauSac: json['mau_sac'] as String?,
      loaiDangNhap: json['loai_dang_nhap'] as String? ?? '',
      quyen: _banDoQuyen(json['quyen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_tai_khoan_nhan_vien': idTaiKhoanNhanVien,
      'danh_tinh_id': danhTinhId,
      'email': email,
      'so_dien_thoai': soDienThoai,
      'ho_ten': hoTen,
      'vai_tro': vaiTro,
      'ten_vai_tro': tenVaiTro,
      'trang_thai': trangThai,
      'cho_phep_dang_nhap_portal': choPhepDangNhapPortal,
      'portal_kich_hoat_luc': portalKichHoatLuc,
      'portal_kich_hoat_boi': portalKichHoatBoi,
      'id_studio_local': idStudioLocal,
      'dang_hoat_dong': dangHoatDong,
      'xoa': xoa,
      'created_at': createdAt,
      'created_by': createdBy,
      'updated_at': updatedAt,
      'updated_by': updatedBy,
      'deleted_at': deletedAt,
      'deleted_by': deletedBy,
      'mau_sac': mauSac,
      'loai_dang_nhap': loaiDangNhap,
      'quyen': quyen,
    };
  }

  static List<String> _dsChuoi(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static Map<String, String> _banDoQuyen(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return const {};
  }
}
