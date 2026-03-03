import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_manipulator.dart';
import 'pdf_edit_screen.dart';

class MergeEditScreen extends StatefulWidget {
  const MergeEditScreen({super.key});

  @override
  State<MergeEditScreen> createState() => _MergeEditScreenState();
}

class _MergeEditScreenState extends State<MergeEditScreen> {
  final List<PdfPageInfo> _pages = [];
  bool _isLoading = false;
  bool _isMerging = false;
  double _progress = 0;

  // ─── File Picking ────────────────────────────────────────

  Future<void> _addFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);

      for (final file in result.files) {
        if (file.path == null) continue;
        final pages = await PdfManipulator.loadPdfPages(file.path!);

        // Renumber pages continuing from current count
        for (int i = 0; i < pages.length; i++) {
          pages[i].displayNumber = _pages.length + i + 1;
        }
        _pages.addAll(pages);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load PDF: $e');
    }
  }

  // ─── Page Management ─────────────────────────────────────

  void _deletePage(int index) {
    setState(() {
      _pages.removeAt(index);
      _renumberPages();
    });
  }

  void _rotatePage(int index) {
    setState(() {
      _pages[index].rotation = (_pages[index].rotation + 90) % 360;
    });
  }

  void _renumberPages() {
    for (int i = 0; i < _pages.length; i++) {
      _pages[i].displayNumber = i + 1;
    }
  }

  void _reorderPage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      _renumberPages();
    });
  }

  // ─── Merge & Save ────────────────────────────────────────

  Future<void> _mergeAndSave() async {
    if (_pages.isEmpty) {
      _showError('No pages to merge');
      return;
    }

    final fileName = await _showFileNameDialog();
    if (fileName == null || fileName.trim().isEmpty) return;

    setState(() {
      _isMerging = true;
      _progress = 0;
    });

    try {
      final outputPath = await PdfManipulator.mergePages(
        pages: _pages,
        fileName: fileName.trim(),
        onProgress: (current, total) {
          if (mounted) {
            setState(() => _progress = current / total);
          }
        },
      );

      if (mounted) {
        setState(() => _isMerging = false);
        _showSuccessDialog(outputPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        _showError('Failed to merge: $e');
      }
    }
  }

  // ─── Split PDF ───────────────────────────────────────────

  Future<void> _splitPdf() async {
    if (_pages.isEmpty) return;

    // Only works if all pages are from a single source
    final sourcePath = _pages.first.sourceFilePath;

    final baseName = await _showFileNameDialog(
      title: 'Split PDF',
      hint: 'Base name for split files',
      buttonLabel: 'Split',
    );
    if (baseName == null || baseName.trim().isEmpty) return;

    setState(() {
      _isMerging = true;
      _progress = 0;
    });

    try {
      final results = await PdfManipulator.splitPdf(
        filePath: sourcePath,
        baseFileName: baseName.trim(),
        onProgress: (current, total) {
          if (mounted) {
            setState(() => _progress = current / total);
          }
        },
      );

      if (mounted) {
        setState(() => _isMerging = false);
        _showMessage('Split into ${results.length} files successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMerging = false);
        _showError('Failed to split: $e');
      }
    }
  }

  // ─── More Options ────────────────────────────────────────

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.swap_vert,
              label: 'Reorder Mode',
              subtitle: 'Long press and drag to reorder pages',
              onTap: () {
                Navigator.pop(context);
                _showMessage('Long press any page to drag and reorder');
              },
            ),
            _OptionTile(
              icon: Icons.call_split,
              label: 'Split PDF',
              subtitle: 'Save each page as a separate PDF',
              onTap: () {
                Navigator.pop(context);
                _splitPdf();
              },
            ),
            _OptionTile(
              icon: Icons.delete_sweep_outlined,
              label: 'Clear All',
              subtitle: 'Remove all loaded pages',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _confirmClearAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Pages',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Remove all loaded pages?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _pages.clear());
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────

  Future<String?> _showFileNameDialog({
    String title = 'Save Merged PDF',
    String hint = 'Enter file name',
    String buttonLabel = 'Merge & Save',
  }) async {
    final controller = TextEditingController(
      text: 'Merged_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}',
    );
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.save_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hint,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textHint),
                suffixText: '.pdf',
                suffixStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
              },
            ),
            const SizedBox(height: 8),
            Text(
              '${_pages.length} page${_pages.length > 1 ? 's' : ''} selected',
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String filePath) {
    final fileSize = PdfManipulator.getFileSize(filePath);
    final fileName = filePath.split('/').last;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('PDF Saved!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(fileName,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${_pages.length} pages • $fileSize',
                style:
                    const TextStyle(color: AppColors.textHint, fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  OpenFile.open(filePath);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(filePath)]);
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary, size: 22),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text('Merge & Edit',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('GOVISTA PDF',
                            style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pages.isNotEmpty ? _showMoreOptions : null,
                    child: Icon(Icons.more_horiz,
                        color: _pages.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        size: 28),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // Page count + Add Files
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      const TextSpan(
                          text: 'PDF Pages ',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      TextSpan(
                          text: '(${_pages.length})',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: _isLoading ? null : _addFiles,
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            color: _isLoading
                                ? AppColors.textHint
                                : AppColors.primary,
                            size: 20),
                        const SizedBox(width: 6),
                        Text('Add Files',
                            style: TextStyle(
                                color: _isLoading
                                    ? AppColors.textHint
                                    : AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceLight,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),

            // Pages Grid (with reorderable)
            Expanded(
              child: _pages.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pages.length,
                      onReorder: _reorderPage,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 8,
                          shadowColor: AppColors.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return Padding(
                          key: ValueKey(
                              '${page.sourceFilePath}_${page.sourcePageIndex}_$index'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPageRow(page, index),
                        );
                      },
                    ),
            ),

            // Progress bar
            if (_isMerging)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Processing page ${(_progress * _pages.length).ceil()} of ${_pages.length}...',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Edit button
                  if (_pages.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _isMerging
                                ? null
                                : () => _openEditor(),
                            icon: const Icon(Icons.edit_note, size: 22),
                            label: const Text('Edit Text',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Merge button
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isMerging || _pages.isEmpty) ? null : _mergeAndSave,
                        icon: _isMerging
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle, size: 22),
                        label: Text(
                            _isMerging ? 'Merging...' : 'Merge & Save',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageRow(PdfPageInfo page, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Page number & drag handle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${page.displayNumber}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Page info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.sourceFileName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Page ${page.sourcePageIndex + 1}${page.rotation > 0 ? ' • Rotated ${page.rotation}°' : ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Rotate
          IconButton(
            onPressed: () => _rotatePage(index),
            icon: const Icon(Icons.rotate_right,
                color: AppColors.textSecondary, size: 22),
            tooltip: 'Rotate',
          ),
          // Delete
          IconButton(
            onPressed: () => _deletePage(index),
            icon:
                const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            tooltip: 'Remove',
          ),
          // Drag handle
          const Icon(Icons.drag_handle, color: AppColors.textHint, size: 22),
        ],
      ),
    );
  }

  void _openEditor() {
    if (_pages.isEmpty) return;

    // Open editor for first page's source file
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfEditScreen(
          filePath: _pages.first.sourceFilePath,
          pageIndex: 0,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: _addFiles,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.note_add_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('No PDF loaded',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap to select PDF files to merge or edit',
                style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Select PDF Files',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withOpacity(0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: isDestructive ? AppColors.error : AppColors.textPrimary),
      ),
      title: Text(label,
          style: TextStyle(
              color: isDestructive ? AppColors.error : AppColors.textPrimary,
              fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}