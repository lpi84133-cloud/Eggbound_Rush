import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/era_hatch_config.dart';
import '../infra/egg_signal_hub.dart';
import '../infra/nest_vault.dart';

/// Push-permission opt-in shown once before the paid-campaign content
/// shell mounts. Accept triggers the system dialog; Skip snoozes the
/// screen for `pushSnoozeSeconds` (rotated away from the sibling default).
class FeatherInvitation extends StatefulWidget {
  const FeatherInvitation({
    super.key,
    required this.vault,
    required this.signals,
    required this.onDone,
  });

  final NestVault vault;
  final EggSignalHub signals;
  final VoidCallback onDone;

  @override
  State<FeatherInvitation> createState() => _FeatherInvitationState();
}

class _FeatherInvitationState extends State<FeatherInvitation> {
  bool _busy = false;

  static const List<Color> _fill = <Color>[
    Color(0xFF8FD14F),
    Color(0xFF5CB330),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.vault.markInviteShown();
    final granted = await widget.signals.requestAuthorization();
    if (!granted) {
      await widget.vault.markPushOsDenied();
    }
    widget.onDone();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.vault.markInviteShown();
    await widget.vault.snoozePushUntil(
      DateTime.now().add(
        const Duration(seconds: EraHatchConfig.pushSnoozeSeconds),
      ),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final bg = landscape
        ? 'assets/hatchway/notify/Horizontal_Notifications_Screen.webp'
        : 'assets/hatchway/notify/Vertical_Notifications_Screen.webp';

    // Identical size + colour on both buttons. Landscape sits them in a
    // tight row (Accept then Skip) so they do not cover the baked-in copy.
    final buttonWidth = landscape
        ? (size.width * 0.28).clamp(168.0, 280.0)
        : (size.width * 0.72).clamp(220.0, 400.0);
    final buttonHeight = landscape ? 54.0 : 60.0;

    Widget pill(String label, VoidCallback onTap) {
      return SizedBox(
        width: buttonWidth,
        height: buttonHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: _fill,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(buttonHeight / 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66101C13),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(buttonHeight / 2),
              onTap: _busy ? null : onTap,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final accept = pill('Accept', _accept);
    final skip = pill('Skip', _skip);

    final actions = landscape
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              accept,
              const SizedBox(width: 14),
              skip,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              accept,
              const SizedBox(height: 12),
              skip,
            ],
          );

    // Landscape: strip every inset so the notch does not shift the
    // horizontal centre. Portrait: keep a tiny bottom gap, buttons sit
    // lower so they clear the baked-in title.
    final actionLayer = landscape
        ? MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            removeTop: true,
            removeBottom: true,
            child: Align(
              alignment: const Alignment(0, 0.82),
              child: actions,
            ),
          )
        : Align(
            alignment: const Alignment(0, 0.88),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: actions,
            ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          actionLayer,
        ],
      ),
    );
  }
}
