import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

class AlbumApi {
  AlbumApi(this._manager);

  final ApiRequestManager _manager;

  // ---------------------------------------------------------------------
  // helper
  // ---------------------------------------------------------------------

  /// Bóc lớp `data` của response: trả Map bên trong `data`; nếu `data`
  /// không phải Map thì trả chính body. Không phải Map thì trả rỗng.
  Map<String, dynamic> _bocData(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
  }

  /// Giống `_bocData` nhưng ưu tiên `data.item` (khớp
  /// `res?.data?.item || res?.data` bên React).
  Map<String, dynamic> _bocItem(dynamic raw) {
    final data = _bocData(raw);
    final item = data['item'];
    if (item is Map) return Map<String, dynamic>.from(item);
    return data;
  }

  /// Chuẩn hoá payload thành danh sách: `data` là List, hoặc `data` là Map
  /// có `du_lieu` / `items` / `list`.
  List<Map<String, dynamic>> _danhSachTuPayload(dynamic raw) {
    dynamic node = raw;
    if (node is Map && node['data'] != null) node = node['data'];

    List? list;
    if (node is List) {
      list = node;
    } else if (node is Map) {
      for (final k in ['du_lieu', 'items', 'list']) {
        if (node[k] is List) {
          list = node[k] as List;
          break;
        }
      }
    }

    return [
      for (final e in list ?? const [])
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  // ---------------------------------------------------------------------
  // Album
  // ---------------------------------------------------------------------

  /// Danh sách album — hỗ trợ tìm kiếm, filter, sắp xếp, phân trang.
  /// Trả về { du_lieu, phan_trang, so_luong_theo_trang_thai }.
  Future<Map<String, dynamic>> danhSach({
    required int trang,
    required int soLuong,
    String? idStudioLocal,
    String? timKiem,
    int? trangThai,
    String? quaHanPhanHoi,
    String? tuNgayTao,
    String? denNgayTao,
    String? sapXep,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/danh-sach',
        method: 'GET',
        key: 'album-danh-sach',
        params: {
          'id_studio_local': idStudioLocal,
          'tim_kiem': timKiem ?? '',
          'trang': trang,
          'so_luong': soLuong,
          if (trangThai != null) 'trang_thai': trangThai,
          if (quaHanPhanHoi != null) 'qua_han_phan_hoi': quaHanPhanHoi,
          if (tuNgayTao != null && tuNgayTao.isNotEmpty)
            'tu_ngay_tao': tuNgayTao,
          if (denNgayTao != null && denNgayTao.isNotEmpty)
            'den_ngay_tao': denNgayTao,
          if (sapXep != null && sapXep.isNotEmpty) 'sap_xep': sapXep,
        },
      ),
    );

    if (!kq.isSuccess) {
      if (kq.isCanceled) {
        // Request bị huỷ do có request mới hơn (đổi filter/search liên tục)
        // -> không throw lỗi hiển thị, để ListView tự bỏ qua qua _requestId.
        throw const ApiException(message: '');
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách album.');
    }

    return _bocData(kq.payload);
  }

  Future<Map<String, dynamic>> taoMoi(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/tao-moi',
        method: 'POST',
        key: 'album-tao-moi',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Thêm album thất bại.');
    }
    return _bocData(kq.payload);
  }

  Future<Map<String, dynamic>> chiTiet({required String idAlbum}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/chi-tiet',
        method: 'POST',
        key: 'album-chi-tiet',
        data: {'id_album': idAlbum},
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được chi tiết album.');
    }
    // BE có thể trả { data: { item: {...} } } hoặc { data: {...} } —
    // khớp `albumDetailRes?.data?.item || albumDetailRes?.data` bên React.
    return _bocItem(kq.payload);
  }

  Future<Map<String, dynamic>> danhSachTepAnh({
    required String idAlbum,
    required int trang,
    int soLuong = 24,
    Map<String, dynamic>? boLoc,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/danh-sach-tep-anh',
        method: 'POST',
        key: 'album-danh-sach-tep-anh-$idAlbum-$trang',
        data: {
          'id_album': idAlbum,
          'trang': trang,
          'so_luong': soLuong,
          ...?boLoc,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách ảnh.');
    }
    return _bocData(kq.payload);
  }

  Future<Map<String, dynamic>> capNhat(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/cap-nhat',
        method: 'POST',
        key: 'album-cap-nhat',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Cập nhật album thất bại.');
    }
    return _bocData(kq.payload);
  }

