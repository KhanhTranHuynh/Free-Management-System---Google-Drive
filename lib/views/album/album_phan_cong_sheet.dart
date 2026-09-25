import 'dart:async';

import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_phan_cong_api.dart';
import 'album_events.dart';

/// Sheet "Phân công phụ trách" cho 1 album.
///
/// Convert từ `PhanCongAlbumModal` (React). Khác biệt chính so với bản
/// React:
/// - React dùng `useMutation` (react-query) + toast tự động qua
///   `notifyApiByCode`; ở đây gọi thẳng `AlbumPhanCongApi` trong
///   try/catch và tự hiện SnackBar, khớp pattern `AlbumEditSheet`.
/// - `queryClient.invalidateQueries(['album'])` → bắn
///   `AlbumEvents.instance` để `AlbumListView` tự `_taiLai()` (khớp cách
///   sheet Thêm/Sửa đang báo hiệu list cha refresh qua giá trị trả về
///   `pop(true)`; ở đây bắn thêm event vì phân công có thể đổi trong khi
///   sheet còn mở, không đợi đóng sheet mới refresh danh sách cha).
/// - `Autocomplete`/`DateTimePicker` (React) → bottom sheet chọn nhân
///   viên (tái dùng ý tưởng `_moChonKhachHang` bên `AlbumEditSheet`) và
///   `showDatePicker` + `showTimePicker` gộp lại.
class AlbumPhanCongSheet extends StatefulWidget {
  const AlbumPhanCongSheet({
    super.key,
    required this.album,
    required this.nhanVienOptions,
  });

  final Map<String, dynamic> album;
  final List<Map<String, dynamic>> nhanVienOptions;

  @override
  State<AlbumPhanCongSheet> createState() => _AlbumPhanCongSheetState();
}

class _AlbumPhanCongSheetState extends State<AlbumPhanCongSheet> {
  final _phanCongApi = AlbumPhanCongApi(ApiRequestManager.instance);

  String get _idAlbum => widget.album['id_album'].toString();

  // ----- danh sách phụ trách -----
  List<Map<String, dynamic>> _danhSachPhuTrach = [];
  bool _loadingDanhSach = true;
  String? _xacNhanHuyId;

  // ----- form thêm -----
  bool _hienFormThem = false;
  String? _tkNhanVienId;
  final _vaiTroController = TextEditingController();
  bool _laNguoiBaoCaoKhiThem = false;
  late DateTime _thoiGianBatDau;
  late DateTime _thoiGianKetThuc;

  // ----- trạng thái loading của từng action -----
  bool _dangGan = false;
  bool _dangHuy = false;
  bool _dangDoiNguoiBaoCao = false;

  @override
  void initState() {
    super.initState();
    _datLaiThoiGianMacDinh();
    unawaited(_taiDanhSach());
  }

  @override
  void dispose() {
    _vaiTroController.dispose();
    super.dispose();
  }

  void _datLaiThoiGianMacDinh() {
    final now = DateTime.now();
    _thoiGianBatDau = DateTime(now.year, now.month, now.day, 0, 0);
    _thoiGianKetThuc = DateTime(now.year, now.month, now.day, 23, 59);
  }

  // ---------------------------------------------------------------------
  // Options / label nhân viên
  // ---------------------------------------------------------------------

  String _labelNhanVien(String? id) {
    if (id == null) return '';
    final match = widget.nhanVienOptions.firstWhere(
      (o) =>
          (o['id_tai_khoan_nhan_vien']?.toString() ?? o['id']?.toString()) ==
          id,
      orElse: () => const {},
    );
    return match['ho_ten']?.toString() ??
        match['so_dien_thoai']?.toString() ??
        id;
  }

  /// Nhân viên CHƯA có trong danh sách phụ trách hiện tại — dùng cho
  /// dropdown "Thêm người" (khớp `nhanVienOptionsKhaDung` bên React).
  List<Map<String, dynamic>> get _nhanVienKhaDung {
    final daPhuTrachIds = _danhSachPhuTrach
        .map((e) => e['tai_khoan_nhan_vien_id']?.toString())
        .toSet();
    return widget.nhanVienOptions.where((o) {
      final id = (o['id_tai_khoan_nhan_vien'] ?? o['id'])?.toString();
      return id != null && !daPhuTrachIds.contains(id);
    }).toList();
  }

