import 'dart:async';

import 'package:flutter/material.dart';

import '../../apis/api_request_manager.dart';
import '../../apis/models/api_exception.dart';
import '../../apis/services/album_api.dart';
import '../../apis/services/tai_khoan_khach_hang_api.dart';
import '../../components/app_images.dart';

class AlbumEditSheet extends StatefulWidget {
  const AlbumEditSheet({
    super.key,
    required this.album,
    required this.khachHangOptions,
  });

  /// Dữ liệu album lấy từ item trong danh sách (đủ dùng để dựng form ngay,
  /// không cần đợi `_taiChiTiet` xong mới hiện sheet — khớp UX React nơi
  /// modal mở ngay với `selectedItem`, chi tiết tải nền và đồng bộ sau).
  final Map<String, dynamic> album;

  /// Danh sách khách hàng đã tải sẵn ở AlbumListView — dùng làm gợi ý ban
  /// đầu trước khi autocomplete tự fetch theo từ khoá.
  final List<Map<String, dynamic>> khachHangOptions;

  @override
  State<AlbumEditSheet> createState() => _AlbumEditSheetState();
}

class _AlbumEditSheetState extends State<AlbumEditSheet> {
  // TODO: thay bằng config.MAU_SAC_MAC_DINH thật khi có file config Dart
  // tương ứng để đối chiếu — tạm giữ giá trị khớp màu primary phổ biến.
  static const String _mauSacMacDinh = '#3B82F6';
  static const int _khachHangPageSize = 100;
  static const Duration _khachHangDebounce = Duration(milliseconds: 350);
  // TODO: đối chiếu config.MIN_PASSWORD_LENGTH / MAX_PASSWORD_LENGTH thật.
  static const int _minPasswordLength = 6;
  static const int _maxPasswordLength = 32;

  final _api = AlbumApi(ApiRequestManager.instance);
  final _khachHangApi = TaiKhoanKhachHangApi(ApiRequestManager.instance);

  // ----- controllers form -----
  late final TextEditingController _tenAlbumController;
  late final TextEditingController _ngayChupController;
  late final TextEditingController _ghiChuController;
  late final TextEditingController _soLanChinhSuaController;
  late final TextEditingController _mauSacController;
  final _matKhauController = TextEditingController();
  final _duongDanDriveController = TextEditingController();
  final _timKiemKhachHangController = TextEditingController();

  // ----- state form -----
  Map<String, dynamic>? _khachHangDaChon;
  bool _khongGioiHanChinhSua = false;
  bool _choPhepTai = true;
  bool _choPhepXemKhongDangNhap = false;

  String? _loiTenAlbum;
  String? _loiSoLanChinhSua;
  String? _loiMauSac;
  String? _loiMatKhau;

  bool _dangTaiChiTiet = true;

  // ----- autocomplete khách hàng -----
  Timer? _debounceKhachHang;
  List<Map<String, dynamic>> _khachHangOptions = [];
  bool _khachHangLoading = false;
  int _khachHangTrang = 1;
  bool _khachHangHasMore = true;
  int _khachHangRequestSeq = 0;
  Map<String, dynamic>? _khachHangHienTaiPin;

  // ----- ảnh hiện có -----
  List<Map<String, dynamic>> _anhHienCo = [];
  final Set<String> _xoaTepAnhIds = {};
  String? _thumbnailOverrideId;
  bool _dangDatThumbnail = false;

  bool _dangLuu = false;

  String get _idAlbum => widget.album['id_album'].toString();

