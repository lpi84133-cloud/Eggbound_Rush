import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../boot/boot_controller.dart';
import '../customization/customization_screen.dart';
import '../info/document_screen.dart';
import '../info/help_screen.dart';
import '../pasture/pasture_controller.dart';
import '../shell/orbit_menu.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final notice = ref.watch(servicesProvider).notice;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'Settings',
            subtitle: 'All data stays on this device',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 120),
              children: [
                const SectionTitle('Feedback'),
                SoftCard(
                  child: Column(
                    children: [
                      _SwitchRow(
                        icon: Icons.volume_up_rounded,
                        title: 'Interface sounds',
                        subtitle: 'Short confirmations for your actions',
                        value: settings.soundEnabled,
                        onChanged: controller.setSound,
                      ),
                      const Divider(height: AppGap.lg),
                      _SwitchRow(
                        icon: Icons.vibration_rounded,
                        title: 'Haptics',
                        subtitle: 'A light tap when something is placed',
                        value: settings.hapticsEnabled,
                        onChanged: controller.setHaptics,
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Pasture'),
                SoftCard(
                  child: Column(
                    children: [
                      _SwitchRow(
                        icon: Icons.dashboard_customize_rounded,
                        title: 'Show zone frames',
                        subtitle: 'Overlay the named areas on the board',
                        value: settings.showZones,
                        onChanged: controller.setShowZones,
                      ),
                      const Divider(height: AppGap.lg),
                      _GoalRow(
                        value: settings.dailyGoal,
                        onChanged: controller.setDailyGoal,
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Reminders'),
                SoftCard(
                  child: Column(
                    children: [
                      _SwitchRow(
                        icon: Icons.notifications_active_rounded,
                        title: 'Daily reminder',
                        subtitle: 'A gentle nudge to collect and log eggs',
                        value: settings.remindersEnabled,
                        onChanged: controller.setRemindersEnabled,
                      ),
                      const Divider(height: AppGap.lg),
                      _ReminderTimeRow(
                        time: TimeOfDay(
                          hour: settings.reminderHour,
                          minute: settings.reminderMinute,
                        ),
                        enabled: settings.remindersEnabled,
                        onTap: _pickReminderTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppGap.md),
                _LinkRow(
                  icon: Icons.palette_rounded,
                  title: 'Themes and decor',
                  subtitle: 'Change how the pasture looks',
                  onTap: () => Navigator.of(context).push(
                    orbitRoute(const CustomizationScreen()),
                  ),
                ),
                const SectionTitle('Your data'),
                _LinkRow(
                  icon: Icons.ios_share_rounded,
                  title: _exporting ? 'Preparing export…' : 'Export data',
                  subtitle: 'Save a JSON copy of everything you created',
                  onTap: _exporting ? null : _exportData,
                ),
                _LinkRow(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Reset local data',
                  subtitle: 'Erase the pasture, eggs, zones and history',
                  danger: true,
                  onTap: _confirmReset,
                ),
                const SizedBox(height: AppGap.sm),
                const InfoNote(
                  'There is no account and no cloud backup, so an export is the '
                  'only way to carry your records to another device.',
                ),
                const SectionTitle('About'),
                _LinkRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & documents',
                  subtitle: 'How it works, FAQ, privacy and support',
                  onTap: () => Navigator.of(context).push(
                    orbitRoute(const HelpScreen()),
                  ),
                ),
                _LinkRow(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  subtitle: 'Offline copy, with an online version available',
                  onTap: () => Navigator.of(context).push(
                    orbitRoute(
                      DocumentScreen(
                        title: 'Privacy Policy',
                        assetPath: 'assets/docs/privacy.html',
                        onlineUrl: notice.privacyUrl,
                      ),
                    ),
                  ),
                ),
                _LinkRow(
                  icon: Icons.support_agent_rounded,
                  title: 'Support',
                  subtitle: 'Answers to the most common questions',
                  onTap: () => Navigator.of(context).push(
                    orbitRoute(
                      DocumentScreen(
                        title: 'Support',
                        assetPath: 'assets/docs/support.html',
                        onlineUrl: notice.supportUrl,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppGap.md),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/app/branding/wordmark.png',
                        width: 130,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _version.isEmpty
                            ? 'Eggbound Rush'
                            : 'Eggbound Rush · $_version',
                        style: AppText.caption,
                      ),
                      Text('Works fully offline', style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final payload = await ref.read(servicesProvider).stats.exportPayload();
      final directory = await getTemporaryDirectory();
      final file = File(p.join(
        directory.path,
        'eggbound-rush-export-${DateTime.now().millisecondsSinceEpoch}.json',
      ));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Eggbound Rush data export',
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final settings = ref.read(settingsControllerProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (picked != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setReminderTime(picked.hour, picked.minute);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('Reset local data?', style: AppText.title),
        content: Text(
          'This erases your pasture layout, every egg record, your zones and '
          'the whole history log, and puts back the starter layout. Your '
          'profile name and photo are kept. This cannot be undone.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Reset',
              style: AppText.bodyStrong.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(pastureControllerProvider.notifier).resetEverything();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data reset')),
      );
    }
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.meadow),
        const SizedBox(width: AppGap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.bodyStrong),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final TimeOfDay time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: AppColors.meadow),
          const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reminder time', style: AppText.bodyStrong),
                Text(
                  enabled
                      ? 'Tap to change when it arrives'
                      : 'Turn the reminder on to set a time',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.shell,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  time.format(context),
                  style: AppText.section.copyWith(color: AppColors.barkDeep),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.flag_rounded, size: 20, color: AppColors.meadow),
        const SizedBox(width: AppGap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily collection goal', style: AppText.bodyStrong),
              Text(
                'Shown on the pasture and in Statistics',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        _StepperButton(
          icon: Icons.remove_rounded,
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppText.section,
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          onTap: value < 20 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: AppColors.shell,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: AppColors.barkDeep),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.meadow;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGap.sm),
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: danger
                  ? AppColors.danger.withValues(alpha: 0.12)
                  : AppColors.shell,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppGap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.bodyStrong.copyWith(
                      color: danger ? AppColors.danger : AppColors.ink,
                    ),
                  ),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
