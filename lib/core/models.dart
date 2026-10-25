enum FilterType {
  original('Original'),
  magic('Magic Color'),
  bw('B&W'),
  gray('Grayscale');

  final String label;
  const FilterType(this.label);
}

class OcrLine {
  final String text;
  final double l, t, r, b; // normalised 0..1
  const OcrLine(this.text, this.l, this.t, this.r, this.b);
  Map<String, dynamic> toJson() => {'x': text, 'l': l, 't': t, 'r': r, 'b': b};
  factory OcrLine.fromJson(Map<String, dynamic> j) => OcrLine(
      j['x'] as String, (j['l'] as num).toDouble(), (j['t'] as num).toDouble(),
      (j['r'] as num).toDouble(), (j['b'] as num).toDouble());
}

class ScanPage {
  final String id, originalPath, path;
  final int width, height;
  final FilterType filter;
  final double brightness, contrast; // -0.5..0.5
  final List<double> corners; // tl,tr,br,bl as x,y pairs, normalised
  final String? ocrText;
  final List<OcrLine> lines;

  const ScanPage({
    required this.id, required this.originalPath, required this.path,
    required this.width, required this.height,
    this.filter = FilterType.original, this.brightness = 0, this.contrast = 0,
    this.corners = const [0, 0, 1, 0, 1, 1, 0, 1],
    this.ocrText, this.lines = const [],
  });

  ScanPage copyWith({
    String? path, int? width, int? height, FilterType? filter,
    double? brightness, double? contrast, List<double>? corners,
    String? ocrText, List<OcrLine>? lines, bool clearOcr = false,
  }) =>
      ScanPage(
        id: id, originalPath: originalPath, path: path ?? this.path,
        width: width ?? this.width, height: height ?? this.height,
        filter: filter ?? this.filter, brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast, corners: corners ?? this.corners,
        ocrText: clearOcr ? null : (ocrText ?? this.ocrText),
        lines: clearOcr ? const [] : (lines ?? this.lines),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'o': originalPath, 'p': path, 'w': width, 'h': height,
        'f': filter.name, 'br': brightness, 'ct': contrast, 'c': corners,
        'ocr': ocrText, 'lines': lines.map((e) => e.toJson()).toList(),
      };

  factory ScanPage.fromJson(Map<String, dynamic> j) => ScanPage(
        id: j['id'] as String, originalPath: j['o'] as String, path: j['p'] as String,
        width: j['w'] as int, height: j['h'] as int,
        filter: FilterType.values.firstWhere((e) => e.name == j['f'], orElse: () => FilterType.original),
        brightness: (j['br'] as num).toDouble(), contrast: (j['ct'] as num).toDouble(),
        corners: (j['c'] as List).map((e) => (e as num).toDouble()).toList(),
        ocrText: j['ocr'] as String?,
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => OcrLine.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class ScanDoc {
  final String id, name;
  final String? folder;
  final DateTime created;
  final List<ScanPage> pages;
  const ScanDoc({required this.id, required this.name, required this.created,
      required this.pages, this.folder});

  ScanDoc copyWith({String? name, List<ScanPage>? pages, String? folder, bool clearFolder = false}) =>
      ScanDoc(id: id, created: created, name: name ?? this.name, pages: pages ?? this.pages,
          folder: clearFolder ? null : (folder ?? this.folder));

  String get allText => pages.map((p) => p.ocrText ?? '').join('\n\n').trim();

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'f': folder,
      'd': created.toIso8601String(), 'pages': pages.map((e) => e.toJson()).toList()};

  factory ScanDoc.fromJson(Map<String, dynamic> j) => ScanDoc(
        id: j['id'] as String, name: j['n'] as String, folder: j['f'] as String?,
        created: DateTime.parse(j['d'] as String),
        pages: (j['pages'] as List).map((e) => ScanPage.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}
