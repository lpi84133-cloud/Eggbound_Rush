import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// No-internet screen with a large retry button.
///
/// Two retry modes:
///   * [retryBuilder] — replace the navigator with a fresh gate (first
///     launch / returning gray with no live WebView).
///   * [onRetry] — keep the current tree (in-session overlay on top of
///     the WebView so reconnect resumes the same page, not notify).
class EmptyAirPage extends StatefulWidget {
  const EmptyAirPage({
    super.key,
    this.retryBuilder,
    this.onRetry,
  }) : assert(retryBuilder != null || onRetry != null);

  final WidgetBuilder? retryBuilder;
  final VoidCallback? onRetry;

  @override
  State<EmptyAirPage> createState() => _EmptyAirPageState();
}

class _EmptyAirPageState extends State<EmptyAirPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // BootScreen locks portrait on hand-off — re-enable full rotation for
    // this screen so the landscape backdrop is reachable.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (widget.onRetry != null) {
      widget.onRetry!();
      if (mounted) setState(() => _busy = false);
      return;
    }
    // Replace the entire gate subtree — never pop with the (possibly
    // unmounted) parent's context.
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(builder: widget.retryBuilder!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final bg = landscape
        ? 'assets/hatchway/nowifi/Horizontal_Nowifi_Screen.webp'
        : 'assets/hatchway/nowifi/Vertical_Nowifi_Screen.webp';

    final buttonWidth = landscape
        ? (size.width * 0.35).clamp(220.0, 520.0)
        : (size.width * 0.70).clamp(220.0, 380.0);

    final button = SizedBox(
      width: buttonWidth,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8FD14F), Color(0xFF5CB330)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(31),
          boxShadow: const [
            BoxShadow(color: Color(0x66101C13), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(31),
            onTap: _busy ? null : _retry,
            child: const Center(
              child: Text(
                'Try again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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

    // Landscape: NO SafeArea + horizontal center — the notch inset would
    // otherwise shift the button off-centre relative to the artwork.
    final buttonLayer = landscape
        ? Align(
            alignment: const Alignment(0, 0.62),
            child: button,
          )
        : SafeArea(
            child: Align(
              alignment: const Alignment(0, 0.72),
              child: button,
            ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover),
          buttonLayer,
        ],
      ),
    );
  }
}
