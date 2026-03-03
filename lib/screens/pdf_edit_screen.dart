import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_manipulator.dart';

class PdfEditScreen extends StatefulWidget {
  final String filePath;
  final int pageIndex;

  const PdfEditScreen({
    super.key,
    required this.filePath,
    this.pageIndex = 0,
  });

  @override
  State<PdfEditScreen> createState() => _PdfEditScreenState();
}

class _PdfEditScreenState extends State<PdfEditScreen> {
  late String _currentFilePath;
  int _currentPage = 0;
  int _totalPages = 0;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _editMode = false;

  // Text blocks for editing
  List<_EditBlock> _blocks = [];
  List<PdfTextBlock> _originals = [];

  // PDF page size (PDF points, A4 = 595 x 842)
  double _pageW = 595;
  double _pageH = 842;

  final PdfViewerController _viewerCtrl = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _currentFilePath = widget.filePath;
    _currentPage = widget.pageIndex;
  }

  @override
  void dispose() {
    _disposeBlocks();
    _viewerCtrl.dispose();
    super.dispose();
  }

  void _disposeBlocks() {
    for (final b in _blocks) {
      b.ctrl.dispose();
      b.focus.dispose();
    }
  }

  // ─── Enter Edit ──────────────────────────────────────────

  Future<void> _enterEdit() async {
    setState(() => _isLoading = true);

    try {
      // Get page size
      final pageCount = await PdfManipulator.getPageCount(_currentFilePath);

      final blocks = await PdfManipulator.extractTextBlocks(
        _currentFilePath,
        _currentPage,
      );

      if (blocks.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('No editable text on this page. Try OCR for scanned PDFs.',
              AppColors.warning);
        }
        return;
      }

      // Deep copy originals for comparison
      final originals = blocks
          .map((b) => PdfTextBlock(
                text: b.text, x: b.x, y: b.y,
                width: b.width, height: b.height,
                fontSize: b.fontSize, fontName: b.fontName,
              ))
          .toList();

      // Create edit blocks with controllers
      final editBlocks = blocks.map((b) {
        return _EditBlock(
          block: b,
          ctrl: TextEditingController(text: b.text),
          focus: FocusNode(),
          origText: b.text,
        );
      }).toList();

      setState(() {
        _blocks = editBlocks;
        _originals = originals;
        _editMode = true;
        _isLoading = false;
        _totalPages = pageCount;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error: $e', AppColors.error);
      }
    }
  }

  void _exitEdit({bool force = false}) {
    if (!force && _hasChanges) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Discard edits?',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Your changes will be lost.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doExitEdit();
              },
              child: const Text('Discard',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    } else {
      _doExitEdit();
    }
  }

  void _doExitEdit() {
    _disposeBlocks();
    setState(() {
      _blocks = [];
      _originals = [];
      _editMode = false;
    });
  }

  bool get _hasChanges {
    for (final b in _blocks) {
      if (b.ctrl.text != b.origText) return true;
    }
    return false;
  }

  // ─── Save ────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_hasChanges) {
      _snack('No changes to save', AppColors.textHint);
      return;
    }

    final name = await _askFileName();
    if (name == null) return;

    setState(() => _isSaving = true);

    try {
      final edited = _blocks
          .map((b) => PdfTextBlock(
                text: b.ctrl.text,
                x: b.block.x, y: b.block.y,
                width: b.block.width, height: b.block.height,
                fontSize: b.block.fontSize, fontName: b.block.fontName,
              ))
          .toList();

      final path = await PdfManipulator.saveEditedPdf(
        sourceFilePath: _currentFilePath,
        pageIndex: _currentPage,
        editedBlocks: edited,
        originalBlocks: _originals,
        fileName: name,
      );

      if (mounted) {
        _disposeBlocks();
        setState(() {
          _isSaving = false;
          _currentFilePath = path;
          _editMode = false;
          _blocks = [];
          _originals = [];
        });
        _showSuccess(path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _snack('Save failed: $e', AppColors.error);
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Divider(color: AppColors.border, height: 1),

            // Edit mode hint
            if (_editMode)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  '${_blocks.length} text blocks found — tap any text to edit it directly',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 12),
                ),
              ),

            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _editMode
                      ? _editView()
                      : _pdfView(),
            ),

            _bottomBar(),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ─────────────────────────────────────────────

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.surface,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_editMode) {
                _exitEdit();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editMode ? 'Editing Page ${_currentPage + 1}' : 'PDF Viewer',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  _editMode
                      ? 'Tap text to place cursor and edit'
                      : 'Page ${_currentPage + 1}${_totalPages > 0 ? ' of $_totalPages' : ''}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Save button
          if (_editMode && _hasChanges)
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── PDF View (normal) ───────────────────────────────────

  Widget _pdfView() {
    return SfPdfViewer.file(
      File(_currentFilePath),
      controller: _viewerCtrl,
      enableTextSelection: true,
      canShowScrollHead: true,
      onPageChanged: (d) =>
          setState(() => _currentPage = d.newPageNumber - 1),
      onDocumentLoaded: (d) =>
          setState(() => _totalPages = d.document.pages.count),
    );
  }

  // ─── Edit View (white page + positioned text fields) ─────

  Widget _editView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale PDF coords to screen
        final screenW = constraints.maxWidth - 16; // 8px margin each side
        final screenH = constraints.maxHeight - 16;

        final scaleX = screenW / _pageW;
        final scaleY = screenH / _pageH;
        final scale = scaleX < scaleY ? scaleX : scaleY;

        final pageRenderW = _pageW * scale;
        final pageRenderH = _pageH * scale;

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: Container(
              width: pageRenderW,
              height: pageRenderH,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: _blocks.map((eb) {
                  final b = eb.block;
                  final left = b.x * scale;
                  final top = b.y * scale;
                  final w = (b.width * scale).clamp(40.0, pageRenderW - left);
                  final fs = (b.fontSize * scale).clamp(6.0, 28.0);

                  final modified = eb.ctrl.text != eb.origText;

                  return Positioned(
                    left: left,
                    top: top,
                    width: w + 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: modified
                            ? Colors.yellow.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: eb.focus.hasFocus
                            ? Border.all(color: AppColors.primary, width: 1.5)
                            : null,
                      ),
                      child: EditableText(
                        controller: eb.ctrl,
                        focusNode: eb.focus,
                        style: TextStyle(
                          fontSize: fs,
                          color: Colors.black87,
                          height: 1.15,
                        ),
                        cursorColor: AppColors.primary,
                        backgroundCursorColor: Colors.grey,
                        maxLines: null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Bottom Bar ──────────────────────────────────────────

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: _editMode
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Btn(
                    icon: Icons.close, label: 'Cancel', onTap: _exitEdit),
                _Btn(
                  icon: Icons.save,
                  label: 'Save',
                  active: _hasChanges,
                  onTap: _hasChanges ? _save : null,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Btn(
                  icon: Icons.edit,
                  label: 'Edit Text',
                  onTap: _enterEdit,
                ),
                _Btn(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () =>
                      Share.shareXFiles([XFile(_currentFilePath)]),
                ),
              ],
            ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<String?> _askFileName() {
    final c = TextEditingController(
      text:
          'Edited_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}',
    );
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.save, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Save PDF',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            suffixText: '.pdf',
            suffixStyle: const TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final n = c.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String path) {
    final size = PdfManipulator.getFileSize(path);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Saved!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            Text(size,
                style:
                    const TextStyle(color: AppColors.textHint, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFile.open(path);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data ────────────────────────────────────────────────────

class _EditBlock {
  final PdfTextBlock block;
  final TextEditingController ctrl;
  final FocusNode focus;
  final String origText;

  _EditBlock({
    required this.block,
    required this.ctrl,
    required this.focus,
    required this.origText,
  });
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _Btn({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active
                  ? AppColors.primary
                  : on
                      ? AppColors.textSecondary
                      : AppColors.textHint,
              size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: active
                      ? AppColors.primary
                      : on
                          ? AppColors.textSecondary
                          : AppColors.textHint,
                  fontSize: 11)),
        ],
      ),
    );
  }
}