  @override
  void initState() {
    super.initState();
    final album = widget.album;

    _tenAlbumController =
        TextEditingController(text: album['ten_album']?.toString() ?? '');

    final ngayChupRaw = album['ngay_chup']?.toString();
    _ngayChupController = TextEditingController(
      text: (ngayChupRaw != null && ngayChupRaw.length >= 10)
          ? ngayChupRaw.substring(0, 10)
          : '',
    );

    final laKhongGioiHan = album['so_lan_chinh_sua_mien_phi'] == null;
    _khongGioiHanChinhSua = laKhongGioiHan;
    _soLanChinhSuaController = TextEditingController(
      text: laKhongGioiHan
          ? ''
          : (album['so_lan_chinh_sua_mien_phi']?.toString() ?? '3'),
    );

    _ghiChuController =
        TextEditingController(text: album['ghi_chu']?.toString() ?? '');
    _mauSacController = TextEditingController(
      text: album['mau_sac']?.toString() ?? _mauSacMacDinh,
    );
    _duongDanDriveController.text = album['duong_dan_drive']?.toString() ?? '';
    _choPhepTai = album['cho_phep_tai'] as bool? ?? true;
    _choPhepXemKhongDangNhap =
        album['cho_phep_xem_khong_dang_nhap'] as bool? ?? false;

    _khachHangHienTaiPin = _timOptionKhachHangHienTai(album);
    _khachHangDaChon = _khachHangHienTaiPin;
    _khachHangOptions =
        _khachHangHienTaiPin != null ? [_khachHangHienTaiPin!] : [];

    _anhHienCo =
        List<Map<String, dynamic>>.from(album['danh_sach_anh'] as List? ?? []);

    _timKiemKhachHangController.addListener(_onTimKiemKhachHangChanged);
    unawaited(_taiChiTiet());
    unawaited(_fetchKhachHang(reset: true));
  }

  @override
  void dispose() {
    _debounceKhachHang?.cancel();
    _timKiemKhachHangController.dispose();
    _tenAlbumController.dispose();
    _ngayChupController.dispose();
    _ghiChuController.dispose();
    _soLanChinhSuaController.dispose();
    _mauSacController.dispose();
    _matKhauController.dispose();
    _duongDanDriveController.dispose();
    super.dispose();
  }

