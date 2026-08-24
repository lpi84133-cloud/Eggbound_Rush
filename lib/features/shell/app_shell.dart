import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/surfaces.dart';
import '../boot/boot_controller.dart';
import '../catalog/catalog_screen.dart';
import '../customization/customization_screen.dart';
import '../feed/feed_screen.dart';
import '../flock/flock_screen.dart';
import '../history/history_screen.dart';
import '../info/help_screen.dart';
import '../pasture/pasture_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../today/today_screen.dart';
import '../zones/zones_screen.dart';
import 'orbit_menu.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _menuKey = GlobalKey<OrbitMenuState>();
  bool _menuOpen = false;

  // Built once so AppShell.build() never re-allocates them when the
  // menu opens/closes.
  late final List<OrbitDestination> _destinations;

  @override
  void initState() {
    super.initState();
    _destinations = [
      OrbitDestination(
        icon: Icons.pets_rounded,
        label: 'My flock',
        onSelected: () => _open(const FlockScreen()),
      ),
      OrbitDestination(
        icon: Icons.insights_rounded,
        label: 'Stats',
        onSelected: () => _open(const StatsScreen()),
      ),
      OrbitDestination(
        icon: Icons.payments_rounded,
        label: 'Feed & costs',
        onSelected: () => _open(const FeedScreen()),
      ),
      OrbitDestination(
        icon: Icons.map_rounded,
        label: 'Coop layout',
        onSelected: () => _open(PastureScreen(onOpenCatalog: _openCatalog)),
      ),
      OrbitDestination(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        onSelected: _showMoreSheet,
      ),
    ];
  }

  void _open(Widget page) {
    ref.read(servicesProvider).feedback.tapFeedback();
    Navigator.of(context).push(orbitRoute<void>(page));
  }

  void _openCatalog() {
    ref.read(servicesProvider).feedback.tapFeedback();
    Navigator.of(context).push(orbitRoute<void>(const CatalogScreen()));
  }

  void _showMoreSheet() {
    ref.read(servicesProvider).feedback.tapFeedback();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _MoreSheet(
        onSelected: (page) {
          Navigator.of(sheetContext).pop();
          _open(page);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // RepaintBoundary keeps the dashboard's raster cache intact when the
        // menu overlay fades in or out above it.
        const RepaintBoundary(child: TodayScreen()),
        if (_menuOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _menuKey.currentState?.close(),
              child: const ColoredBox(color: Color(0x40151A14)),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
          child: OrbitMenu(
            key: _menuKey,
            destinations: _destinations,
            onToggle: (open) => setState(() => _menuOpen = open),
          ),
        ),
      ],
    );
  }
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.onSelected});

  final void Function(Widget page) onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String, Widget)>[
      (
        Icons.dashboard_customize_rounded,
        'Coop areas',
        'Name the nesting, feeding and water areas in your run',
        const ZonesScreen(),
      ),
      (
        Icons.history_rounded,
        'Activity log',
        'Everything you have recorded, newest first',
        const HistoryScreen(),
      ),
      (
        Icons.palette_rounded,
        'Appearance',
        'Backgrounds and markers for the coop layout',
        const CustomizationScreen(),
      ),
      (
        Icons.person_rounded,
        'Profile',
        'Your name, photo and keeping totals',
        const ProfileScreen(),
      ),
      (
        Icons.settings_rounded,
        'Settings',
        'Sound, daily target and your local data',
        const SettingsScreen(),
      ),
      (
        Icons.help_outline_rounded,
        'Help & documents',
        'How it works, FAQ, privacy and support',
        const HelpScreen(),
      ),
    ];

    return AppSheet(
      title: 'More',
      subtitle: 'Secondary tools and everything about your data',
      children: [
        RowGroup(
          children: [
            for (final (icon, title, subtitle, page) in entries)
              AppRow(
                leading: IconChip(icon: icon),
                title: title,
                detail: subtitle,
                chevron: true,
                onTap: () => onSelected(page),
              ),
          ],
        ),
        const SizedBox(height: AppGap.md),
      ],
    );
  }
}
