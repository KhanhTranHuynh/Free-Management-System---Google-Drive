import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

class AlbumApi {
  AlbumApi(this._manager);

  final ApiRequestManager _manager;

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

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      // Fallback phòng BE đổi cấu trúc, bỏ lớp 'data'.
      return map;
    }
    return const <String, dynamic>{};
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

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
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

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      // BE có thể trả { data: { item: {...} } } hoặc { data: {...} } —
      // khớp `albumDetailRes?.data?.item || albumDetailRes?.data` bên React.
      final inner = map['data'];
      if (inner is Map) {
        final innerMap = Map<String, dynamic>.from(inner);
        final item = innerMap['item'];
        if (item is Map) return Map<String, dynamic>.from(item);
        return innerMap;
      }
      return map;
    }
    return const <String, dynamic>{};
  }

  /// Danh sách ảnh (tệp ảnh) của 1 album — PHÂN TRANG, dùng để tải khối
  /// "Ảnh hiện có" trong sheet Sửa album theo từng trang (mặc định 24
  /// ảnh/lần) thay vì nạp nguyên danh sách ảnh trong 1 lần, tránh
  /// render/DOM quá nặng khi album có nhiều ảnh. Khớp
  /// `useAnhAlbumPhanTrang` bên React, gọi `AlbumApi.danhSachTepAnh`
  /// (`/album/danh-sach-tep-anh`).
  /// Trả về { du_lieu, phan_trang } — cùng khuôn dạng với [danhSach].
  Future<Map<String, dynamic>> danhSachTepAnh({
    required String idAlbum,
    required int trang,
    int soLuong = 24,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/album/danh-sach-tep-anh',
        method: 'POST',
        // key gắn theo id_album + trang — khớp cách React đặt key
        // `TepAnhDanhSach:${id_album}:${trang}` để mỗi trang là 1 request
        // độc lập, tải trang 2 không bị huỷ bởi/không huỷ request trang 1.
        key: 'album-danh-sach-tep-anh-$idAlbum-$trang',
        data: {
          'id_album': idAlbum,
          'trang': trang,
          'so_luong': soLuong,
        },
      ),
    );

    if (!kq.isSuccess) {
      throw kq.error ??
          const ApiException(message: 'Không tải được danh sách ảnh.');
    }

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
  }

  /// Cập nhật thông tin album (không bao gồm mật khẩu — xem [datMatKhau]).
  /// `xoaTepAnhIds` (nếu có) là các id ảnh hiện có cần xoá khi lưu, khớp
  /// field `xoa_tep_anh_ids` trong payload React.
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

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
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

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
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

    final raw = kq.payload;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return map;
    }
    return const <String, dynamic>{};
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
}
