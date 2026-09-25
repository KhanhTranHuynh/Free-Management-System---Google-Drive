import 'dart:async';

import 'package:flutter/material.dart';

import '../../../apis/api_request_manager.dart';
import '../../../apis/models/api_exception.dart';
import '../../../apis/services/album_api.dart';
import '../../../apis/services/binh_luan_anh_api.dart';
import '../../../apis/services/tep_anh_api.dart';
import '../../../apis/services/yeu_cau_chinh_sua_api.dart';

class AlbumDetailView extends StatefulWidget {
  const AlbumDetailView({super.key, required this.idAlbum});

  final String idAlbum;

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  static const _tabs = ['anh', 'yeu_cau', 'chot_yeu_cau', 'da_sua'];
  static const _tabLabels = {
    'anh': 'Tất cả ảnh',
    'yeu_cau': 'Chưa chốt',
    'chot_yeu_cau': 'Đã chốt',
    'da_sua': 'Đã chỉnh sửa',
  };

  final _albumApi = AlbumApi(ApiRequestManager.instance);
  final _tepAnhApi = TepAnhApi(ApiRequestManager.instance);
  final _ycsApi = YeuCauChinhSuaApi(ApiRequestManager.instance);
  final _blApi = BinhLuanAnhApi(ApiRequestManager.instance);

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _requestController = TextEditingController();
  Timer? _debounce;

  // ----- filter / tab -----
  String _activeTab = 'anh';
  String _daChonFilter = 'tat_ca'; // tat_ca | da_chon | chua_chon
  String _trangThaiAnhFilter = 'tat_ca';
  String _timKiem = '';

  // ----- header -----
  Map<String, dynamic>? _album;
  Map<String, dynamic> _thongKe = {};
  bool _isLoadingHeader = false;
  String? _errorHeader;

  // ----- danh sách ảnh -----
  List<Map<String, dynamic>> _anh = [];
  int _trang = 1;
  int _tongSo = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorAnh;
  int _requestId = 0;

  // ----- lựa chọn -----
  final Set<String> _idTepAnhDaChon = {};
  final Set<String> _dangDoiChon = {}; // đang gọi API chọn/bỏ chọn

