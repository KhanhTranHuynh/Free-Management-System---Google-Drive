import 'dart:async';

/// Thay thế cho `window.dispatchEvent(SU_KIEN_ALBUM_CAN_TAI_LAI)` bên React.
/// Bất kỳ màn hình nào (modal chi tiết, phân công, ...) sau khi thay đổi dữ
/// liệu album có thể gọi `AlbumEvents.instance.baoCanTaiLai()` để các
/// AlbumListView đang mở tự tải lại, mà không cần truyền callback qua nhiều
/// tầng widget.
class AlbumEvents {
  AlbumEvents._();
  static final AlbumEvents instance = AlbumEvents._();

  final _controller = StreamController<void>.broadcast();

  Stream<void> get canTaiLai$ => _controller.stream;

  void baoCanTaiLai() => _controller.add(null);

  void dispose() => _controller.close();
}
