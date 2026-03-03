import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

enum PageSize { a4, letter, legal, a3, a5 }
enum PageOrientation { portrait, landscape }
enum ImageQuality { low, medium, high, original }
enum PageMargin { none, small, normal, large }

class PdfSettings {
  PageSize pageSize;
  PageOrientation orientation;
  ImageQuality quality;
  PageMargin margin;

  PdfSettings({
    this.pageSize = PageSize.a4,
    this.orientation = PageOrientation.portrait,
    this.quality = ImageQuality.high,
    this.margin = PageMargin.normal,
  });

  PdfPageFormat get pdfPageFormat {
    PdfPageFormat format;
    switch (pageSize) {
      case PageSize.a4:
        format = PdfPageFormat.a4;
        break;
      case PageSize.letter:
        format = PdfPageFormat.letter;
        break;
      case PageSize.legal:
        format = PdfPageFormat.legal;
        break;
      case PageSize.a3:
        format = PdfPageFormat.a3;
        break;
      case PageSize.a5:
        format = PdfPageFormat.a5;
        break;
    }
    if (orientation == PageOrientation.landscape) {
      format = format.landscape;
    }
    return format;
  }

  double get marginValue {
    switch (margin) {
      case PageMargin.none:
        return 0;
      case PageMargin.small:
        return 12;
      case PageMargin.normal:
        return 28;
      case PageMargin.large:
        return 48;
    }
  }

  int get compressionQuality {
    switch (quality) {
      case ImageQuality.low:
        return 40;
      case ImageQuality.medium:
        return 65;
      case ImageQuality.high:
        return 85;
      case ImageQuality.original:
        return 100;
    }
  }

  String get pageSizeLabel {
    switch (pageSize) {
      case PageSize.a4:
        return 'A4';
      case PageSize.letter:
        return 'Letter';
      case PageSize.legal:
        return 'Legal';
      case PageSize.a3:
        return 'A3';
      case PageSize.a5:
        return 'A5';
    }
  }

  String get orientationLabel {
    switch (orientation) {
      case PageOrientation.portrait:
        return 'Portrait';
      case PageOrientation.landscape:
        return 'Landscape';
    }
  }

  String get qualityLabel {
    switch (quality) {
      case ImageQuality.low:
        return 'Low';
      case ImageQuality.medium:
        return 'Medium';
      case ImageQuality.high:
        return 'High';
      case ImageQuality.original:
        return 'Original';
    }
  }

  String get marginLabel {
    switch (margin) {
      case PageMargin.none:
        return 'None';
      case PageMargin.small:
        return 'Small';
      case PageMargin.normal:
        return 'Normal';
      case PageMargin.large:
        return 'Large';
    }
  }
}

class PdfGenerator {
  /// Generates a PDF from a list of image file paths.
  /// Returns the output file path on success.
  static Future<String> generatePdf({
    required List<String> imagePaths,
    required PdfSettings settings,
    String? fileName,
    void Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();
    final format = settings.pdfPageFormat;
    final marginVal = settings.marginValue;

    for (int i = 0; i < imagePaths.length; i++) {
      onProgress?.call(i + 1, imagePaths.length);

      final file = File(imagePaths[i]);
      if (!await file.exists()) continue;

      Uint8List imageBytes = await file.readAsBytes();

      // Compress if not original quality
      if (settings.quality != ImageQuality.original) {
        imageBytes = _compressImage(imageBytes, settings.compressionQuality);
      }

      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.all(marginVal),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    // Save to app documents directory
    final outputDir = await getApplicationDocumentsDirectory();
    final outputName = fileName ??
        'GoVista_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = '${outputDir.path}/$outputName.pdf';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(await pdf.save());

    return outputPath;
  }

  /// Compresses an image to the given quality (0-100).
  static Uint8List _compressImage(Uint8List bytes, int quality) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    } catch (_) {
      // If decoding fails, return original bytes
      return bytes;
    }
  }

  /// Returns the file size in a human-readable format.
  static String getFileSize(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return '0 B';
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}