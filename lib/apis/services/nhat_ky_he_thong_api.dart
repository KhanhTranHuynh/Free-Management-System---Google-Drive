import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

/// Gọi API nhật ký hệ thống qua [ApiRequestManager].
/// Khớp descriptor bên React: GET /nhat-ky-he-thong/danh-sach.
///
/// QUAN TRỌNG: kq.payload trả về NGUYÊN envelope đầy đủ từ BE:
///   { data: { du_lieu: [...], phan_trang: {...} }, message, code,
///     status, token, rToken }
/// -> Phải bóc thêm 1 lớp 'data' mới lấy đúng { du_lieu, phan_trang }.
/// (Đã xác nhận bằng data thật trả về từ BE ngày 24/09/2026.)
///
/// Chỉ có 1 thao tác duy nhất — xem danh sách (read-only, không có
/// thêm/sửa/xoá). Không truyền sap_xep vì BE cố định
/// ORDER BY created_at DESC (xem comment bên React).
///
/// TODO(tạm thời): các dòng `print(...)` bên dưới là log debug để xác minh
/// runtime thực tế nếu vẫn còn lỗi sau fix này. Xoá khi đã xác nhận ổn.
class NhatKyHeThongApi {
  NhatKyHeThongApi(this._manager);

  final ApiRequestManager _manager;

  Future<Map<String, dynamic>> layDanhSach({
    int trang = 1,
    int soLuong = 10,
    String? tenBang,
    String? hanhDong,
  }) async {
    final kq = await _manager.send(
      ApiRequest(
        apiUrl: '/nhat-ky-he-thong/danh-sach',
        method: 'GET',
        key: 'nhat-ky-he-thong-danh-sach',
        params: {
          'trang': trang,
          'so_luong': soLuong,
          if (tenBang != null && tenBang.isNotEmpty) 'ten_bang': tenBang,
          if (hanhDong != null && hanhDong.isNotEmpty) 'hanh_dong': hanhDong,
        },
      ),
    );

    // ignore: avoid_print
    print('[NhatKyHeThongApi] isSuccess=${kq.isSuccess} '
        'isCanceled=${kq.isCanceled}');

    if (!kq.isSuccess) {
      if (!kq.isCanceled) {
        notifyApiByCode(
          kq,
          options: const ApiNotifyOptions(
            silentOnSuccess: true,
            errorMessage: 'Không tải được nhật ký hệ thống',
          ),
        );
      }
      throw kq.error ??
          const ApiException(message: 'Không tải được nhật ký hệ thống.');
    }

    final raw = kq.payload;
    // ignore: avoid_print
    print('[NhatKyHeThongApi] payload type=${raw.runtimeType} raw=$raw');

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'];
      if (inner is Map) {
        final result = Map<String, dynamic>.from(inner);
        // ignore: avoid_print
        print('[NhatKyHeThongApi] unwrapped -> '
            'du_lieu length=${(result['du_lieu'] as List?)?.length}, '
            'phan_trang=${result['phan_trang']}');
        return result;
      }
      // Fallback phòng trường hợp BE đổi cấu trúc, bỏ lớp 'data'.
      // ignore: avoid_print
      print('[NhatKyHeThongApi] no nested "data" key, using top-level map');
      return map;
    }
    return const <String, dynamic>{};
  }
}
