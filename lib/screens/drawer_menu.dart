import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'GoVista PDF',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your PDF Toolkit',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // Menu Items
            _DrawerItem(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.folder_outlined,
              label: 'All Files',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.camera_alt_outlined,
              label: 'Gallery to PDF',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.merge_type,
              label: 'Merge & Edit',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.document_scanner_outlined,
              label: 'OCR Scanner',
              onTap: () => Navigator.pop(context),
            ),

            const Spacer(),
            const Divider(color: AppColors.border),

            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.info_outline,
              label: 'About',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 24),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
