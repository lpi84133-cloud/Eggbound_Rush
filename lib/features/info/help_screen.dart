import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';
import '../boot/boot_controller.dart';
import '../shell/orbit_menu.dart';
import 'document_screen.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(servicesProvider).notice;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          RibbonHeader(
            title: 'Help & documents',
            subtitle: 'Everything here is readable offline',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, AppGap.md, 16, 120),
              children: [
                if (notice.hasNotice) ...[
                  SoftCard(
                    color: AppColors.shell,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign_rounded,
                                color: AppColors.amber, size: 20),
                            const SizedBox(width: AppGap.sm),
                            Expanded(
                              child: Text(notice.noticeTitle!,
                                  style: AppText.section),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(notice.noticeBody!, style: AppText.body),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppGap.md),
                ],
                const SectionTitle('Learn the app'),
                _DocTile(
                  icon: Icons.menu_book_rounded,
                  title: 'How it works',
                  subtitle: 'The board, zones, egg tracking and Care Points',
                  onTap: () => Navigator.of(context).push(
                    orbitRoute(
                      const DocumentScreen(
                        title: 'How it works',
                        assetPath: 'assets/docs/how-it-works.html',
                        onlineUrl: 'https://eggboundrush.com',
                      ),
                    ),
                  ),
                ),
                _DocTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Support & FAQ',
                  subtitle: 'Common questions and troubleshooting',
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
                _DocTile(
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  subtitle: 'What is stored, and what never leaves the device',
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
                const SectionTitle('Quick answers'),
                const _FaqTile(
                  question: 'Do I need an internet connection?',
                  answer:
                      'No. Every screen, including these documents, works with '
                      'the connection turned off.',
                ),
                const _FaqTile(
                  question: 'Can I buy Care Points?',
                  answer:
                      'No. There are no purchases of any kind. Points come only '
                      'from using the app and unlock decorative options.',
                ),
                const _FaqTile(
                  question: 'Where is my data stored?',
                  answer:
                      'In the app\'s private storage on this device. You can '
                      'export it or erase it from Settings.',
                ),
                const _FaqTile(
                  question: 'Why does an object sit outside my zones?',
                  answer:
                      'Zones are areas on the board. Drag the object inside a '
                      'zone, or resize the zone frame to cover it.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGap.sm),
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.shell,
              child: Icon(icon, color: AppColors.meadow, size: 20),
            ),
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppGap.sm),
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppGap.md),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppGap.md,
              0,
              AppGap.md,
              AppGap.md,
            ),
            title: Text(question, style: AppText.bodyStrong),
            iconColor: AppColors.meadow,
            collapsedIconColor: AppColors.inkFaint,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(answer, style: AppText.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
