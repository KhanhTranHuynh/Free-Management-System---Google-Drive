import 'package:flutter/material.dart';

import '../views/album/album_list_view.dart';

/// Page mỏng: chỉ dựng khung + ghép view (không chứa logic).
class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: const SafeArea(child: AlbumListView()),
    );
  }
}
