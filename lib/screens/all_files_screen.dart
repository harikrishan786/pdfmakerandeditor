import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/pdf_file_model.dart';
import '../widgets/recent_file_tile.dart';

class AllFilesScreen extends StatefulWidget {
  const AllFilesScreen({super.key});

  @override
  State<AllFilesScreen> createState() => _AllFilesScreenState();
}

class _AllFilesScreenState extends State<AllFilesScreen> {
  String _sortBy = 'Date';
  bool _isGridView = false;

  // Dummy files
  final List<PdfFileModel> _files = [
    PdfFileModel(
      name: 'Project_Proposal_Final.pdf',
      path: '/dummy/path1.pdf',
      size: '2.4 MB',
      createdAt: 'Created 2 hours ago',
      pageCount: 12,
    ),
    PdfFileModel(
      name: 'Invoice_March_2025.pdf',
      path: '/dummy/path2.pdf',
      size: '1.1 MB',
      createdAt: 'Created yesterday',
      pageCount: 3,
    ),
    PdfFileModel(
      name: 'Scanned_Document.pdf',
      path: '/dummy/path3.pdf',
      size: '5.8 MB',
      createdAt: 'Created 3 days ago',
      pageCount: 8,
    ),
    PdfFileModel(
      name: 'Meeting_Notes.pdf',
      path: '/dummy/path4.pdf',
      size: '0.8 MB',
      createdAt: 'Created 5 days ago',
      pageCount: 4,
    ),
    PdfFileModel(
      name: 'Presentation_Slides.pdf',
      path: '/dummy/path5.pdf',
      size: '12.3 MB',
      createdAt: 'Created 1 week ago',
      pageCount: 24,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'All Files',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // View toggle
                  GestureDetector(
                    onTap: () => setState(() => _isGridView = !_isGridView),
                    child: Icon(
                      _isGridView ? Icons.view_list : Icons.grid_view_rounded,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textHint, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search files...',
                          hintStyle: TextStyle(color: AppColors.textHint),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sort & Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${_files.length} files',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // TODO: sort options
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.sort,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Sort: $_sortBy',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // File List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RecentFileTile(
                      file: _files[index],
                      onTap: () {
                        // TODO: Open PDF
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}