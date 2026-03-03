import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a single PDF page with its source info
class PdfPageInfo {
  final String sourceFilePath;
  final String sourceFileName;
  final int sourcePageIndex; // 0-based index in source file
  int displayNumber; // 1-based display number
  int rotation; // 0, 90, 180, 270

  PdfPageInfo({
    required this.sourceFilePath,
    required this.sourceFileName,
    required this.sourcePageIndex,
    required this.displayNumber,
    this.rotation = 0,
  });
}

/// Represents extracted text from a PDF page for editing
class PdfTextBlock {
  String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final double fontSize;
  final String fontName;

  PdfTextBlock({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.fontName,
  });
}

class PdfManipulator {
  /// Loads a PDF and returns page info list
  static Future<List<PdfPageInfo>> loadPdfPages(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final pageCount = document.pages.count;
    final fileName = filePath.split('/').last;

    final pages = List.generate(pageCount, (i) => PdfPageInfo(
      sourceFilePath: filePath,
      sourceFileName: fileName,
      sourcePageIndex: i,
      displayNumber: i + 1,
    ));

    document.dispose();
    return pages;
  }

  /// Gets page count without loading full page info
  static Future<int> getPageCount(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final count = document.pages.count;
    document.dispose();
    return count;
  }

  /// Merges selected pages from potentially multiple PDFs into one
  static Future<String> mergePages({
    required List<PdfPageInfo> pages,
    required String fileName,
    void Function(int current, int total)? onProgress,
  }) async {
    final outputDoc = PdfDocument();
    // Remove the default blank page
    outputDoc.pages.removeAt(0);

    // Group pages by source file to avoid re-reading
    final Map<String, Uint8List> fileCache = {};

    for (int i = 0; i < pages.length; i++) {
      onProgress?.call(i + 1, pages.length);
      final page = pages[i];

      // Load source file bytes (cached)
      if (!fileCache.containsKey(page.sourceFilePath)) {
        final file = File(page.sourceFilePath);
        fileCache[page.sourceFilePath] = await file.readAsBytes();
      }

      final sourceDoc = PdfDocument(inputBytes: fileCache[page.sourceFilePath]!);
      final template = sourceDoc.pages[page.sourcePageIndex].createTemplate();

      // Add new page with matching size
      final newPage = outputDoc.pages.add();
      newPage.graphics.setTransparency(1);

      // Apply rotation if needed
      if (page.rotation != 0) {
        final g = newPage.graphics;
        final w = newPage.getClientSize().width;
        final h = newPage.getClientSize().height;

        switch (page.rotation) {
          case 90:
            g.rotateTransform(90);
            g.translateTransform(0, -w);
            break;
          case 180:
            g.rotateTransform(180);
            g.translateTransform(-w, -h);
            break;
          case 270:
            g.rotateTransform(270);
            g.translateTransform(-h, 0);
            break;
        }
      }

      // Draw source page content onto new page
      newPage.graphics.drawPdfTemplate(
        template,
        const Offset(0, 0),
        newPage.getClientSize(),
      );

      sourceDoc.dispose();
    }

    // Save
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = '${outputDir.path}/$fileName.pdf';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(await outputDoc.save());
    outputDoc.dispose();

    return outputPath;
  }

  /// Split a PDF into individual page files
  static Future<List<String>> splitPdf({
    required String filePath,
    required String baseFileName,
    void Function(int current, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final sourceDoc = PdfDocument(inputBytes: bytes);
    final outputDir = await getApplicationDocumentsDirectory();
    final results = <String>[];

    for (int i = 0; i < sourceDoc.pages.count; i++) {
      onProgress?.call(i + 1, sourceDoc.pages.count);

      final singleDoc = PdfDocument();
      singleDoc.pages.removeAt(0);

      final template = sourceDoc.pages[i].createTemplate();
      final newPage = singleDoc.pages.add();
      newPage.graphics.drawPdfTemplate(
        template,
        const Offset(0, 0),
        newPage.getClientSize(),
      );

      final outputPath = '${outputDir.path}/${baseFileName}_page_${i + 1}.pdf';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await singleDoc.save());
      singleDoc.dispose();
      results.add(outputPath);
    }

    sourceDoc.dispose();
    return results;
  }

  /// Extract all text from a specific page (for digital/system-generated PDFs)
  static Future<String> extractTextFromPage(
      String filePath, int pageIndex) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final textExtractor = PdfTextExtractor(document);
    final text = textExtractor.extractText(
        startPageIndex: pageIndex, endPageIndex: pageIndex);

    document.dispose();
    return text;
  }

  /// Extract all text from entire PDF
  static Future<String> extractAllText(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final textExtractor = PdfTextExtractor(document);
    final text = textExtractor.extractText();

    document.dispose();
    return text;
  }

  /// Extract text with position info (for inline editing)
  static Future<List<PdfTextBlock>> extractTextBlocks(
      String filePath, int pageIndex) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final textExtractor = PdfTextExtractor(document);
    final lines = textExtractor.extractTextLines(
        startPageIndex: pageIndex, endPageIndex: pageIndex);

    final blocks = <PdfTextBlock>[];
    for (final line in lines) {
      blocks.add(PdfTextBlock(
        text: line.text,
        x: line.bounds.left,
        y: line.bounds.top,
        width: line.bounds.width,
        height: line.bounds.height,
        fontSize: line.wordCollection.isNotEmpty
            ? line.wordCollection.first.fontSize
            : 12.0,
        fontName: line.wordCollection.isNotEmpty
            ? line.wordCollection.first.fontName
            : 'Helvetica',
      ));
    }

    document.dispose();
    return blocks;
  }

  /// Creates a new PDF with edited text overlays
  static Future<String> saveEditedPdf({
    required String sourceFilePath,
    required int pageIndex,
    required List<PdfTextBlock> editedBlocks,
    required List<PdfTextBlock> originalBlocks,
    required String fileName,
  }) async {
    final file = File(sourceFilePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final page = document.pages[pageIndex];

    // Find blocks that were edited
    for (int i = 0; i < editedBlocks.length && i < originalBlocks.length; i++) {
      if (editedBlocks[i].text != originalBlocks[i].text) {
        final block = editedBlocks[i];

        // Cover original text with white rectangle
        page.graphics.drawRectangle(
          bounds: Rect.fromLTWH(
            block.x - 1,
            block.y - 1,
            block.width + 2,
            block.height + 2,
          ),
          brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        );

        // Draw new text
        final font = PdfStandardFont(
          PdfFontFamily.helvetica,
          block.fontSize,
        );
        page.graphics.drawString(
          block.text,
          font,
          bounds: Rect.fromLTWH(
            block.x,
            block.y,
            block.width + 50,
            block.height,
          ),
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        );
      }
    }

    // Save
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = '${outputDir.path}/$fileName.pdf';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(await document.save());
    document.dispose();

    return outputPath;
  }

  /// Add text annotation/watermark to a page
  static Future<String> addTextToPage({
    required String sourceFilePath,
    required int pageIndex,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required String fileName,
    int colorR = 0,
    int colorG = 0,
    int colorB = 0,
  }) async {
    final file = File(sourceFilePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final page = document.pages[pageIndex];
    final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);

    page.graphics.drawString(
      text,
      font,
      bounds: Rect.fromLTWH(x, y, page.getClientSize().width - x, fontSize + 4),
      brush: PdfSolidBrush(PdfColor(colorR, colorG, colorB)),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = '${outputDir.path}/$fileName.pdf';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(await document.save());
    document.dispose();

    return outputPath;
  }

  /// Returns file size in readable format
  static String getFileSize(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return '0 B';
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}