import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/pdf_file_model.dart';
import '../widgets/feature_card.dart';
import '../widgets/recent_file_tile.dart';
import 'image_to_pdf_screen.dart';
import 'merge_edit_screen.dart';
import 'ocr_screen.dart';
import 'all_files_screen.dart';
import 'drawer_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<PdfFileModel> _recentFiles = [
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const DrawerMenu(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // ✅ FIX: Limits width on web so it looks like a mobile app
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                          child: const Icon(
                            Icons.menu,
                            color: AppColors.textPrimary,
                            size: 28,
                          ),
                        ),
                        const Text(
                          'GoVista PDF',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Icon(
                            Icons.account_circle_outlined,
                            color: AppColors.textPrimary,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Feature Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        FeatureCard(
                          title: 'Gallery to PDF',
                          subtitle:
                              'Convert photos into professional documents',
                          imagePath:
                              'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600',
                          actionIcon: Icons.camera_alt_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ImageToPdfScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        FeatureCard(
                          title: 'Merge & Edit PDF',
                          subtitle: 'Combine files and organize your pages',
                          imagePath:
                              'https://images.unsplash.com/photo-1557683316-973673baf926?w=600',
                          actionIcon: Icons.edit_note_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MergeEditScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        FeatureCard(
                          title: 'OCR Scanner',
                          subtitle:
                              'Extract text from scanned documents',
                          imagePath:
                              'https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=600',
                          actionIcon: Icons.document_scanner_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OcrScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Recent Files Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Files',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllFilesScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recent Files List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RecentFileTile(
                            file: _recentFiles[index],
                            onTap: () {},
                          ),
                        );
                      },
                      childCount: _recentFiles.length,
                    ),
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