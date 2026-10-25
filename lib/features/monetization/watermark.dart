import 'package:image/image.dart' as img;
import '../../core/constants.dart';

/// Stamps a small footer band onto a raster page (used for JPEG export).
/// PDF exports render the same text as a footer in pdf_generator.dart.
img.Image stampWatermark(img.Image im) {
  final band = (im.height * 0.035).round().clamp(28, 60).toInt();
  img.fillRect(im,
      x1: 0, y1: im.height - band, x2: im.width, y2: im.height,
      color: img.ColorRgba8(255, 255, 255, 230));
  img.drawString(im, watermarkText,
      font: img.arial24, y: im.height - band + (band - 24) ~/ 2,
      color: img.ColorRgb8(107, 114, 128));
  return im;
}
