import 'package:flutter/material.dart';

// =============================================================================
// LỚP 1: RESOLVE URL — quyết định URL cuối cùng cần tải (có resize hay
// không, theo cú pháp của từng nguồn ảnh). Đây là hàm THUẦN (không UI),
// nên rất dễ test riêng và dễ mở rộng.
//
// Khi có nguồn ảnh mới (CDN riêng, S3 presigned URL, Cloudinary...), chỉ
// cần thêm 1 case mới ở `_urlAnhCuoiCungMacDinh`, KHÔNG cần sửa gì trong
// widget AnhMang hay ở các trang đang gọi AnhMang.
// =============================================================================

/// Trả về URL đã gắn tham số resize phù hợp với domain của [urlGoc].
/// Domain không xác định -> giữ nguyên URL gốc (an toàn, không đoán mò).
String _urlAnhCuoiCungMacDinh(String urlGoc, int? kichThuoc) {
  if (kichThuoc == null) return urlGoc;
  final uri = Uri.tryParse(urlGoc);
  if (uri == null) return urlGoc;

  // --- Google Drive / googleusercontent (lh3...) ---
  // Cú pháp: "https://lh3.googleusercontent.com/d/{id}=w2000" — hậu tố
  // "=wNNN" ở CUỐI url, không phải query chuẩn "?key=value". Cắt phần
  // "=..." cũ (nếu có) rồi nối lại theo chiều rộng mong muốn.
  if (uri.host.endsWith('googleusercontent.com')) {
    final base = urlGoc.split('=').first;
    return '$base=w$kichThuoc';
  }

  // --- Thêm nguồn ảnh mới tại đây khi cần, ví dụ: ---
  // if (uri.host == 'cdn.yourdomain.com') {
  //   return urlGoc.replaceAll(RegExp(r'\?.*$'), '') + '?w=$kichThuoc';
  // }
  // if (uri.host.contains('cloudinary.com')) {
  //   return urlGoc.replaceFirst('/upload/', '/upload/w_$kichThuoc/');
  // }

  return urlGoc;
}

// =============================================================================
// LỚP 2: RENDER — quyết định cách THỰC SỰ tải & vẽ ảnh lên màn hình.
// Hiện dùng Image.network (built-in, không cần thêm package). Sau này
// muốn đổi sang package `cached_network_image` (có cache đĩa thật) thì chỉ
// sửa đúng hàm `_taiAnhMacDinh` này — mọi chỗ đang gọi AnhMang trong app
// tự động được lợi, không cần sửa từng trang.
// =============================================================================

Widget _taiAnhMacDinh({
  required String url,
  double? width,
  double? height,
  required BoxFit fit,
  required WidgetBuilder khungTai,
  required WidgetBuilder khungLoi,
}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    loadingBuilder: (context, anh, tienTrinh) {
      if (tienTrinh == null) return anh;
      return khungTai(context);
    },
    errorBuilder: (context, error, stackTrace) => khungLoi(context),
  );

  // --- Khi đổi sang cached_network_image, thay toàn bộ thân hàm bằng: ---
  // return CachedNetworkImage(
  //   imageUrl: url,
  //   width: width,
  //   height: height,
  //   fit: fit,
  //   placeholder: (context, _) => khungTai(context),
  //   errorWidget: (context, _, __) => khungLoi(context),
  // );
}

/// Widget hiển thị ảnh từ URL dùng chung cho toàn app — thay cho việc gọi
/// `Image.network(...)` rải rác ở nhiều trang (card album, avatar nhân
/// viên, avatar khách hàng...).
///
/// Cách dùng:
/// ```dart
/// AnhMang(url: album['anh_bia'], width: 160, height: 120, boGoc: 12)
/// AnhMang.avatar(url: nhanVien['anh_dai_dien'], duongKinh: 40)
/// ```
///
/// Đổi cơ chế trong tương lai — KHÔNG cần sửa nơi gọi AnhMang:
///  - Thêm nguồn ảnh mới / đổi cách resize -> sửa `_urlAnhCuoiCungMacDinh`
///    (hoặc gán `AnhMang.resolverUrl = hamMoi` ở `main()` nếu muốn đổi
///    hẳn logic mà không sửa file này).
///  - Đổi thư viện tải ảnh (vd: cached_network_image) -> sửa
///    `_taiAnhMacDinh` (hoặc gán `AnhMang.taiAnh = hamMoi` ở `main()`).
class AnhMang extends StatelessWidget {
  const AnhMang({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.boGoc = 0,
    this.hinhDang = BoxShape.rectangle,
    this.fit = BoxFit.cover,
    this.kichThuocResize,
  });

  /// Tạo sẵn dạng avatar tròn — dùng cho nhân viên, khách hàng.
  factory AnhMang.avatar({
    Key? key,
    required String? url,
    double duongKinh = 40,
  }) {
    return AnhMang(
      key: key,
      url: url,
      width: duongKinh,
      height: duongKinh,
      hinhDang: BoxShape.circle,
      // *2 để ảnh nét trên màn hình mật độ điểm ảnh cao (Retina).
      kichThuocResize: (duongKinh * 2).round(),
    );
  }

  /// URL ảnh gốc. Có thể null/rỗng — sẽ tự hiện fallback.
  final String? url;
  final double? width;
  final double? height;

  /// Bo góc — chỉ áp dụng khi [hinhDang] là [BoxShape.rectangle].
  final double boGoc;
  final BoxShape hinhDang;
  final BoxFit fit;

  /// Nếu set, sẽ nhờ [resolverUrl] gắn tham số resize vào URL gốc. Mặc
  /// định (không set): nếu có [width]/[height], tự suy ra từ cạnh lớn
  /// nhất * 2.
  final int? kichThuocResize;

  // --- 2 điểm mở rộng toàn cục, ghi đè được từ bên ngoài (vd trong
  // main() lúc khởi động app) mà không cần sửa file này ---
  static String Function(String urlGoc, int? kichThuoc) resolverUrl =
      _urlAnhCuoiCungMacDinh;

  static Widget Function({
    required String url,
    double? width,
    double? height,
    required BoxFit fit,
    required WidgetBuilder khungTai,
    required WidgetBuilder khungLoi,
  }) taiAnh = _taiAnhMacDinh;

  @override
  Widget build(BuildContext context) {
    final rawUrl = url;
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return _khungLoi(context);
    }

    final kichThuoc = kichThuocResize ??
        (width != null || height != null
            ? ((width ?? height)! * 2).round()
            : null);
    final urlCuoi = resolverUrl(rawUrl, kichThuoc);

    final child = taiAnh(
      url: urlCuoi,
      width: width,
      height: height,
      fit: fit,
      khungTai: _khungTai,
      khungLoi: _khungLoi,
    );

    if (hinhDang == BoxShape.circle) {
      return ClipOval(
        child: SizedBox(width: width, height: height, child: child),
      );
    }
    if (boGoc > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(boGoc),
        child: child,
      );
    }
    return child;
  }

  Widget _khungTai(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _khungLoi(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        size: (width ?? height ?? 40) * 0.4,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
