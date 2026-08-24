import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/preferences_repository.dart';
import '../../data/stats_repository.dart';
import 'avatar_editor.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final stats = ref.watch(statsProvider(StatsRange.all)).value;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'Profile',
            subtitle: 'Stored on this device only',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, AppGap.lg, 16, 120),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ProfileAvatar(profile: profile, size: 116),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: AppColors.meadow,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () =>
                                    _showPhotoOptions(context, ref, profile),
                                child: const SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: Icon(
                                    Icons.photo_camera_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppGap.md),
                      Text(profile.name, style: AppText.display),
                      if (profile.joinedAt != null)
                        Text(
                          'Keeping this pasture since '
                          '${DateFormat('MMMM d, y').format(profile.joinedAt!)}',
                          style: AppText.caption,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppGap.lg),
                PillButton(
                  label: 'Edit display name',
                  icon: Icons.edit_rounded,
                  tone: PillTone.quiet,
                  expand: true,
                  onPressed: () => _editName(context, ref, profile),
                ),
                const SectionTitle('Your totals'),
                SoftCard(
                  child: Column(
                    children: [
                      _TotalRow(
                        icon: Icons.check_circle_rounded,
                        label: 'Eggs collected all time',
                        value: '${stats?.eggsCollected ?? 0}',
                      ),
                      const Divider(height: AppGap.lg),
                      _TotalRow(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Active day streak',
                        value: '${stats?.streakDays ?? 0}',
                      ),
                      const Divider(height: AppGap.lg),
                      _TotalRow(
                        icon: Icons.eco_rounded,
                        label: 'Care Points',
                        value: '${stats?.carePoints ?? 0}',
                      ),
                      const Divider(height: AppGap.lg),
                      _TotalRow(
                        icon: Icons.grid_view_rounded,
                        label: 'Objects on the pasture',
                        value: '${stats?.objectsPlaced ?? 0}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppGap.lg),
                const InfoNote(
                  'Your photo and name never leave this device. There is no '
                  'account and nothing is uploaded.',
                  icon: Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('Display name', style: AppText.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await ref.read(profileControllerProvider.notifier).setName(result);
    }
  }

  Future<void> _showPhotoOptions(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: AppRadius.brLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppGap.md),
              Text('Profile photo', style: AppText.title),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'The photo is cropped on your device and saved to the app\'s '
                  'private folder.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
              const SizedBox(height: AppGap.sm),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.meadow),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.meadow),
                title: const Text('Choose from library'),
                onTap: () => Navigator.of(sheetContext).pop('gallery'),
              ),
              if (profile.hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  title: const Text('Remove current photo'),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
              const SizedBox(height: AppGap.sm),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;
    if (action == 'remove') {
      await ref.read(profileControllerProvider.notifier).setAvatar(null);
      return;
    }

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo access is unavailable on this device.'),
          ),
        );
      }
      return;
    }
    if (picked == null || !context.mounted) return;

    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AvatarEditor(sourceFile: File(picked!.path)),
        fullscreenDialog: true,
      ),
    );
    if (path == null) return;
    await ref.read(profileControllerProvider.notifier).setAvatar(path);
    imageCache.clear();
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 48});

  final UserProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final file = profile.avatarPath == null ? null : File(profile.avatarPath!);
    final hasFile = file != null && file.existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.shell,
        border: Border.all(color: AppColors.grassSoft, width: 2.5),
        boxShadow: AppShadow.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasFile
          ? Image.file(file, fit: BoxFit.cover)
          : Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: Image.asset(
                'assets/app/images/chicken_idle.png',
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.amber),
        const SizedBox(width: AppGap.md),
        Expanded(child: Text(label, style: AppText.body)),
        Text(value, style: AppText.bodyStrong),
      ],
    );
  }
}
