import 'package:flutter/material.dart';

import '../../../../configs/app_colors.dart';

/// Tương ứng CardLichSuYeuCauChinhSua (DetailPanel.jsx): lịch sử yêu cầu
/// nhóm theo lần chỉnh sửa (mới nhất trước), thu gọn mặc định.
class LichSuYeuCauCard extends StatefulWidget {
  const LichSuYeuCauCard({
    super.key,
    required this.idTepAnh,
    required this.danhSach,
    required this.dangTai,
    required this.laAnhDaChinhSua,
    required this.fmt,
  });

  final String idTepAnh;
  final List<Map<String, dynamic>> danhSach;
  final bool dangTai;
  final bool laAnhDaChinhSua;
  final String Function(dynamic) fmt;

  @override
  State<LichSuYeuCauCard> createState() => _LichSuYeuCauCardState();
}

class _LichSuYeuCauCardState extends State<LichSuYeuCauCard> {
  bool _moRong = false;

  List<({int lan, List<Map<String, dynamic>> items})> _nhom() {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final y in widget.danhSach) {
      final k = (y['lan_chinh_sua'] as num?)?.toInt() ?? 0;
      (map[k] ??= []).add(y);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (lan: k, items: map[k]!)];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nhom = _nhom();
    // Tự mở rộng nếu nhóm mới nhất không chứa ảnh đang xem (giống React).
    final nhomDauCoAnhHienTai = nhom.isNotEmpty &&
        nhom.first.items
            .any((y) => y['tep_anh_id']?.toString() == widget.idTepAnh);
    final moRong = _moRong || (nhom.length > 1 && !nhomDauCoAnhHienTai);
    final hienThi = moRong ? nhom : nhom.take(1).toList();
    final soAn = nhom.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.history, size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('LỊCH SỬ YÊU CẦU CHỈNH SỬA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          Text('${widget.danhSach.length}',
              style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
        const SizedBox(height: 8),
        if (widget.dangTai && widget.danhSach.isEmpty)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (widget.danhSach.isEmpty)
          Text(
            widget.laAnhDaChinhSua
                ? 'Không xác định được lịch sử. Có thể ảnh đã chỉnh sửa được upload đồng loạt.'
                : 'Ảnh này chưa từng có yêu cầu chỉnh sửa nào.',
            style: TextStyle(fontSize: 11, color: cs.outline),
          ),
        for (final g in hienThi) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(g.lan > 0 ? 'SỬA LẦN ${g.lan}' : 'ẢNH GỐC',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: cs.outline)),
          ),
          for (final y in g.items) _item(context, y),
        ],
        if (soAn > 0)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _moRong = !_moRong),
              child: Text(moRong ? 'Thu gọn' : 'Xem thêm $soAn lần sửa trước'),
            ),
          ),
      ],
    );
  }

  Widget _item(BuildContext context, Map<String, dynamic> y) {
    final laHienTai = y['tep_anh_id']?.toString() == widget.idTepAnh;
    final tt = (y['trang_thai_yeu_cau'] ?? y['trang_thai'])?.toString();
    final ten = y['nguoi_yeu_cau_ho_ten']?.toString() ??
        (y['tai_khoan_khach_hang_id'] != null
            ? 'Khách hàng'
            : 'Nhân viên studio');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: laHienTai ? AppColors.primary.withOpacity(0.06) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: laHienTai
                ? AppColors.primary
                : Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(ten,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600))),
            Text(tt ?? '—',
                style: TextStyle(fontSize: 10, color: AppColors.primary)),
          ]),
          if ((y['noi_dung_yeu_cau']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(y['noi_dung_yeu_cau'].toString(),
                  style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 4),
          Text('Yêu cầu lúc ${widget.fmt(y['created_at'])}',
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          if (y['chot_luc'] != null)
            Text('Chốt lúc ${widget.fmt(y['chot_luc'])}',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          if (tt == 'hoan_thanh')
            Text('Hoàn thành ${widget.fmt(y['updated_at'])}',
                style: const TextStyle(fontSize: 10, color: Colors.green)),
        ],
      ),
    );
  }
}
