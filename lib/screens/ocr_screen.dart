import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../utils/ocr_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isProcessing = false;
  String _statusText = '';
  double _progress = 0;

  OcrResult? _result;
  int _selectedPageIndex = 0;

  // Editing
  bool _isEditing = false;
  final TextEditingController _editController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  // ─── File Picking ────────────────────────────────────────

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
          _result = null;
          _isEditing = false;
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
          _result = null;
          _isEditing = false;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (image != null) {
        setState(() {
          _selectedFilePath = image.path;
          _selectedFileName = image.name;
          _result = null;
          _isEditing = false;
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  // ─── OCR Processing ──────────────────────────────────────

  Future<void> _startOcr() async {
    if (_selectedFilePath == null) {
      _showError('Please select a file first');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _statusText = 'Preparing...';
      _result = null;
      _isEditing = false;
    });

    try {
      final result = await OcrService.processFile(
        filePath: _selectedFilePath!,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _progress = total > 0 ? current / total : 0;
              _statusText = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _result = result;
          _selectedPageIndex = 0;
        });

        if (result.fullText.trim().isEmpty) {
          _showError('No text found in the document');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('OCR failed: $e');
      }
    }
  }

  // ─── Actions ─────────────────────────────────────────────

  void _copyText() {
    if (_result == null) return;
    final text = _isEditing
        ? _editController.text
        : _result!.pages[_selectedPageIndex].text;
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('Text copied to clipboard');
  }

  void _toggleEdit() {
    if (_result == null) return;
    setState(() {
      if (!_isEditing) {
        _editController.text = _result!.pages[_selectedPageIndex].text;
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _exportText() async {
    if (_result == null) return;

    final text = _isEditing
        ? _editController.text
        : _result!.fullText;

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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Export As',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            _SourceOption(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Searchable PDF',
              subtitle: 'Save as a text-based PDF',
              onTap: () {
                Navigator.pop(context);
                _exportAsPdf(text);
              },
            ),
            _SourceOption(
              icon: Icons.text_snippet_outlined,
              label: 'Text File (.txt)',
              subtitle: 'Save as plain text',
              onTap: () {
                Navigator.pop(context);
                _exportAsTxt(text);
              },
            ),
            _SourceOption(
              icon: Icons.share,
              label: 'Share Text',
              subtitle: 'Share via other apps',
              onTap: () {
                Navigator.pop(context);
                Share.share(text);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPdf(String text) async {
    final fileName = await _showFileNameDialog('Save as PDF');
    if (fileName == null) return;

    try {
      final path = await OcrService.saveAsPdf(
        text: text,
        fileName: fileName,
      );
      _showExportSuccess(path);
    } catch (e) {
      _showError('Export failed: $e');
    }
  }

  Future<void> _exportAsTxt(String text) async {
    final fileName = await _showFileNameDialog('Save as Text');
    if (fileName == null) return;

    try {
      final path = await OcrService.saveAsTxt(
        text: text,
        fileName: fileName,
      );
      _showExportSuccess(path);
    } catch (e) {
      _showError('Export failed: $e');
    }
  }

  // ─── Dialogs ─────────────────────────────────────────────

  Future<String?> _showFileNameDialog(String title) async {
    final controller = TextEditingController(
      text: 'OCR_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}',
    );
    controller.selection = TextSelection(
        baseOffset: 0, extentOffset: controller.text.length);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'File name',
            hintStyle: const TextStyle(color: AppColors.textHint),
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
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final n = controller.text.trim();
              if (n.isNotEmpty) Navigator.pop(context, n);
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

  void _showExportSuccess(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Exported!',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  OpenFile.open(filePath);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Open File'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _clearSelection() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _result = null;
      _isEditing = false;
      _editController.clear();
    });
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
                _buildTopBar(),
                const Divider(color: AppColors.border, height: 1),
                Expanded(
                  child: _result != null ? _buildResultView() : _buildInputView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OCR Scanner',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Extract & edit text from any document',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (_result != null)
            GestureDetector(
              onTap: _clearSelection,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('New Scan',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Input View (before processing) ──────────────────────

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source cards
          const Text('SELECT SOURCE',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SourceCard(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF File',
                  subtitle: 'Scanned or digital',
                  isSelected:
                      _selectedFilePath?.endsWith('.pdf') == true,
                  onTap: _pickPdf,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SourceCard(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  subtitle: 'JPG, PNG, etc.',
                  isSelected: _selectedFilePath != null &&
                      !_selectedFilePath!.endsWith('.pdf'),
                  onTap: _pickImage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SourceCard(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  subtitle: 'Scan now',
                  onTap: _pickFromCamera,
                ),
              ),
            ],
          ),

          // Selected file
          if (_selectedFilePath != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedFilePath!.endsWith('.pdf')
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName ?? 'Selected file',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text('Smart Detection',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Automatically detects whether your document is scanned or digital. Uses Google ML Kit OCR for scanned documents and direct text extraction for digital PDFs.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Processing progress
          if (_isProcessing) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_statusText,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 15)),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Extract button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (_isProcessing || _selectedFilePath == null)
                  ? null
                  : _startOcr,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.document_scanner, size: 22),
              label: Text(
                _isProcessing ? 'Processing...' : 'Extract Text',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Result View (after processing) ──────────────────────

  Widget _buildResultView() {
    final result = _result!;
    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: result.isScanned
              ? AppColors.warning.withValues(alpha: 0.1)
              : AppColors.success.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(
                result.isScanned
                    ? Icons.document_scanner
                    : Icons.text_snippet,
                color:
                    result.isScanned ? AppColors.warning : AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isScanned
                      ? 'OCR completed • ${result.totalWords} words • ${result.processingTime.inSeconds}s'
                      : 'Digital text extracted • ${result.totalWords} words',
                  style: TextStyle(
                    color: result.isScanned
                        ? AppColors.warning
                        : AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Page selector (if multiple pages)
        if (result.pages.length > 1)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: result.pages.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedPageIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPageIndex = index;
                      if (_isEditing) {
                        _editController.text = result.pages[index].text;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Page ${index + 1}',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Text('EXTRACTED TEXT',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              _ActionChip(
                icon: Icons.copy,
                label: 'Copy',
                onTap: _copyText,
              ),
              const SizedBox(width: 6),
              _ActionChip(
                icon: _isEditing ? Icons.visibility : Icons.edit,
                label: _isEditing ? 'View' : 'Edit',
                onTap: _toggleEdit,
              ),
              const SizedBox(width: 6),
              _ActionChip(
                icon: Icons.file_download_outlined,
                label: 'Export',
                onTap: _exportText,
              ),
            ],
          ),
        ),

        // Text content
        Expanded(
          child: _isEditing ? _buildEditView() : _buildTextView(),
        ),
      ],
    );
  }

  Widget _buildTextView() {
    final pageText = _result!.pages[_selectedPageIndex].text;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: SelectableText(
          pageText.isEmpty ? 'No text found on this page.' : pageText,
          style: TextStyle(
            color: pageText.isEmpty
                ? AppColors.textHint
                : AppColors.textPrimary,
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ),
    );
  }

  Widget _buildEditView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: TextField(
          controller: _editController,
          maxLines: null,
          expands: true,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.7,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(16),
            border: InputBorder.none,
            hintText: 'Edit text here...',
            hintStyle: TextStyle(color: AppColors.textHint),
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(label,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}