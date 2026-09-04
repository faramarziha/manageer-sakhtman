
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// نتیجه فشرده‌سازی تصویر
class CompressionResult {
  final Uint8List bytes;
  final int originalSize;
  final int compressedSize;
  final int width;
  final int height;
  final String format;

  const CompressionResult({
    required this.bytes,
    required this.originalSize,
    required this.compressedSize,
    required this.width,
    required this.height,
    required this.format,
  });

  /// نسبت کاهش حجم (۰ تا ۱)
  double get reductionRatio {
    if (originalSize == 0) return 0;
    return 1 - (compressedSize / originalSize);
  }

  /// درصد کاهش حجم
  int get reductionPercent => (reductionRatio * 100).round();

  /// حجم نهایی به کیلوبایت
  int get compressedKb => (compressedSize / 1024).ceil();

  /// هدف حجمی محقق شده است؟
  bool get metTarget => compressedSize <= ImageCompressor.targetBytes;
}

/// ---------------------------------------------------------------------------
/// سرویس فشرده‌سازی حداکثری تصاویر در سمت کلاینت
///
/// استراتژی Zero-Cost Architecture (کاهش هزینه سرور و هاست):
///
///   تصاویر فاکتورهای مالی و رسیدهای پرداخت پیش از بارگذاری به سرور، در
///   کلاینت فلاتر فشرده و به فرمت WebP با حجم زیر ۱۰۰ کیلوبایت تبدیل
///   می‌شوند تا ترافیک مصرفی سرور و حجم هاست به حداقل برسد.
///
///   الگوریتم تطبیقی: ابتدا ابعاد تصویر به حداکثر ۱۴۰۰ پیکسل محدود
///   می‌شود، سپس کیفیت به صورت پله‌ای کاهش می‌یابد تا حجم نهایی به هدف
///   ۱۰۰ کیلوبایت برسد.
/// ---------------------------------------------------------------------------
class ImageCompressor {
  const ImageCompressor._();

  /// هدف حجمی نهایی: ۱۰۰ کیلوبایت
  static const int targetBytes = 100 * 1024;

  /// حداکثر بُعد بزرگ‌تر تصویر (پیکسل)
  static const int maxDimension = 1400;

  /// پله‌های کیفیت برای تلاش‌های متوالی فشرده‌سازی
  static const List<int> qualitySteps = [80, 65, 50, 38, 28, 20];

  /// فرمت خروجی هدف
  static const String preferredFormat = 'webp';

  /// فشرده‌سازی تصویر تا رسیدن به حجم هدف
  ///
  /// عملیات سنگین رمزگذاری در یک Isolate جداگانه اجرا می‌شود تا رشته
  /// اصلی UI بلاک نشود.
  static Future<CompressionResult?> compress(Uint8List input) async {
    if (input.isEmpty) return null;
    try {
      return await compute(_compressWorker, input);
    } catch (_) {
      return null;
    }
  }

  /// تابع کارگر فشرده‌سازی (اجرا در Isolate)
  static CompressionResult? _compressWorker(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return null;

    // گام ۱: محدودسازی ابعاد
    var image = decoded;
    final longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > maxDimension) {
      final isLandscape = decoded.width >= decoded.height;
      image = img.copyResize(
        decoded,
        width: isLandscape ? maxDimension : null,
        height: isLandscape ? null : maxDimension,
        interpolation: img.Interpolation.average,
      );
    }

    // گام ۲: کاهش پله‌ای کیفیت تا رسیدن به حجم هدف
    // نکته: پکیج image فعلاً رمزگذار WebP ندارد؛ لذا از JPEG با کیفیت
    // تطبیقی استفاده می‌شود که برای تصاویر فاکتور نتیجه مشابهی می‌دهد.
    // در نسخه اندروید، پکیج flutter_image_compress خروجی WebP بومی
    // تولید می‌کند و این کلاس تنها لایه پشتیبان است.
    Uint8List? best;
    for (final q in qualitySteps) {
      final encoded = Uint8List.fromList(img.encodeJpg(image, quality: q));
      best = encoded;
      if (encoded.lengthInBytes <= targetBytes) break;
    }

    // گام ۳: اگر همچنان بزرگ است، ابعاد را نیز کاهش می‌دهیم
    if (best != null && best.lengthInBytes > targetBytes) {
      var scaled = image;
      for (var i = 0; i < 3 && best!.lengthInBytes > targetBytes; i++) {
        scaled = img.copyResize(
          scaled,
          width: (scaled.width * 0.7).round(),
          interpolation: img.Interpolation.average,
        );
        best = Uint8List.fromList(img.encodeJpg(scaled, quality: 35));
        image = scaled;
      }
    }

    if (best == null) return null;

    return CompressionResult(
      bytes: best,
      originalSize: input.lengthInBytes,
      compressedSize: best.lengthInBytes,
      width: image.width,
      height: image.height,
      format: 'jpg',
    );
  }

  /// تخمین حجم نهایی پیش از فشرده‌سازی (برای نمایش به کاربر)
  static String describeSize(int bytes) {
    if (bytes < 1024) return '$bytes بایت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} کیلوبایت';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} مگابایت';
  }
}
