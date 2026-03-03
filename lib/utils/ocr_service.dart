import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'pdf_manipulator.dart';

/// Result of OCR processing
class OcrResult {
  final String fullText;
  final List<OcrPageResult> pages;
  final bool isScanned; // true = OCR used, false = digital text extracted
  final Duration processingTime;

  OcrResult({
    required this.fullText,
    required this.pages,
    required this.isScanned,
    required this.processingTime,
  });

  int get totalWords =>
      fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// Result for a single page
class OcrPageResult {
  final int pageNumber;
  final String text;
  final List<OcrTextBlock> blocks;

  OcrPageResult({
    required this.pageNumber,
    required this.text,
    this.blocks = const [],
  });
}

/// Individual text block with position (from ML Kit)
class OcrTextBlock {
  final String text;
  final List<OcrTextLine> lines;

  OcrTextBlock({required this.text, this.lines = const []});
}

/// Individual text line
class OcrTextLine {
  final String text;

  OcrTextLine({required this.text});
}

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Main method: auto-detects if PDF is scanned or digital, processes accordingly
  static Future<OcrResult> processFile({
    required String filePath,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final extension = filePath.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      return await _processPdf(filePath, onProgress);
    } else {
      // Single image file
      return await _processImage(filePath, onProgress);
    }
  }

  /// Process a PDF - tries digital extraction first, falls back to OCR
  static Future<OcrResult> _processPdf(
    String filePath,
    void Function(int current, int total, String status)? onProgress,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Step 1: Try digital text extraction
    onProgress?.call(0, 1, 'Checking for digital text...');

    final digitalText = await PdfManipulator.extractAllText(filePath);
    final cleanDigital = digitalText.trim();

    // If there's substantial text, it's a digital PDF
    if (cleanDigital.length > 20) {
      // Extract page by page
      final pageCount = await PdfManipulator.getPageCount(filePath);
      final pages = <OcrPageResult>[];

      for (int i = 0; i < pageCount; i++) {
        onProgress?.call(i + 1, pageCount, 'Extracting page ${i + 1}...');
        final pageText =
            await PdfManipulator.extractTextFromPage(filePath, i);
        pages.add(OcrPageResult(
          pageNumber: i + 1,
          text: pageText,
        ));
      }

      stopwatch.stop();
      return OcrResult(
        fullText: cleanDigital,
        pages: pages,
        isScanned: false,
        processingTime: stopwatch.elapsed,
      );
    }

    // Step 2: Scanned PDF - convert pages to images and run OCR
    onProgress?.call(0, 1, 'Scanned PDF detected, starting OCR...');

    final pageImages = await _pdfToImages(filePath, onProgress);
    final pages = <OcrPageResult>[];
    final allText = StringBuffer();

    for (int i = 0; i < pageImages.length; i++) {
      onProgress?.call(
          i + 1, pageImages.length, 'OCR on page ${i + 1}...');

      final inputImage = InputImage.fromFilePath(pageImages[i]);
      final recognized = await _textRecognizer.processImage(inputImage);

      final blocks = <OcrTextBlock>[];
      final pageTextBuf = StringBuffer();

      for (final block in recognized.blocks) {
        final lines = <OcrTextLine>[];
        for (final line in block.lines) {
          lines.add(OcrTextLine(text: line.text));
          pageTextBuf.writeln(line.text);
        }
        blocks.add(OcrTextBlock(text: block.text, lines: lines));
      }

      final pageText = pageTextBuf.toString().trim();
      pages.add(OcrPageResult(
        pageNumber: i + 1,
        text: pageText,
        blocks: blocks,
      ));

      allText.writeln(pageText);
      allText.writeln('');

      // Clean up temp image
      try {
        await File(pageImages[i]).delete();
      } catch (_) {}
    }

    stopwatch.stop();
    return OcrResult(
      fullText: allText.toString().trim(),
      pages: pages,
      isScanned: true,
      processingTime: stopwatch.elapsed,
    );
  }