  /// Đặt ảnh (đã có sẵn trong album, không phải ảnh mới upload) làm
  /// thumbnail. Khớp `AlbumApi.datThumbnail` bên React (gọi ngay khi bấm
  /// icon ngôi sao, không chờ nút Lưu).
  Future<Map<String, dynamic>> datThumbnail({
    required String idAlbum,
    required String idTepAnh,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/dat-thumbnail',
        method: 'POST',
        key: 'album-dat-thumbnail',
        data: {
          'id_album': idAlbum,
          'id_tep_anh': idTepAnh,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Đặt thumbnail thất bại.');
    }
    return _bocData(kq.payload);
  }

  /// Đổi mật khẩu truy cập album — tách API riêng với `capNhat`, khớp
  /// React (gọi tuần tự SAU khi capNhat thành công, lỗi ở bước này không
  /// làm hỏng việc đã lưu thông tin album, chỉ báo lỗi riêng).
  Future<Map<String, dynamic>> datMatKhau({
    required String idAlbum,
    required String matKhau,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/dat-mat-khau',
        method: 'POST',
        key: 'album-dat-mat-khau',
        data: {
          'id_album': idAlbum,
          'mat_khau': matKhau,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Đổi mật khẩu thất bại.');
    }
    return _bocData(kq.payload);
  }

  /// Lấy mật khẩu truy cập album (quyền ALBUM/dat_mat_khau).
  /// Trả về chuỗi mật khẩu, hoặc null nếu album chưa đặt.
  Future<String?> layMatKhau({required String idAlbum}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/lay-mat-khau',
        method: 'POST',
        key: 'album-lay-mat-khau',
        data: {'id_album': idAlbum},
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Lấy mật khẩu thất bại.');
    }

    final data = _bocData(kq.payload);
    final s = (data['mat_khau'] ?? data['password'])?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<void> doiTrangThai({
    required String idAlbum,
    required String trangThai,
    required void Function() onReloadCanThiet,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/trang-thai',
        method: 'POST',
        key: 'album-doi-trang-thai',
        data: {
          'id_album': idAlbum,
          'trang_thai': trangThai,
        },
      ),
    );

    notifyApiByCode(
      kq,
      options: ApiNotifyOptions(
        successMessage: 'Đã đổi trạng thái album',
        errorMessage: 'Đổi trạng thái thất bại',
        onSuccess: (_) => onReloadCanThiet(),
      ),
    );
  }

  Future<void> xoa({required String idAlbum}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/xoa',
        method: 'POST',
        key: 'album-xoa',
        data: {'id_album': idAlbum},
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Xoá album thất bại.');
    }
  }

  Future<Map<String, dynamic>> chiTietHeader({required String idAlbum}) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/chi-tiet-header',
        method: 'POST',
        key: 'album-chi-tiet-header',
        data: {'id_album': idAlbum},
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được thông tin album.');
    }
    return _bocItem(kq.payload);
  }

  /// Header album phục vụ SEO (public, không cần đăng nhập).
  Future<Map<String, dynamic>> chiTietHeaderSeo({
    required String idAlbum,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/public/album-seo/chi-tiet-header',
        method: 'POST',
        key: 'album-chi-tiet-header-seo',
        data: {'id_album': idAlbum},
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được thông tin album.');
    }
    return _bocItem(kq.payload);
  }

  /// Tải ảnh từ Drive vào album. [payload] giữ nguyên field BE yêu cầu.
  Future<Map<String, dynamic>> taiAnhTuDrive(
      Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/tai-anh-tu-drive',
        method: 'POST',
        key: 'album-tai-anh-tu-drive',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Tải ảnh từ Drive thất bại.');
    }
    return _bocData(kq.payload);
  }

  // ---------------------------------------------------------------------
  // Phân công / lịch phân công
  // ---------------------------------------------------------------------

  /// Lịch phân công theo khoảng ngày (yyyy-MM-dd, gồm cả 2 đầu).
  Future<List<Map<String, dynamic>>> phanCongLich({
    required String tuNgay,
    required String denNgay,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/lich',
        method: 'POST',
        key: 'album-phan-cong-lich',
        data: {'tu_ngay': tuNgay, 'den_ngay': denNgay},
      ),
    );

    if (!kq.isSuccess) {
      if (kq.isCanceled) throw const ApiException(message: '');
      throw kq.error ??
          const ApiException(message: 'Không tải được lịch phân công.');
    }
    return _danhSachTuPayload(kq.payload);
  }

  /// Danh sách phân công của 1 album.
  Future<List<Map<String, dynamic>>> phanCongDanhSach({
    required String idAlbum,
    Map<String, dynamic>? boLoc,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/danh-sach',
        method: 'POST',
        key: 'album-phan-cong-danh-sach-$idAlbum',
        data: {
          'id_album': idAlbum,
          ...?boLoc,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách phân công.');
    }
    return _danhSachTuPayload(kq.payload);
  }

  /// Phân công nhân viên phụ trách album (quyền LICH_PHAN_CONG/them).
  Future<Map<String, dynamic>> phanCong(Map<String, dynamic> payload) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong',
        method: 'POST',
        key: 'album-phan-cong',
        data: payload,
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Phân công thất bại.');
    }
    return _bocData(kq.payload);
  }

  /// Huỷ 1 phân công (quyền LICH_PHAN_CONG/xoa).
  Future<void> huyPhanCong({
    required String idAlbum,
    required String idAlbumPhuTrach,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/xoa',
        method: 'POST',
        key: 'album-huy-phan-cong',
        data: {
          'id_album': idAlbum,
          'id_album_phu_trach': idAlbumPhuTrach,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ?? const ApiException(message: 'Huỷ phân công thất bại.');
    }
  }

  /// Đặt 1 phân công làm người báo cáo chính (quyền LICH_PHAN_CONG/sua).
  Future<void> doiNguoiBaoCao({
    required String idAlbum,
    required String idAlbumPhuTrach,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/phan-cong/doi-nguoi-bao-cao',
        method: 'POST',
        key: 'album-doi-nguoi-bao-cao',
        data: {
          'id_album': idAlbum,
          'id_album_phu_trach': idAlbumPhuTrach,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Đổi người báo cáo thất bại.');
    }
  }
}