  bool get _hasMore => _anh.length < _tongSo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_taiHeader());
    unawaited(_taiDanhSachAnh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildBoLoc() {
    final filter = <String, dynamic>{};
    if (_activeTab == 'anh') {
      if (_daChonFilter != 'tat_ca')
        filter['da_chon'] = _daChonFilter == 'da_chon';
      if (_trangThaiAnhFilter != 'tat_ca') {
        filter['trang_thai_anh'] = _trangThaiAnhFilter;
      }
    }
    if (_activeTab == 'yeu_cau') {
      filter['yeu_cau_chinh_sua'] = 'da_yeu_cau';
      filter['trang_thai_anh'] = 'da_yeu_cau';
    }
    if (_activeTab == 'chot_yeu_cau') {
      filter['yeu_cau_chinh_sua'] = 'da_yeu_cau';
      filter['trang_thai_anh'] = 'da_chot';
    }
    if (_activeTab == 'da_sua') {
      filter['version_anh'] = 'da_sua';
    }
    if (_timKiem.trim().isNotEmpty) {
      filter['tu_khoa'] = _timKiem.trim();
    }
    return filter;
  }

  // ---------------------------------------------------------------------
  // Tải dữ liệu
  // ---------------------------------------------------------------------

  Future<void> _taiHeader() async {
    setState(() {
      _isLoadingHeader = true;
      _errorHeader = null;
    });
    try {
      final body = await _albumApi.chiTietHeader(idAlbum: widget.idAlbum);
      if (!mounted) return;
      setState(() {
        _album = body;
        _thongKe = Map<String, dynamic>.from(body['thong_ke'] as Map? ?? {});
        _isLoadingHeader = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorHeader = e.message.isNotEmpty
            ? e.message
            : 'Không tải được thông tin album.';
        _isLoadingHeader = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorHeader = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _isLoadingHeader = false;
      });
    }
  }

  Future<void> _taiDanhSachAnh({bool append = false}) async {
    final id = ++_requestId;
    final trangCanTai = append ? _trang + 1 : 1;

    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
      _errorAnh = null;
    });

    try {
      final body = await _albumApi.danhSachTepAnh(
        idAlbum: widget.idAlbum,
        trang: trangCanTai,
        soLuong: 24,
        boLoc: _buildBoLoc(),
      );
      if (!mounted || id != _requestId) return;

      final list =
          List<Map<String, dynamic>>.from(body['du_lieu'] as List? ?? []);
      final phanTrang =
          Map<String, dynamic>.from(body['phan_trang'] as Map? ?? {});

      setState(() {
        _tongSo = (phanTrang['tong_so'] as num?)?.toInt() ?? list.length;
        _anh = append ? [..._anh, ...list] : list;
        _trang = trangCanTai;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _errorAnh = e.message.isNotEmpty ? e.message : 'Không tải được ảnh.';
        if (!append) {
          _anh = [];
          _tongSo = 0;
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _errorAnh = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _lamMoiTatCa() async {
    _idTepAnhDaChon.clear();
    await Future.wait([_taiHeader(), _taiDanhSachAnh()]);
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore || !_hasMore || _errorAnh != null) return;
    final vuotNguong = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300;
    if (vuotNguong) unawaited(_taiDanhSachAnh(append: true));
  }

  // ---------------------------------------------------------------------
  // Sự kiện
  // ---------------------------------------------------------------------

  void _onChangeTab(String tab) {
    if (tab == _activeTab) return;
    setState(() {
      _activeTab = tab;
      _trangThaiAnhFilter = 'tat_ca';
      _idTepAnhDaChon.clear();
      _searchController.clear();
      _timKiem = '';
    });
    unawaited(_taiDanhSachAnh());
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _timKiem = value);
      unawaited(_taiDanhSachAnh());
    });
  }

  void _toggleChonAnh(Map<String, dynamic> anh) {
    final idTepAnh = anh['id_tep_anh'].toString();
    if (_dangDoiChon.contains(idTepAnh)) return;
    if (anh['duoc_phep_chon'] != true) return;
    final dangChon = anh['duoc_khach_chon'] == true;
    unawaited(_doiChonAnh(idTepAnh, !dangChon));
  }

  Future<void> _doiChonAnh(String idTepAnh, bool chonMoi) async {
    setState(() => _dangDoiChon.add(idTepAnh));
    try {
      await _tepAnhApi.chonTepAnh(
        idAlbum: widget.idAlbum,
        idTepAnh: [idTepAnh],
        chon: chonMoi,
      );
      if (!mounted) return;
      setState(() {
        _anh = _anh
            .map((a) => a['id_tep_anh'].toString() == idTepAnh
                ? {...a, 'duoc_khach_chon': chonMoi}
                : a)
            .toList();
        if (chonMoi) {
          _idTepAnhDaChon.add(idTepAnh);
        } else {
          _idTepAnhDaChon.remove(idTepAnh);
        }
        _dangDoiChon.remove(idTepAnh);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _dangDoiChon.remove(idTepAnh));
      _thongBao('Cập nhật lựa chọn thất bại');
    }
  }

  Future<void> _chonBoChonTatCa(bool chonMoi) async {
    try {
      await _tepAnhApi.chonBoChonTepAnhTatCa(
          idAlbum: widget.idAlbum, chon: chonMoi);
      if (!mounted) return;
      setState(() {
        _anh = _anh.map((a) => {...a, 'duoc_khach_chon': chonMoi}).toList();
        if (chonMoi) {
          _idTepAnhDaChon.addAll(_anh.map((a) => a['id_tep_anh'].toString()));
        } else {
          _idTepAnhDaChon.clear();
        }
      });
      await _taiDanhSachAnh();
    } catch (_) {
      _thongBao('Cập nhật lựa chọn thất bại');
    }
  }

  Future<void> _guiYeuCauHangLoat() async {
    final noiDung = _requestController.text.trim();
    if (_idTepAnhDaChon.isEmpty) return;
    try {
      await _ycsApi.taoHangLoat(
        idAlbum: widget.idAlbum,
        tepAnhIds: _idTepAnhDaChon.take(50).toList(),
        noiDung: noiDung,
      );
      if (!mounted) return;
      _requestController.clear();
      setState(() => _idTepAnhDaChon.clear());
      _thongBao('Đã gửi yêu cầu chỉnh sửa');
      await _lamMoiTatCa();
    } catch (_) {
      _thongBao('Gửi yêu cầu chỉnh sửa thất bại');
    }
  }

  Future<void> _huyYeuCauHangLoat() async {
    if (_idTepAnhDaChon.isEmpty) return;
    try {
      await _ycsApi.xoaTheoTepAnh(tepAnhIds: _idTepAnhDaChon.take(50).toList());
      if (!mounted) return;
      setState(() => _idTepAnhDaChon.clear());
      _thongBao('Đã hủy yêu cầu chỉnh sửa');
      await _lamMoiTatCa();
    } catch (_) {
      _thongBao('Hủy yêu cầu chỉnh sửa thất bại');
    }
  }

  Future<void> _chotYeuCauDaChon() async {
    if (_idTepAnhDaChon.isEmpty) return;
    try {
      await _ycsApi.chotTheoTepAnh(tepAnhIds: _idTepAnhDaChon.toList());
      if (!mounted) return;
      setState(() => _idTepAnhDaChon.clear());
      _thongBao('Chốt yêu cầu chỉnh sửa thành công');
      await _lamMoiTatCa();
    } catch (_) {
      _thongBao('Chốt yêu cầu chỉnh sửa thất bại');
    }
  }

  Future<void> _xacNhanChotTatCaAlbum() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chốt tất cả yêu cầu chỉnh sửa'),
        content: Text('Chốt yêu cầu chỉnh sửa cho ${_tongSo} ảnh đã yêu cầu?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý')),
        ],
      ),
    );
    if (dongY != true) return;
    try {
      await _ycsApi.chotTatCaTheoAlbum(idAlbum: widget.idAlbum);
      _thongBao('Chốt tất cả yêu cầu chỉnh sửa thành công');
      await _lamMoiTatCa();
    } catch (_) {
      _thongBao('Chốt tất cả yêu cầu chỉnh sửa thất bại');
    }
  }

  Future<void> _xacNhanXoaCungTatCa() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy yêu cầu chưa chốt'),
        content: const Text(
            'Xóa vĩnh viễn tất cả yêu cầu chỉnh sửa chưa chốt của album này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (dongY != true) return;
    try {
      await _ycsApi.xoaCungChuaChotTheoAlbum(idAlbum: widget.idAlbum);
      _thongBao('Đã xóa vĩnh viễn các yêu cầu chỉnh sửa chưa chốt');
      await _lamMoiTatCa();
    } catch (_) {
      _thongBao('Xóa tất cả yêu cầu chỉnh sửa thất bại');
    }
  }

  void _thongBao(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _moChiTietAnh(Map<String, dynamic> anh) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (context, scrollController) => _AnhDetailSheet(
          idAlbum: widget.idAlbum,
          anhBanDau: anh,
          tepAnhApi: _tepAnhApi,
          ycsApi: _ycsApi,
          blApi: _blApi,
          scrollController: scrollController,
          onThayDoi: _lamMoiTatCa,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_errorHeader != null && _album == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorHeader!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _taiHeader, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _lamMoiTatCa,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildTabs()),
              SliverToBoxAdapter(child: _buildFilterBar()),
              _buildBody(),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        ),
        if (_activeTab == 'anh' && _idTepAnhDaChon.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    if (_isLoadingHeader && _album == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final album = _album ?? {};
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              album['ten_album']?.toString() ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Khách hàng: ${album['khach_hang']?['ho_ten'] ?? '—'}'),
            Text(
                'Trạng thái: ${album['trang_thai_hien_thi'] ?? album['trang_thai'] ?? '—'}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('Tất cả: ${_thongKe['tong_so_hinh'] ?? 0}'),
                Text(
                    'Chưa chốt: ${_thongKe['tong_so_yeu_cau_chua_chot'] ?? 0}'),
                Text('Đã chốt: ${_thongKe['tong_so_yeu_cau_da_chot'] ?? 0}'),
                Text('Đã sửa: ${_thongKe['tong_hinh_da_sua'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _tabs.map((tab) {
          final active = tab == _activeTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_tabLabels[tab] ?? tab),
              selected: active,
              onSelected: (_) => _onChangeTab(tab),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Tìm tên file ảnh...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 8),
          if (_activeTab == 'anh')
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _daChonFilter,
                    decoration: const InputDecoration(
                      labelText: 'Ảnh đã chọn',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'tat_ca', child: Text('Tất cả')),
                      DropdownMenuItem(
                          value: 'da_chon', child: Text('Đã chọn')),
                      DropdownMenuItem(
                          value: 'chua_chon', child: Text('Chưa chọn')),
                    ],
                    onChanged: (v) {
                      setState(() => _daChonFilter = v ?? 'tat_ca');
                      unawaited(_taiDanhSachAnh());
                    },
                  ),
                ),
              ],
            ),
          if (_activeTab == 'yeu_cau')
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _xacNhanChotTatCaAlbum,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Chốt tất cả'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _xacNhanXoaCungTatCa,
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Hủy tất cả'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_anh.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: Text(_errorAnh ?? 'Không có ảnh nào.')),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _AnhTile(
            anh: _anh[index],
            dangDoiChon:
                _dangDoiChon.contains(_anh[index]['id_tep_anh'].toString()),
            onTap: () => _moChiTietAnh(_anh[index]),
            onToggleChon: () => _toggleChonAnh(_anh[index]),
          ),
          childCount: _anh.length,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('${_idTepAnhDaChon.length} ảnh'),
                const Spacer(),
                TextButton(
                  onPressed: () => _chonBoChonTatCa(true),
                  child: const Text('Chọn tất cả'),
                ),
                TextButton(
                  onPressed: () => _chonBoChonTatCa(false),
                  child: const Text('Bỏ chọn'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _requestController,
                    decoration: const InputDecoration(
                      hintText: 'Yêu cầu chỉnh sửa...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _guiYeuCauHangLoat,
                  icon: const Icon(Icons.add),
                  tooltip: 'Thêm yêu cầu',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnhTile extends StatelessWidget {
  const _AnhTile({
    required this.anh,
    required this.dangDoiChon,
    required this.onTap,
    required this.onToggleChon,
  });

  final Map<String, dynamic> anh;
  final bool dangDoiChon;
  final VoidCallback onTap;
  final VoidCallback onToggleChon;

  @override
  Widget build(BuildContext context) {
    final duocChon = anh['duoc_khach_chon'] == true;
    final duocPhepChon = anh['duoc_phep_chon'] == true;
    final url = anh['duong_dan_preview']?.toString() ??
        anh['duong_dan_drive_xem']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.grey.shade200,
              child: url != null
                  ? Image.network(url, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 32, color: Colors.grey),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: _Badge(
                text: (anh['lan_sua_hien_tai'] ?? 0) == 0
                    ? 'Ảnh gốc'
                    : 'Ver ${anh['lan_sua_hien_tai']}',
              ),
            ),
            if (duocPhepChon)
              Positioned(
                right: 6,
                bottom: 6,
                child: InkWell(
                  onTap: dangDoiChon ? null : onToggleChon,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: duocChon
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black54,
                    child: dangDoiChon
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            duocChon ? Icons.check : Icons.check,
                            size: 14,
                            color: Colors.white70,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Sheet chi tiết 1 ảnh — thông tin, yêu cầu chỉnh sửa, bình luận.
/// Đơn giản hoá so với DetailPanel.jsx (bỏ so sánh trước/sau, ảnh liên
/// quan, upload kết quả qua Drive — có thể bổ sung sau nếu cần).
class _AnhDetailSheet extends StatefulWidget {
  const _AnhDetailSheet({
    required this.idAlbum,
    required this.anhBanDau,
    required this.tepAnhApi,
    required this.ycsApi,
    required this.blApi,
    required this.scrollController,
    required this.onThayDoi,
  });

  final String idAlbum;
  final Map<String, dynamic> anhBanDau;
  final TepAnhApi tepAnhApi;
  final YeuCauChinhSuaApi ycsApi;
  final BinhLuanAnhApi blApi;
  final ScrollController scrollController;
  final Future<void> Function() onThayDoi;

  @override
  State<_AnhDetailSheet> createState() => _AnhDetailSheetState();
}

class _AnhDetailSheetState extends State<_AnhDetailSheet> {
  final _yeuCauController = TextEditingController();
  final _binhLuanController = TextEditingController();

  Map<String, dynamic>? _chiTiet;
  bool _isLoading = true;
  bool _dangGuiYeuCau = false;
  bool _dangGuiBinhLuan = false;

  String get _idTepAnh => widget.anhBanDau['id_tep_anh'].toString();

  @override
  void initState() {
    super.initState();
    unawaited(_taiChiTiet());
  }

  @override
  void dispose() {
    _yeuCauController.dispose();
    _binhLuanController.dispose();
    super.dispose();
  }

  Future<void> _taiChiTiet() async {
    setState(() => _isLoading = true);
    try {
      final body = await widget.tepAnhApi.chiTiet(idTepAnh: _idTepAnh);
      if (!mounted) return;
      setState(() {
        _chiTiet = body;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guiYeuCau() async {
    final noiDung = _yeuCauController.text.trim();
    if (noiDung.isEmpty || _dangGuiYeuCau) return;
    setState(() => _dangGuiYeuCau = true);
    try {
      await widget.ycsApi.taoHangLoat(
        idAlbum: widget.idAlbum,
        tepAnhIds: [_idTepAnh],
        noiDung: noiDung,
      );
      _yeuCauController.clear();
      await _taiChiTiet();
      await widget.onThayDoi();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _dangGuiYeuCau = false);
    }
  }

  Future<void> _guiBinhLuan() async {
    final noiDung = _binhLuanController.text.trim();
    if (noiDung.isEmpty || _dangGuiBinhLuan) return;
    setState(() => _dangGuiBinhLuan = true);
    try {
      await widget.blApi.taoBinhLuan(idTepAnh: _idTepAnh, noiDung: noiDung);
      _binhLuanController.clear();
      await _taiChiTiet();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _dangGuiBinhLuan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yeuCau = List<Map<String, dynamic>>.from(
        _chiTiet?['yeu_cau_chinh_sua'] as List? ?? []);
    final binhLuan =
        List<Map<String, dynamic>>.from(_chiTiet?['binh_luan'] as List? ?? []);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chi tiết ảnh',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(widget.anhBanDau['ten_tep_goc']?.toString() ?? ''),
          const Divider(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text('Yêu cầu chỉnh sửa (${yeuCau.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...yeuCau.map((y) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(y['noi_dung_yeu_cau']?.toString() ?? '—'),
                    subtitle:
                        Text('Trạng thái: ${y['trang_thai_yeu_cau'] ?? '—'}'),
                  ),
                )),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yeuCauController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập yêu cầu chỉnh sửa...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _dangGuiYeuCau ? null : _guiYeuCau,
                  icon: _dangGuiYeuCau
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Bình luận (${binhLuan.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...binhLuan.map((bl) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(bl['noi_dung']?.toString() ?? ''),
                    subtitle: Text(
                        bl['nguoi_binh_luan_ho_ten']?.toString() ?? 'Ẩn danh'),
                  ),
                )),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _binhLuanController,
                    decoration: const InputDecoration(
                      hintText: 'Viết bình luận...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _dangGuiBinhLuan ? null : _guiBinhLuan,
                  icon: _dangGuiBinhLuan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