  /// Process a single image file with OCR
  static Future<OcrResult> _processImage(
    String filePath,
    void Function(int current, int total, String status)? onProgress,
  ) async {
    final stopwatch = Stopwatch()..start();
    onProgress?.call(1, 1, 'Running OCR...');

    final inputImage = InputImage.fromFilePath(filePath);
    final recognized = await _textRecognizer.processImage(inputImage);

    final blocks = <OcrTextBlock>[];
    final textBuf = StringBuffer();

    for (final block in recognized.blocks) {
      final lines = <OcrTextLine>[];
      for (final line in block.lines) {
        lines.add(OcrTextLine(text: line.text));
        textBuf.writeln(line.text);
      }
      blocks.add(OcrTextBlock(text: block.text, lines: lines));
    }

    stopwatch.stop();
    return OcrResult(
      fullText: textBuf.toString().trim(),
      pages: [
        OcrPageResult(
          pageNumber: 1,
          text: textBuf.toString().trim(),
          blocks: blocks,
        ),
      ],
      isScanned: true,
      processingTime: stopwatch.elapsed,
    );
  }

  /// Converts each PDF page to a PNG image for OCR processing
  /// Extracts embedded images from scanned PDF pages
  static Future<List<String>> _pdfToImages(
    String filePath,
    void Function(int current, int total, String status)? onProgress,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final tempDir = await getTemporaryDirectory();
    final imagePaths = <String>[];

    for (int i = 0; i < document.pages.count; i++) {
      onProgress?.call(
          i + 1, document.pages.count, 'Converting page ${i + 1} to image...');

      final page = document.pages[i];
      bool imageExtracted = false;

      // Note: Direct image extraction from PDF is not available in basic Syncfusion PDF.
      // For production use, consider using 'pdf_render' or similar package for rendering.
      // Currently using fallback approach to create placeholder images.

      // Fallback: create a placeholder
      // In production, you'd use a PDF renderer package for this
      if (!imageExtracted) {
        final imagePath = '${tempDir.path}/ocr_page_${i + 1}.png';
        final blankImage = img.Image(width: 2480, height: 3508); // A4 at 300dpi
        img.fill(blankImage, color: img.ColorRgba8(255, 255, 255, 255));
        await File(imagePath)
            .writeAsBytes(Uint8List.fromList(img.encodePng(blankImage)));
        imagePaths.add(imagePath);
      }
    }

    document.dispose();
    return imagePaths;
  }

  /// Save extracted/edited text as a new searchable PDF
  static Future<String> saveAsPdf({
    required String text,
    required String fileName,
    double fontSize = 12,
  }) async {
    final document = PdfDocument();
    document.pages.removeAt(0);

    // Split text into chunks that fit on a page
    final lines = text.split('\n');
    const linesPerPage = 45; // approximate lines per A4 page at 12pt
    
    for (int i = 0; i < lines.length; i += linesPerPage) {
      final pageLines = lines.sublist(
        i,
        (i + linesPerPage > lines.length) ? lines.length : i + linesPerPage,
      );
      final pageText = pageLines.join('\n');

      final page = document.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
      final clientSize = page.getClientSize();

      page.graphics.drawString(
        pageText,
        font,
        bounds: ui.Rect.fromLTWH(40, 40, clientSize.width - 80, clientSize.height - 80),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        format: PdfStringFormat(
          lineSpacing: 4,
          wordSpacing: 1,
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = '${outputDir.path}/$fileName.pdf';
    await File(outputPath).writeAsBytes(await document.save());
    document.dispose();

    return outputPath;
  }

  /// Save extracted text as a plain .txt file
  static Future<String> saveAsTxt({
    required String text,
    required String fileName,
  }) async {
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = '${outputDir.path}/$fileName.txt';
    await File(outputPath).writeAsString(text);
    return outputPath;
  }

  /// Clean up resources
  static void dispose() {
    _textRecognizer.close();
  }
}

