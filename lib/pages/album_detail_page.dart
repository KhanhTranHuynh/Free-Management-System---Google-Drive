import 'package:flutter/material.dart';

import '../views/album/detail/album_detail_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view (không chứa logic).
///
/// Không còn dùng AppBar — tiêu đề "Chi tiết album" nằm trong chính
/// AlbumDetailView (thanh tiêu đề tự vẽ, khớp cách các view/sheet khác tự
/// hiển thị tiêu đề của mình thay vì nhờ khung Scaffold/AppBar bên
/// ngoài).
///
/// FIX: không bọc `SafeArea` phía trên nữa — khung ngoài (PhotoFlow
/// shell) đã tự chừa khoảng cách với thanh trên cùng rồi, `SafeArea`
/// cộng thêm inset an toàn của thiết bị/trình duyệt vào padding-top của
/// header bên trong view khiến phần trên bị dư ra một khoảng trắng xấu.
class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({super.key, required this.idAlbum});

  final String idAlbum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: AlbumDetailView(idAlbum: idAlbum),
      ),
    );
  }
}
