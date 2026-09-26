import 'package:flutter/material.dart';

import '../configs/app_colors.dart';
import 'app_modal.dart';
import 'chip_loc.dart';

/// 1 lựa chọn trong dropdown "Sắp xếp theo" của [showModalLocSapXep].
///
/// [value] là chuỗi định danh tự do do trang gọi tự quy ước (vd gộp cả
/// cột + chiều sắp xếp thành `"ho_ten:ASC"`) — component không quan tâm
/// cấu trúc bên trong [value], chỉ dùng nó để biết đang chọn lựa chọn
/// nào và trả nguyên văn lại qua callback khi người dùng đổi.
class TuyChonSapXep {
  const TuyChonSapXep({required this.value, required this.label});

  final String value;
  final String label;
}

/// 1 lựa chọn (1 chip) trong 1 [NhomLoc].
class TuyChonLoc {
  const TuyChonLoc({
    this.value,
    required this.label,
    this.soDem,
    this.mau,
    this.soDemDangNgoac = false,
  });

  /// `null` = lựa chọn "Tất cả".
  final String? value;
  final String label;
  final int? soDem;
  final Color? mau;
  final bool soDemDangNgoac;
}

/// 1 nhóm lọc (vd "Vai trò", "Trạng thái"). Component vẽ MỖI nhóm trên
/// đúng 1 dòng: nhãn bên trái + các [ChipLoc] cuộn ngang bên phải — có
/// bao nhiêu nhóm thì có bấy nhiêu dòng (2 nhóm lọc = 2 dòng), thay vì
/// mỗi nhóm chiếm nhiều dòng (nhãn riêng 1 dòng rồi Wrap chip xuống các
/// dòng dưới) như cách vẽ tay trước đây.
class NhomLoc {
  const NhomLoc({
    required this.tieuDe,
    required this.options,
    required this.dangChon,
    required this.onChon,
  });

  final String tieuDe;
  final List<TuyChonLoc> options;

  /// Giá trị ([TuyChonLoc.value]) đang được chọn trong nhóm này.
  final String? dangChon;
  final ValueChanged<String?> onChon;
}

/// Modal "Lọc & sắp xếp" DÙNG CHUNG cho mọi danh sách trong app (Nhân
/// viên, Nhật ký hệ thống, ...). Gồm:
/// - 1 dropdown "Sắp xếp theo" (nếu truyền [tuyChonSapXep]) — gộp cột +
///   chiều sắp xếp vào chung 1 lựa chọn dạng select.
/// - N [NhomLoc], mỗi nhóm 1 dòng.
/// - Nút "Xoá lọc" / "Xong".
///
/// Component tự quản lý state hiển thị (chip nào đang tô, dropdown đang
/// chọn gì) để phản hồi ngay khi bấm, đồng thời gọi callback tương ứng
/// để trang gọi tự lọc lại dữ liệu của nó — trang gọi KHÔNG cần tự dựng
/// StatefulBuilder/setModalState như cách làm cũ.
Future<void> showModalLocSapXep(
  BuildContext context, {
  required String title,
  List<TuyChonSapXep>? tuyChonSapXep,
  String? sapXepDangChon,
  ValueChanged<String?>? onDoiSapXep,
  required List<NhomLoc> nhomLoc,
  required VoidCallback onXoaLoc,
}) {
  return showAppModal(
    context,
    title: title,
    type: AppModalType.bottomSheet,
    builder: (ctx) => _NoiDungLocSapXep(
      tuyChonSapXep: tuyChonSapXep,
      sapXepDangChon: sapXepDangChon,
      onDoiSapXep: onDoiSapXep,
      nhomLoc: nhomLoc,
      onXoaLoc: onXoaLoc,
    ),
  );
}

class _NoiDungLocSapXep extends StatefulWidget {
  const _NoiDungLocSapXep({
    required this.tuyChonSapXep,
    required this.sapXepDangChon,
    required this.onDoiSapXep,
    required this.nhomLoc,
    required this.onXoaLoc,
  });

  final List<TuyChonSapXep>? tuyChonSapXep;
  final String? sapXepDangChon;
  final ValueChanged<String?>? onDoiSapXep;
  final List<NhomLoc> nhomLoc;
  final VoidCallback onXoaLoc;

  @override
  State<_NoiDungLocSapXep> createState() => _NoiDungLocSapXepState();
}

class _NoiDungLocSapXepState extends State<_NoiDungLocSapXep> {
  // State cục bộ chỉ để tô sáng chip/dropdown ngay khi bấm — nguồn dữ
  // liệu thật (list, đếm số...) vẫn nằm ở trang gọi, trang gọi tự lọc
  // lại qua callback bên dưới.
  late String? _sapXepDangChon = widget.sapXepDangChon;
  late final List<String?> _dangChonTheoNhom =
      widget.nhomLoc.map((n) => n.dangChon).toList();

  void _chonSapXep(String? value) {
    setState(() => _sapXepDangChon = value);
    widget.onDoiSapXep?.call(value);
  }

  void _chonLoc(int nhomIndex, String? value) {
    setState(() => _dangChonTheoNhom[nhomIndex] = value);
    widget.nhomLoc[nhomIndex].onChon(value);
  }

  void _xoaLoc() {
    setState(() {
      _sapXepDangChon =
          (widget.tuyChonSapXep == null || widget.tuyChonSapXep!.isEmpty)
              ? null
              : widget.tuyChonSapXep!.first.value;
      for (var i = 0; i < _dangChonTheoNhom.length; i++) {
        _dangChonTheoNhom[i] = null;
      }
    });
    widget.onXoaLoc();
  }

  Widget _dongNhom(int index, NhomLoc nhom) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${nhom.tieuDe}:',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tc in nhom.options) ...[
                    ChipLoc(
                      label: tc.label,
                      soDem: tc.soDem,
                      mau: tc.mau,
                      soDemDangNgoac: tc.soDemDangNgoac,
                      dangChon: _dangChonTheoNhom[index] == tc.value,
                      onTap: () => _chonLoc(index, tc.value),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coDropdownSapXep =
        widget.tuyChonSapXep != null && widget.tuyChonSapXep!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (coDropdownSapXep) ...[
          DropdownButtonFormField<String>(
            initialValue: _sapXepDangChon,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sắp xếp theo',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              for (final tc in widget.tuyChonSapXep!)
                DropdownMenuItem(value: tc.value, child: Text(tc.label)),
            ],
            onChanged: _chonSapXep,
          ),
          const SizedBox(height: 18),
        ],
        for (var i = 0; i < widget.nhomLoc.length; i++)
          _dongNhom(i, widget.nhomLoc[i]),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _xoaLoc,
                child: const Text('Xoá lọc'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Xong'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
