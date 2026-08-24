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
    final granted = await widget.signals.requestAuthorization();
    if (!granted) {
      await widget.vault.markPushOsDenied();
    }
    widget.onDone();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
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

    final buttonWidth = landscape
        ? (size.width * 0.32).clamp(220.0, 480.0)
        : (size.width * 0.72).clamp(220.0, 400.0);

    Widget button({
      required String label,
      required VoidCallback? onTap,
      required List<Color> gradient,
      Color textColor = Colors.white,
    }) {
      return SizedBox(
        width: buttonWidth,
        height: 60,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0x66101C13), blurRadius: 10, offset: Offset(0, 5)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _busy ? null : onTap,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
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

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        button(
          label: 'Allow notifications',
          onTap: _accept,
          gradient: const [Color(0xFF8FD14F), Color(0xFF5CB330)],
        ),
        const SizedBox(height: 12),
        button(
          label: 'Not now',
          onTap: _skip,
          gradient: const [Color(0xFF3E5B47), Color(0xFF2A4231)],
        ),
      ],
    );

    // Landscape: no SafeArea, centre horizontally so the notch does not
    // skew the buttons off the artwork.
    final actionLayer = landscape
        ? Align(alignment: const Alignment(0, 0.58), child: actions)
        : SafeArea(child: Align(alignment: const Alignment(0, 0.72), child: actions));

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
