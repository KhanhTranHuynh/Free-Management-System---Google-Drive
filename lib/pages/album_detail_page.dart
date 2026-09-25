import 'package:flutter/material.dart';

import '../views/album/album_detail_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view (không chứa logic).
class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({super.key, required this.idAlbum});

  final String idAlbum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết album')),
      body: SafeArea(child: AlbumDetailView(idAlbum: idAlbum)),
    );
  }
}
