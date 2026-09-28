import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Các API còn thiếu của màn chi tiết album (khớp descriptor bên React).
/// TODO endpoint: đối chiếu từng đường dẫn với src/api/descriptors/*.js.
class AlbumDetailApi {
  AlbumDetailApi(this._manager);

  final ApiRequestManager _manager;

  Future<dynamic> _goi(
    String url, {
    required String key,
    Map<String, dynamic>? data,
    required String loi,
  }) async {
    final kq = await _manager.send(
      ApiRequest(apiUrl: url, method: 'POST', key: key, data: data),
    );
    if (!kq.isSuccess) throw kq.error ?? ApiException(message: loi);
    return kq.payload;
  }

  dynamic _data(dynamic raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  Map<String, dynamic> _map(dynamic raw) {
    final d = _data(raw);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    var d = _data(raw);
    if (d is Map && d['du_lieu'] is List) d = d['du_lieu'];
    if (d is! List) return const [];
    return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// AlbumApi.layMatKhau -> data.mat_khau_truy_cap
  Future<String?> layMatKhau(String idAlbum) async {
    final raw = await _goi('/album/lay-mat-khau', // TODO endpoint
        key: 'album-lay-mat-khau',
        data: {'id_album': idAlbum},
        loi: 'Lấy mật khẩu thất bại.');
    return _map(raw)['mat_khau_truy_cap']?.toString();
  }

  /// TepAnhApi.danhSachDaChot
  Future<List<Map<String, dynamic>>> danhSachDaChot(String idAlbum) async {
    final raw = await _goi('/tep-anh/danh-sach-da-chot', // TODO endpoint
        key: 'tep-anh-da-chot-$idAlbum',
        data: {'id_album': idAlbum},
        loi: 'Không tải được danh sách ảnh đã chốt.');
    return _list(raw);
  }

  /// danhSachTepAnhDrive: payload = {id_album, ...bộ lọc}. Trả về list ảnh.
  Future<List<Map<String, dynamic>>> danhSachTepAnhDrive(
      Map<String, dynamic> payload) async {
    final raw = await _goi('/album/danh-sach-tep-anh-drive',
        key: 'tep-anh-drive-${payload['id_album']}',
        data: payload,
        loi: 'Không tải được danh sách ảnh Drive.');
    return _list(raw);
  }

  /// GoogleDriveApi.doiChieuAlbum
  /// -> { khop, thieu_trong_drive, du_trong_drive }
  Future<Map<String, dynamic>> doiChieuAlbum({
    required String idAlbum,
    required String duongDanDrive,
  }) async {
    final raw = await _goi('/google-drive/doi-chieu-album', // TODO endpoint
        key: 'gd-doi-chieu-album',
        data: {'id_album': idAlbum, 'duong_dan_drive': duongDanDrive},
        loi: 'Đối chiếu thất bại.');
    return _map(raw);
  }

  /// GoogleDriveApi.uploadKetQuaYeuCauChinhSua
  Future<Map<String, dynamic>> uploadKetQuaYeuCauChinhSua({
    required String idAlbum,
    required String duongDanDrive,
    int? lanChotThu,
  }) async {
    final raw = await _goi(
        '/google-drive/upload-ket-qua-yeu-cau-chinh-sua', // TODO endpoint
        key: 'gd-upload-ket-qua-hang-loat',
        data: {
          'id_album': idAlbum,
          'duong_dan_drive': duongDanDrive,
          if (lanChotThu != null) 'lan_chot_thu': lanChotThu,
        },
        loi: 'Upload kết quả từ Google Drive thất bại.');
    return _map(raw);
  }

  Future<void> taoBinhLuan({
    required String idTepAnh,
    required String noiDung,
    String? binhLuanChaId,
  }) async {
    await _goi('/binh-luan-anh/tao', // TODO endpoint
        key: 'bl-tao',
        data: {
          'tep_anh_id': idTepAnh,
          'noi_dung': noiDung,
          if (binhLuanChaId != null) 'binh_luan_cha_id': binhLuanChaId,
        },
        loi: 'Gửi bình luận thất bại.');
  }

  Future<void> xoaBinhLuan(String idBinhLuan) async {
    await _goi('/binh-luan-anh/xoa', // TODO endpoint
        key: 'bl-xoa',
        data: {'id_binh_luan_anh': idBinhLuan},
        loi: 'Xoá bình luận thất bại.');
  }

  Future<void> giaiQuyetBinhLuan(String idBinhLuan, bool daGiaiQuyet) async {
    await _goi('/binh-luan-anh/giai-quyet', // TODO endpoint
        key: 'bl-giai-quyet',
        data: {
          'id_binh_luan_anh': idBinhLuan,
          'da_giai_quyet': daGiaiQuyet,
        },
        loi: 'Cập nhật thất bại.');
  }
}