  void _thongBao(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic>? _timOptionKhachHangHienTai(Map<String, dynamic> album) {
    final idKhachHang = album['tai_khoan_khach_hang_id'];
    if (idKhachHang == null) return null;
    final hoTen = album['ten_khach_hang']?.toString() ?? '';
    final sdt = album['so_dien_thoai_khach_hang']?.toString() ?? '';
    if (hoTen.isEmpty && sdt.isEmpty) return null;
    return {
      'label':
          hoTen.isNotEmpty ? (sdt.isNotEmpty ? '$hoTen - $sdt' : hoTen) : sdt,
      'value': idKhachHang,
    };
  }

  // ---------------------------------------------------------------------
  // Tải chi tiết album — khớp useQuery(['album','chi-tiet', idAlbum])
  // ---------------------------------------------------------------------

  Future<void> _taiChiTiet() async {
    try {
      final ct = await _api.chiTiet(idAlbum: _idAlbum);
      if (!mounted || ct.isEmpty) {
        if (mounted) setState(() => _dangTaiChiTiet = false);
        return;
      }

      setState(() {
        _dangTaiChiTiet = false;

        _tenAlbumController.text =
            ct['ten_album']?.toString() ?? _tenAlbumController.text;

        final ngayChupRaw = ct['ngay_chup']?.toString();
        if (ngayChupRaw != null && ngayChupRaw.length >= 10) {
          _ngayChupController.text = ngayChupRaw.substring(0, 10);
        }

        final laKhongGioiHan = ct['so_lan_chinh_sua_mien_phi'] == null;
        _khongGioiHanChinhSua = laKhongGioiHan;
        if (!laKhongGioiHan) {
          _soLanChinhSuaController.text =
              ct['so_lan_chinh_sua_mien_phi']?.toString() ?? '3';
        }

        _ghiChuController.text = ct['ghi_chu']?.toString() ?? '';
        _mauSacController.text = ct['mau_sac']?.toString() ?? _mauSacMacDinh;
        _duongDanDriveController.text = ct['duong_dan_drive']?.toString() ?? '';
        _choPhepTai = ct['cho_phep_tai'] as bool? ?? _choPhepTai;
        _choPhepXemKhongDangNhap =
            ct['cho_phep_xem_khong_dang_nhap'] as bool? ??
                _choPhepXemKhongDangNhap;

        if (ct['danh_sach_anh'] is List) {
          _anhHienCo =
              List<Map<String, dynamic>>.from(ct['danh_sach_anh'] as List);
        }

        final pin = _timOptionKhachHangHienTai(ct);
        if (pin != null && _khachHangHienTaiPin == null) {
          _khachHangHienTaiPin = pin;
          _khachHangDaChon ??= pin;
          final daCo = _khachHangOptions.any((o) => o['value'] == pin['value']);
          if (!daCo) _khachHangOptions = [pin, ..._khachHangOptions];
        }
      });
    } catch (_) {
      // Không tải được chi tiết -> vẫn giữ form dựng từ item trong danh
      // sách, không chặn thao tác sửa (khớp React chỉ log lỗi).
      if (mounted) setState(() => _dangTaiChiTiet = false);
    }
  }

  // ---------------------------------------------------------------------
  // Autocomplete khách hàng
  // ---------------------------------------------------------------------

  void _onTimKiemKhachHangChanged() {
    _debounceKhachHang?.cancel();
    _debounceKhachHang = Timer(_khachHangDebounce, () {
      unawaited(_fetchKhachHang(reset: true));
    });
  }

  Future<void> _fetchKhachHang({required bool reset}) async {
    final seq = ++_khachHangRequestSeq;
    final trang = reset ? 1 : _khachHangTrang + 1;
    setState(() => _khachHangLoading = true);

    try {
      final res = await _khachHangApi.layDanhSach(
        trang: trang,
        soLuong: _khachHangPageSize,
        timKiem: _timKiemKhachHangController.text.trim(),
      );
      if (seq != _khachHangRequestSeq || !mounted) return;

      final items =
          List<Map<String, dynamic>>.from(res['du_lieu'] as List? ?? []);
      final phanTrang = res['phan_trang'] as Map?;
      final tongSo = (phanTrang?['tong_so'] as num?)?.toInt() ?? 0;

      final mapped = items.map((item) {
        final hoTen = item['ho_ten']?.toString() ?? '';
        final sdt = item['so_dien_thoai']?.toString() ?? '';
        return <String, dynamic>{
          'label': hoTen.isNotEmpty
              ? (sdt.isNotEmpty ? '$hoTen - $sdt' : hoTen)
              : sdt,
          'value': item['id_tai_khoan_khach_hang'],
        };
      }).toList();

      setState(() {
        final base = reset ? <Map<String, dynamic>>[] : _khachHangOptions;
        final daCoSet = base.map((o) => o['value']).toSet();
        var merged = [
          ...base,
          ...mapped.where((o) => !daCoSet.contains(o['value'])),
        ];
        if (_khachHangHienTaiPin != null &&
            !merged.any((o) => o['value'] == _khachHangHienTaiPin!['value'])) {
          merged = [_khachHangHienTaiPin!, ...merged];
        }
        _khachHangOptions = merged;
        _khachHangHasMore = trang * _khachHangPageSize < tongSo;
        _khachHangTrang = trang;
      });
    } catch (_) {
      // im lặng bỏ qua, khớp catch-log-only bên React
    } finally {
      if (seq == _khachHangRequestSeq && mounted) {
        setState(() => _khachHangLoading = false);
      }
    }
  }

  Future<void> _moChonKhachHang() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chọn khách hàng',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _timKiemKhachHangController,
                        decoration: const InputDecoration(
                          hintText: 'Gõ tên hoặc số điện thoại...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >=
                                    n.metrics.maxScrollExtent - 200 &&
                                !_khachHangLoading &&
                                _khachHangHasMore) {
                              unawaited(_fetchKhachHang(reset: false));
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: _khachHangOptions.length +
                                (_khachHangLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _khachHangOptions.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final o = _khachHangOptions[index];
                              final daChon =
                                  o['value'] == _khachHangDaChon?['value'];
                              return ListTile(
                                title: Text(o['label']?.toString() ?? '--'),
                                trailing:
                                    daChon ? const Icon(Icons.check) : null,
                                selected: daChon,
                                onTap: () => Navigator.pop(sheetCtx, o),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    if (chosen != null) {
      setState(() => _khachHangDaChon = chosen);
    }
  }

  // ---------------------------------------------------------------------
  // Ảnh hiện có: đặt thumbnail / đánh dấu xoá
  // ---------------------------------------------------------------------

  bool _laThumbnail(Map<String, dynamic> anh) {
    if (_thumbnailOverrideId != null) {
      return anh['id_tep_anh']?.toString() == _thumbnailOverrideId;
    }
    return anh['la_thumbnail'] == true;
  }

  List<Map<String, dynamic>> get _anhHienCoDaSapXep {
    final list = [..._anhHienCo];
    list.sort((a, b) {
      final ta = _laThumbnail(a);
      final tb = _laThumbnail(b);
      if (ta == tb) return 0;
      return ta ? -1 : 1;
    });
    return list;
  }

  Future<void> _datThumbnail(Map<String, dynamic> anh) async {
    if (_dangDatThumbnail) return;
    final idTepAnh = anh['id_tep_anh']?.toString();
    if (idTepAnh == null) return;

    setState(() => _dangDatThumbnail = true);
    try {
      await _api.datThumbnail(idAlbum: _idAlbum, idTepAnh: idTepAnh);
      if (!mounted) return;
      setState(() => _thumbnailOverrideId = idTepAnh);
      _thongBao('Đã đặt thumbnail');
    } on ApiException catch (e) {
      _thongBao(e.message.isNotEmpty ? e.message : 'Đặt thumbnail thất bại');
    } catch (_) {
      _thongBao('Đặt thumbnail thất bại');
    } finally {
      if (mounted) setState(() => _dangDatThumbnail = false);
    }
  }

  void _toggleXoaAnh(String idTepAnh) {
    setState(() {
      if (_xoaTepAnhIds.contains(idTepAnh)) {
        _xoaTepAnhIds.remove(idTepAnh);
      } else {
        _xoaTepAnhIds.add(idTepAnh);
      }
    });
  }

  void _xemAnhPhongTo(String? url) {
    if (url == null || url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: AnhMang(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Validate + Lưu
  // ---------------------------------------------------------------------

  bool _validate() {
    String? loiTen;
    String? loiSoLan;
    String? loiMau;
    String? loiMatKhau;

    if (_tenAlbumController.text.trim().isEmpty) {
      loiTen = 'Vui lòng nhập tên album';
    }

    if (!_khongGioiHanChinhSua) {
      final soLan = int.tryParse(_soLanChinhSuaController.text.trim());
      if (soLan != null && soLan < 0) {
        loiSoLan = 'Không được nhỏ hơn 0';
      }
    }

    final mauSac = _mauSacController.text.trim();
    if (mauSac.isNotEmpty && !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(mauSac)) {
      loiMau = 'Mã màu không hợp lệ';
    }

    final mk = _matKhauController.text.trim();
    if (mk.isNotEmpty) {
      if (mk.length < _minPasswordLength) {
        loiMatKhau = 'Mật khẩu phải có ít nhất $_minPasswordLength ký tự';
      } else if (mk.length > _maxPasswordLength) {
        loiMatKhau = 'Mật khẩu không được quá $_maxPasswordLength ký tự';
      }
    }

    setState(() {
      _loiTenAlbum = loiTen;
      _loiSoLanChinhSua = loiSoLan;
      _loiMauSac = loiMau;
      _loiMatKhau = loiMatKhau;
    });

    return loiTen == null &&
        loiSoLan == null &&
        loiMau == null &&
        loiMatKhau == null;
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (!_validate()) return;

    setState(() => _dangLuu = true);
    try {
      final soLanText = _soLanChinhSuaController.text.trim();
      final payload = <String, dynamic>{
        'id_album': _idAlbum,
        'ten_album': _tenAlbumController.text.trim(),
        'tai_khoan_khach_hang_id': _khachHangDaChon?['value'],
        'ngay_chup': _ngayChupController.text.trim().isEmpty
            ? null
            : _ngayChupController.text.trim(),
        'so_lan_chinh_sua_mien_phi': _khongGioiHanChinhSua
            ? null
            : (soLanText.isEmpty ? null : int.tryParse(soLanText)),
        'ghi_chu': _ghiChuController.text.trim().isEmpty
            ? null
            : _ghiChuController.text.trim(),
        'mau_sac': _mauSacController.text.trim().isEmpty
            ? null
            : _mauSacController.text.trim(),
        'cho_phep_tai': _choPhepTai,
        'cho_phep_xem_khong_dang_nhap': _choPhepXemKhongDangNhap,
        if (_xoaTepAnhIds.isNotEmpty) 'xoa_tep_anh_ids': _xoaTepAnhIds.toList(),
        // duong_dan_drive: readonly trên form (khớp React `disabled`),
        // không gửi lại để tránh vô tình ghi đè giá trị BE đang giữ.
      };

      final capNhatRes = await _api.capNhat(payload);

      final mkMoi = _matKhauController.text.trim();
      if (mkMoi.isNotEmpty) {
        try {
          await _api.datMatKhau(idAlbum: _idAlbum, matKhau: mkMoi);
        } on ApiException catch (e) {
          _thongBao(
            e.message.isNotEmpty
                ? 'Đã cập nhật thông tin album, nhưng đổi mật khẩu thất bại: ${e.message}'
                : 'Đã cập nhật thông tin album, nhưng đổi mật khẩu thất bại.',
          );
        }
      }

      if (!mounted) return;
      _thongBao('Cập nhật album thành công');
      Navigator.of(context).pop(capNhatRes.isNotEmpty ? capNhatRes : true);
    } on ApiException catch (e) {
      _thongBao(e.message.isNotEmpty ? e.message : 'Cập nhật album thất bại');
    } catch (_) {
      _thongBao('Cập nhật album thất bại');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  Future<void> _chonNgayChup() async {
    final ket = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (ket == null) return;
    setState(() {
      _ngayChupController.text =
          '${ket.year.toString().padLeft(4, '0')}-${ket.month.toString().padLeft(2, '0')}-${ket.day.toString().padLeft(2, '0')}';
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
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
                  Text('Cập nhật album',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_dangTaiChiTiet)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _muc1ThongTin(),
                      const SizedBox(height: 24),
                      _muc2AnhHienCo(),
                      const SizedBox(height: 24),
                      _muc3QuyenTruyCap(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _dangLuu ? null : () => Navigator.of(context).pop(),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _dangLuu ? null : _luu,
                      child: _dangLuu
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeading(int index, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text('$index. $title',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _muc1ThongTin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(1, 'Thông tin album'),
        TextField(
          controller: _tenAlbumController,
          decoration: InputDecoration(
            labelText: 'Tên album *',
            errorText: _loiTenAlbum,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ngayChupController,
          readOnly: true,
          onTap: _chonNgayChup,
          decoration: const InputDecoration(
            labelText: 'Ngày chụp',
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _moChonKhachHang,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Khách hàng'),
            child: Text(
              _khachHangDaChon?['label']?.toString() ?? 'Gõ để tìm khách hàng',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _duongDanDriveController,
          readOnly: true,
          enabled: false,
          decoration: const InputDecoration(
            labelText: 'Đường dẫn Drive (dùng để upload ảnh)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ghiChuController,
          maxLines: 2,
          decoration:
              const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _soLanChinhSuaController,
                    keyboardType: TextInputType.number,
                    enabled: !_khongGioiHanChinhSua,
                    decoration: InputDecoration(
                      labelText: 'Số lần chỉnh sửa',
                      errorText: _loiSoLanChinhSua,
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Không giới hạn số lần chỉnh sửa miễn phí',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _khongGioiHanChinhSua,
                    onChanged: (v) =>
                        setState(() => _khongGioiHanChinhSua = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _mauSacController,
                decoration: InputDecoration(
                  labelText: 'Màu lịch',
                  errorText: _loiMauSac,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _parseMau(_mauSacController.text),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _muc2AnhHienCo() {
    final list = _anhHienCoDaSapXep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(2, 'Ảnh trong album'),
        if (list.isEmpty)
          Text(
            'Album chưa có ảnh nào.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          Text(
            'Ảnh hiện có (${list.length}) — bấm ảnh để xem, biểu tượng sao để đặt thumbnail, thùng rác để đánh dấu xoá.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final anh = list[index];
              final idTepAnh = anh['id_tep_anh']?.toString() ?? '';
              final seXoa = _xoaTepAnhIds.contains(idTepAnh);
              final laThumb = _laThumbnail(anh);
              final url = anh['duong_dan_anh']?.toString() ??
                  anh['thumbnail_view']?.toString();

              return Opacity(
                opacity: seXoa ? 0.5 : 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: seXoa ? null : () => _xemAnhPhongTo(url),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: seXoa
                                  ? Colors.red
                                  : laThumb
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                              width: laThumb ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: url != null
                              ? AnhMang(url: url, fit: BoxFit.cover)
                              : const ColoredBox(color: Colors.black12),
                        ),
                      ),
                    ),
                    if (!seXoa && !laThumb)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: _miniIconButton(
                          icon: Icons.star_outline,
                          onTap: _dangDatThumbnail
                              ? null
                              : () => _datThumbnail(anh),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _miniIconButton(
                        icon: seXoa ? Icons.undo : Icons.delete_outline,
                        color: seXoa ? null : Colors.red,
                        onTap: () => _toggleXoaAnh(idTepAnh),
                      ),
                    ),
                    if (laThumb && !seXoa)
                      const Positioned(
                        bottom: 4,
                        left: 4,
                        right: 4,
                        child: _NhanNho(text: 'Thumbnail'),
                      ),
                    if (seXoa)
                      const Positioned(
                        bottom: 4,
                        left: 4,
                        right: 4,
                        child: _NhanNho(text: 'Sẽ xoá', mauNen: Colors.red),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_xoaTepAnhIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_xoaTepAnhIds.length} ảnh sẽ bị xoá khi lưu',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: 8),
        // TODO: khối "Thêm ảnh mới / thay ảnh" — chưa convert, xem ghi chú
        // đầu file. Tạm để nút vô hiệu hoá kèm giải thích cho người dùng.
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Thêm ảnh mới (đang phát triển)'),
        ),
      ],
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color ?? Colors.white),
      ),
    );
  }

  Widget _muc3QuyenTruyCap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(3, 'Cài đặt quyền truy cập'),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Đường dẫn (link) của album không đổi khi cập nhật ở đây. Các '
            'thiết lập bên dưới chỉ quyết định ai được xem link đó và xem '
            'được những gì.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cho phép truy cập công khai'),
          subtitle: Text(
            _choPhepXemKhongDangNhap
                ? 'Bất kỳ ai có link chỉ được xem, không cần nhập mật khẩu.'
                : 'Khách chưa đăng nhập phải nhập đúng mật khẩu mới xem được link.',
            style: const TextStyle(fontSize: 12),
          ),
          value: _choPhepXemKhongDangNhap,
          onChanged: (v) => setState(() => _choPhepXemKhongDangNhap = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cho phép tải ảnh'),
          subtitle: const Text(
            'Khách hàng có thể tải ảnh gốc về thiết bị.',
            style: TextStyle(fontSize: 12),
          ),
          value: _choPhepTai,
          onChanged: (v) => setState(() => _choPhepTai = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _matKhauController,
          decoration: InputDecoration(
            labelText: 'Mật khẩu truy cập album',
            hintText: 'Để trống nếu không muốn đổi mật khẩu',
            errorText: _loiMatKhau,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Không bắt buộc — để trống nghĩa là giữ nguyên mật khẩu hiện tại.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _parseMau(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final s = hex.replaceAll('#', '');
    final value = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
    return value == null ? Colors.grey : Color(value);
  }
}

class _NhanNho extends StatelessWidget {
  const _NhanNho({required this.text, this.mauNen});

  final String text;
  final Color? mauNen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color:
            (mauNen ?? Theme.of(context).colorScheme.primary).withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 9),
      ),
    );
  }
}
