import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../core/models.dart';

const List<double> fullFrame = [0, 0, 1, 0, 1, 1, 0, 1];

class RenderParams {
  final Uint8List srcBytes;
  final int maxSide, quality;
  final List<double> corners;
  final FilterType filter;
  final double brightness, contrast;
  const RenderParams({
    required this.srcBytes,
    this.maxSide = 1000,
    this.quality = 85,
    this.corners = fullFrame,
    this.filter = FilterType.original,
    this.brightness = 0,
    this.contrast = 0,
  });
}

class RenderResult {
  final Uint8List bytes;
  final int width, height;
  const RenderResult(this.bytes, this.width, this.height);
}

/// All pixel work runs in a background isolate so the UI stays at full frame rate.
class ImageEngine {
  static Future<RenderResult> render(RenderParams p) => compute(_render, p);
  static Future<List<double>> detectCorners(Uint8List bytes) =>
      compute(_detect, bytes);
}

RenderResult _render(RenderParams p) {
  var im = img.decodeImage(p.srcBytes);
  if (im == null) throw StateError('Cannot decode image data');
  im = img.bakeOrientation(im);
  if (math.max(im.width, im.height) > p.maxSide) {
    im = im.width >= im.height
        ? img.copyResize(im,
            width: p.maxSide, interpolation: img.Interpolation.linear)
        : img.copyResize(im,
            height: p.maxSide, interpolation: img.Interpolation.linear);
  }
  if (!listEquals(p.corners, fullFrame)) im = _warp(im, p.corners);

  switch (p.filter) {
    case FilterType.original:
      break;
    case FilterType.magic:
      im = img.adjustColor(_flatten(im), contrast: 1.12, saturation: 1.15);
    case FilterType.bw:
      im = _threshold(img.grayscale(_flatten(im)));
    case FilterType.gray:
      im = img.grayscale(im);
  }
  if (p.brightness != 0 || p.contrast != 0) {
    im = img.adjustColor(im,
        brightness: 1 + p.brightness, contrast: 1 + p.contrast);
  }
  return RenderResult(Uint8List.fromList(img.encodeJpg(im, quality: p.quality)),
      im.width, im.height);
}

/// Perspective transform: maps the user's quad onto an upright rectangle.
img.Image _warp(img.Image im, List<double> c) {
  final w = im.width, h = im.height;
  img.Point pt(int i) => img.Point(c[i * 2] * w, c[i * 2 + 1] * h);
  final tl = pt(0), tr = pt(1), br = pt(2), bl = pt(3);
  double d(img.Point a, img.Point b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)).toDouble();
  final ow = ((d(tl, tr) + d(bl, br)) / 2).round().clamp(32, 8000).toInt();
  final oh = ((d(tl, bl) + d(tr, br)) / 2).round().clamp(32, 8000).toInt();
  return img.copyRectify(im,
      topLeft: tl,
      topRight: tr,
      bottomLeft: bl,
      bottomRight: br,
      toImage: img.Image(width: ow, height: oh),
      interpolation: img.Interpolation.linear);
}

/// Background flattening: estimates the paper/light gradient with a heavy blur of a
/// down-scaled copy and divides it out. Removes shadows and evens out lighting.
img.Image _flatten(img.Image src) {
  final w = src.width, h = src.height;
  final small = img.copyResize(src,
      width: math.max(24, w ~/ 10), interpolation: img.Interpolation.average);
  final bg = img.copyResize(img.gaussianBlur(small, radius: 4),
      width: w, height: h, interpolation: img.Interpolation.linear);
  final out = src.clone();
  for (final px in out) {
    final b = bg.getPixel(px.x, px.y);
    px.r = (px.r * 255 / math.max(1, b.r * 0.94)).clamp(0, 255);
    px.g = (px.g * 255 / math.max(1, b.g * 0.94)).clamp(0, 255);
    px.b = (px.b * 255 / math.max(1, b.b * 0.94)).clamp(0, 255);
  }
  return out;
}

/// Soft threshold: crisp text, no jagged edges.
img.Image _threshold(img.Image g) {
  for (final px in g) {
    final l = px.r;
    final v = l < 110 ? 0 : (l > 175 ? 255 : (l - 110) * 255 / 65);
    px.r = v;
    px.g = v;
    px.b = v;
  }
  return g;
}

/// Auto-snap: finds the bounding box of content that differs from the border tone.
/// Axis-aligned only (no skew detection).
List<double> _detect(Uint8List bytes) {
  var im = img.decodeImage(bytes);
  if (im == null) return fullFrame;
  im = img.bakeOrientation(im);
  im = img.grayscale(
      img.copyResize(im, width: 320, interpolation: img.Interpolation.average));
  final w = im.width, h = im.height;
  final ring = <int>[];
  for (var x = 0; x < w; x += 4) {
    ring
      ..add(im.getPixel(x, 0).r.toInt())
      ..add(im.getPixel(x, h - 1).r.toInt());
  }
  for (var y = 0; y < h; y += 4) {
    ring
      ..add(im.getPixel(0, y).r.toInt())
      ..add(im.getPixel(w - 1, y).r.toInt());
  }
  ring.sort();
  final bg = ring[ring.length ~/ 2];
  final rows = List<int>.filled(h, 0), cols = List<int>.filled(w, 0);
  for (final px in im) {
    if ((px.r - bg).abs() > 28) {
      rows[px.y]++;
      cols[px.x]++;
    }
  }
  int first(List<int> a, int t) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] > t) return i;
    }
    return 0;
  }

  int last(List<int> a, int t) {
    for (var i = a.length - 1; i >= 0; i--) {
      if (a[i] > t) return i;
    }
    return a.length - 1;
  }

  final top = first(rows, w ~/ 50), bottom = last(rows, w ~/ 50);
  final left = first(cols, h ~/ 50), right = last(cols, h ~/ 50);
  if (right - left < w * 0.2 || bottom - top < h * 0.2) return fullFrame;
  double c(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  final l = c(left / w - 0.01), r = c(right / w + 0.01);
  final t = c(top / h - 0.01), b = c(bottom / h + 0.01);
  return [l, t, r, t, r, b, l, b];
}
