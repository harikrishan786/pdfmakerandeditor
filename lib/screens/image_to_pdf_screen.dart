import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_thumbnail.dart';
import '../utils/pdf_generator.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<String> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final PdfSettings _settings = PdfSettings();

  bool _isGenerating = false;
  double _progress = 0;

  // ─── Image Picking ───────────────────────────────────────

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 90,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((e) => e.path));
        });
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedImages.add(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  void _showPickOptions() {
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
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
              ),
              title: const Text('Gallery',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text('Select multiple photos',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
              ),
              title: const Text('Camera',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text('Take a new photo',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Image Management ────────────────────────────────────

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Remove all selected images?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedImages.clear());
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ─── PDF Generation ──────────────────────────────────────

  Future<void> _generatePdf() async {
    if (_selectedImages.isEmpty) {
      _showError('Please select at least one image');
      return;
    }

    // Show filename dialog
    final fileName = await _showFileNameDialog();
    if (fileName == null || fileName.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _progress = 0;
    });

    try {
      final outputPath = await PdfGenerator.generatePdf(
        imagePaths: _selectedImages,
        settings: _settings,
        fileName: fileName.trim(),
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progress = current / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isGenerating = false);
        _showSuccessDialog(outputPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showError('Failed to generate PDF: $e');
      }
    }
  }

  Future<String?> _showFileNameDialog() async {
    final controller = TextEditingController(
      text: 'Document_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}',
    );

    // Auto-select all text when dialog opens
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Save PDF As',
                style: TextStyle(
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
              const Text(
                'Enter a name for your PDF file',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter file name',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  suffixText: '.pdf',
                  suffixStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.pop(context, value.trim());
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} • ${_settings.pageSizeLabel} • ${_settings.orientationLabel}',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Create PDF',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String filePath) {
    final fileSize = PdfGenerator.getFileSize(filePath);
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
            const Text(
              'PDF Created!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedImages.length} pages • $fileSize',
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            // Open PDF
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Share
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Done
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

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_selectedImages.isNotEmpty) ...[
              _buildSelectedPhotosHeader(),
              const SizedBox(height: 12),
              _buildPhotosList(),
              const SizedBox(height: 16),
            ],
            Expanded(child: _buildAddPhotosArea()),
            _buildBottomAction(),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
              const Spacer(),
              if (_selectedImages.isNotEmpty)
                GestureDetector(
                  onTap: _clearAll,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showPdfSettings(context),
                child: const Icon(
                  Icons.tune,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Image to PDF',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedImages.isEmpty
                ? 'Select images to convert'
                : '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} selected • Long press to reorder',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPhotosHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'SELECTED PHOTOS (${_selectedImages.length})',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showPickOptions,
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 4),
                Text(
                  'Add More',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosList() {
    return SizedBox(
      height: 190,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _selectedImages.length,
        onReorder: _reorderImages,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            elevation: 6,
            shadowColor: AppColors.primary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          return PhotoThumbnail(
            key: ValueKey('${_selectedImages[index]}_$index'),
            imagePath: _selectedImages[index],
            onRemove: () => _removeImage(index),
            index: index + 1,
          );
        },
      ),
    );
  }

  Widget _buildAddPhotosArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _showPickOptions,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Photos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to browse gallery or capture\nfrom camera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_isGenerating) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.surfaceLight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing image ${(_progress * _selectedImages.length).ceil()} of ${_selectedImages.length}...',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generatePdf,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 22),
              label: Text(
                _isGenerating ? 'Generating...' : 'Generate PDF',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Settings Bottom Sheet ───────────────────────────────

  void _showPdfSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'PDF Settings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _SettingsTile(
                  icon: Icons.aspect_ratio,
                  label: 'Page Size',
                  value: _settings.pageSizeLabel,
                  onTap: () {
                    _showOptionPicker<PageSize>(
                      context: context,
                      title: 'Page Size',
                      options: PageSize.values,
                      labels: ['A4', 'Letter', 'Legal', 'A3', 'A5'],
                      current: _settings.pageSize,
                      onSelect: (val) {
                        setState(() => _settings.pageSize = val);
                        setSheetState(() {});
                      },
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.photo_size_select_large,
                  label: 'Image Quality',
                  value: _settings.qualityLabel,
                  onTap: () {
                    _showOptionPicker<ImageQuality>(
                      context: context,
                      title: 'Image Quality',
                      options: ImageQuality.values,
                      labels: ['Low', 'Medium', 'High', 'Original'],
                      current: _settings.quality,
                      onSelect: (val) {
                        setState(() => _settings.quality = val);
                        setSheetState(() {});
                      },
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.crop_rotate,
                  label: 'Orientation',
                  value: _settings.orientationLabel,
                  onTap: () {
                    _showOptionPicker<PageOrientation>(
                      context: context,
                      title: 'Orientation',
                      options: PageOrientation.values,
                      labels: ['Portrait', 'Landscape'],
                      current: _settings.orientation,
                      onSelect: (val) {
                        setState(() => _settings.orientation = val);
                        setSheetState(() {});
                      },
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.space_bar,
                  label: 'Margin',
                  value: _settings.marginLabel,
                  onTap: () {
                    _showOptionPicker<PageMargin>(
                      context: context,
                      title: 'Margin',
                      options: PageMargin.values,
                      labels: ['None', 'Small', 'Normal', 'Large'],
                      current: _settings.margin,
                      onSelect: (val) {
                        setState(() => _settings.margin = val);
                        setSheetState(() {});
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOptionPicker<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required List<String> labels,
    required T current,
    required void Function(T) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(options.length, (i) {
              final isSelected = options[i] == current;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                ),
                title: Text(
                  labels[i],
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                onTap: () {
                  onSelect(options[i]);
                  Navigator.pop(ctx);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              color: AppColors.textHint, size: 20),
        ],
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dashedBorder.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}