  String? get _loiThoiGian {
    if (_thoiGianKetThuc.isBefore(_thoiGianBatDau)) {
      return 'Thời gian kết thúc phải sau hoặc bằng thời gian bắt đầu';
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Tải danh sách phụ trách
  // ---------------------------------------------------------------------

  Future<void> _taiDanhSach() async {
    setState(() => _loadingDanhSach = true);
    try {
      final ds = await _phanCongApi.danhSach(idAlbum: _idAlbum);
      if (!mounted) return;
      setState(() => _danhSachPhuTrach = ds);
    } catch (_) {
      if (!mounted) return;
      setState(() => _danhSachPhuTrach = []);
      _thongBao('Không tải được danh sách phụ trách.');
    } finally {
      if (mounted) setState(() => _loadingDanhSach = false);
    }
  }

  void _thongBao(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetForm() {
    setState(() {
      _tkNhanVienId = null;
      _vaiTroController.clear();
      _laNguoiBaoCaoKhiThem = false;
      _datLaiThoiGianMacDinh();
      _hienFormThem = false;
    });
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _themPhuTrach() async {
    if (_tkNhanVienId == null || _loiThoiGian != null) return;

    setState(() => _dangGan = true);
    try {
      await _phanCongApi.ganPhuTrach(
        idAlbum: _idAlbum,
        taiKhoanNhanVienId: _tkNhanVienId!,
        vaiTroPhuTrach: _vaiTroController.text.trim().isEmpty
            ? null
            : _vaiTroController.text.trim(),
        laNguoiBaoCao: _laNguoiBaoCaoKhiThem ? true : null,
        thoiGianBatDau: _thoiGianBatDau.toIso8601String(),
        thoiGianKetThuc: _thoiGianKetThuc.toIso8601String(),
      );
      if (!mounted) return;
      _thongBao('Phân công thành công');
      AlbumEvents.instance.baoCanTaiLai(); // khớp invalidateQueries(['album'])
      _resetForm();
      unawaited(_taiDanhSach());
    } on ApiException catch (e) {
      _thongBao(e.message.isNotEmpty ? e.message : 'Phân công thất bại');
    } catch (_) {
      _thongBao('Phân công thất bại');
    } finally {
      if (mounted) setState(() => _dangGan = false);
    }
  }

  Future<void> _huy(String idAlbumPhuTrach) async {
    setState(() => _dangHuy = true);
    try {
      await _phanCongApi.huyPhuTrach(
        idAlbum: _idAlbum,
        idAlbumPhuTrach: idAlbumPhuTrach,
      );
      if (!mounted) return;
      _thongBao('Đã huỷ phân công');
      setState(() => _xacNhanHuyId = null);
      unawaited(_taiDanhSach());
    } on ApiException catch (e) {
      _thongBao(e.message.isNotEmpty ? e.message : 'Huỷ phân công thất bại');
    } catch (_) {
      _thongBao('Huỷ phân công thất bại');
    } finally {
      if (mounted) setState(() => _dangHuy = false);
    }
  }

  Future<void> _chonNguoiBaoCao(Map<String, dynamic> item) async {
    if (_dangDoiNguoiBaoCao || item['la_nguoi_bao_cao'] == true) return;

    setState(() => _dangDoiNguoiBaoCao = true);
    try {
      await _phanCongApi.doiNguoiBaoCao(
        idAlbum: _idAlbum,
        idAlbumPhuTrach: item['id_album_phu_trach'].toString(),
      );
      if (!mounted) return;
      _thongBao('Đã đặt làm người báo cáo');
      AlbumEvents.instance.baoCanTaiLai();
      unawaited(_taiDanhSach());
    } on ApiException catch (e) {
      _thongBao(
          e.message.isNotEmpty ? e.message : 'Đổi người báo cáo thất bại');
    } catch (_) {
      _thongBao('Đổi người báo cáo thất bại');
    } finally {
      if (mounted) setState(() => _dangDoiNguoiBaoCao = false);
    }
  }

  // ---------------------------------------------------------------------
  // Chọn nhân viên / thời gian
  // ---------------------------------------------------------------------

  Future<void> _moChonNhanVien() async {
    final options = _nhanVienKhaDung;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chọn nhân viên',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Expanded(
                    child: options.isEmpty
                        ? const Center(
                            child: Text('Đã phân công hết nhân viên'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final o = options[index];
                              final id =
                                  (o['id_tai_khoan_nhan_vien'] ?? o['id'])
                                      ?.toString();
                              final ten = o['ho_ten']?.toString() ??
                                  o['so_dien_thoai']?.toString() ??
                                  '--';
                              return ListTile(
                                title: Text(ten),
                                selected: id == _tkNhanVienId,
                                trailing: id == _tkNhanVienId
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () => Navigator.pop(ctx, id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (chosen != null) setState(() => _tkNhanVienId = chosen);
  }

  Future<void> _chonThoiGian({required bool laBatDau}) async {
    final hienTai = laBatDau ? _thoiGianBatDau : _thoiGianKetThuc;

    final ngay = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDate: hienTai,
    );
    if (ngay == null || !mounted) return;

    final gio = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(hienTai),
    );
    if (gio == null) return;

    final ketQua =
        DateTime(ngay.year, ngay.month, ngay.day, gio.hour, gio.minute);
    setState(() {
      if (laBatDau) {
        _thoiGianBatDau = ketQua;
      } else {
        _thoiGianKetThuc = ketQua;
      }
    });
  }

  String _formatThoiGian(dynamic isoStringOrDate) {
    DateTime? date;
    if (isoStringOrDate is DateTime) {
      date = isoStringOrDate;
    } else if (isoStringOrDate is String && isoStringOrDate.isNotEmpty) {
      date = DateTime.tryParse(isoStringOrDate);
    }
    if (date == null) return '';
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year} '
        '${pad(date.hour)}:${pad(date.minute)}';
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phân công phụ trách - ${widget.album['ten_album'] ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerDanhSach(),
                      const SizedBox(height: 12),
                      if (_hienFormThem) ...[
                        _formThem(),
                        const SizedBox(height: 16),
                      ],
                      _danhSachPhuTrachWidget(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerDanhSach() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.group_outlined,
              size: 18, color: Colors.amber.shade800),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Danh sách phụ trách',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                _loadingDanhSach
                    ? 'Đang tải...'
                    : '${_danhSachPhuTrach.length} người đang được phân công',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        FilledButton.tonal(
          onPressed: () => setState(() => _hienFormThem = !_hienFormThem),
          child: Text(_hienFormThem ? 'Huỷ' : '+ Thêm người'),
        ),
      ],
    );
  }

  Widget _formThem() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _moChonNhanVien,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Nhân viên *',
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: _nhanVienKhaDung.isEmpty
                    ? 'Đã phân công hết nhân viên'
                    : '-- Chọn nhân viên --',
              ),
              child: Text(
                _tkNhanVienId != null ? _labelNhanVien(_tkNhanVienId) : '',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vaiTroController,
            decoration: const InputDecoration(
              labelText: 'Vai trò phụ trách',
              hintText: 'vd: Editor chính (không bắt buộc)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _chonThoiGian(laBatDau: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Thời gian bắt đầu',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                    ),
                    child: Text(_formatThoiGian(_thoiGianBatDau)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _chonThoiGian(laBatDau: false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Thời gian kết thúc',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: _loiThoiGian,
                      suffixIcon:
                          const Icon(Icons.calendar_today_outlined, size: 16),
                    ),
                    child: Text(_formatThoiGian(_thoiGianKetThuc)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Đặt người này làm người báo cáo chính',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _laNguoiBaoCaoKhiThem,
                  onChanged: (v) =>
                      setState(() => _laNguoiBaoCaoKhiThem = v ?? false),
                ),
              ),
              FilledButton(
                onPressed:
                    (_dangGan || _tkNhanVienId == null || _loiThoiGian != null)
                        ? null
                        : _themPhuTrach,
                child: _dangGan
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Thêm vào danh sách'),
              ),
            ],
          ),
          if (_laNguoiBaoCaoKhiThem)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nếu album đang có người báo cáo khác, người đó sẽ bị bỏ '
                'vai trò này khi bạn bấm "Thêm".',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _danhSachPhuTrachWidget() {
    if (_loadingDanhSach) {
      return Column(
        children: List.generate(
          2,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: Colors.grey.shade200),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 10, width: 120, color: Colors.grey.shade200),
                      const SizedBox(height: 6),
                      Container(
                          height: 8, width: 80, color: Colors.grey.shade100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_danhSachPhuTrach.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border:
              Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.person_add_alt_outlined,
                size: 32, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Album chưa có ai phụ trách.',
                style: TextStyle(color: Colors.grey.shade500)),
            if (!_hienFormThem) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() => _hienFormThem = true),
                child: const Text('+ Thêm người ngay'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: _danhSachPhuTrach.map((item) {
        final ten = _labelNhanVien(item['tai_khoan_nhan_vien_id']?.toString());
        final laBaoCao = item['la_nguoi_bao_cao'] == true;
        final idPhuTrach = item['id_album_phu_trach'].toString();
        final dangXacNhanHuy = _xacNhanHuyId == idPhuTrach;
        final batDau = _formatThoiGian(item['thoi_gian_bat_dau']);
        final ketThuc = _formatThoiGian(item['thoi_gian_ket_thuc']);
        final coThoiGian = batDau.isNotEmpty || ketThuc.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: laBaoCao ? Colors.amber.withOpacity(0.05) : null,
            border: Border.all(
              color: laBaoCao
                  ? Colors.amber.withOpacity(0.3)
                  : Colors.grey.shade200,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(ten.isNotEmpty ? ten[0].toUpperCase() : '?'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ten,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (laBaoCao) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star,
                                    size: 11, color: Colors.amber.shade800),
                                const SizedBox(width: 2),
                                Text('Người báo cáo',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.amber.shade800)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['vai_tro_phu_trach']?.toString() ??
                          'Chưa có vai trò cụ thể',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coThoiGian)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 11, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              '${batDau.isEmpty ? '?' : batDau} → '
                              '${ketThuc.isEmpty ? '?' : ketThuc}',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!laBaoCao)
                IconButton(
                  tooltip: 'Đặt làm người báo cáo chính',
                  onPressed:
                      _dangDoiNguoiBaoCao ? null : () => _chonNguoiBaoCao(item),
                  icon: const Icon(Icons.star_outline, size: 18),
                ),
              if (dangXacNhanHuy) ...[
                TextButton(
                  onPressed: _dangHuy ? null : () => _huy(idPhuTrach),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: _dangHuy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác nhận'),
                ),
                TextButton(
                  onPressed: () => setState(() => _xacNhanHuyId = null),
                  child: const Text('Huỷ'),
                ),
              ] else
                IconButton(
                  tooltip: 'Huỷ phân công',
                  onPressed: () => setState(() => _xacNhanHuyId = idPhuTrach),
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey.shade400),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
