class PdfFileModel {
  final String name;
  final String path;
  final String size;
  final String createdAt;
  final int pageCount;

  PdfFileModel({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    this.pageCount = 1,
  });
}
