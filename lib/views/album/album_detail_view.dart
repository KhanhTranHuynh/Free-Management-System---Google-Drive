import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_api.dart';

class AlbumDetailView extends StatefulWidget {
  const AlbumDetailView({super.key, required this.idAlbum});

  final String idAlbum;

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  final _api = AlbumApi(ApiRequestManager.instance);

  Map<String, dynamic>? _data;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _taiChiTiet();
  }

  Future<void> _taiChiTiet() async {
    if (widget.idAlbum.isEmpty) {
      setState(() => _error = 'Không tìm thấy album');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ⚠️ Đổi "chiTiet" thành đúng tên hàm lấy 1 album trong AlbumApi
      // của bạn (ví dụ: layChiTiet, timTheoId...). Nếu chưa có hàm này,
      // báo mình nội dung album_api.dart để mình thêm luôn.
      final body = await _api.chiTiet(idAlbum: widget.idAlbum);
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(
          (body['du_lieu'] as Map?) ?? body,
        );
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message.isNotEmpty ? e.message : 'Tải chi tiết thất bại';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _taiChiTiet,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_data == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return RefreshIndicator(
      onRefresh: _taiChiTiet,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _data!['ten_album']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Trạng thái: ${_data!['trang_thai'] ?? ''}'),
          // Thêm các field khác tuỳ theo dữ liệu API trả về ở đây.
        ],
      ),
    );
  }
}
