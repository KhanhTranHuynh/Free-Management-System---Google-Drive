import '../api_notify.dart';
import '../api_request_manager.dart';
import '../models/api_exception.dart';

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
