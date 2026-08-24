import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/surfaces.dart';

class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.asset,
    required this.bullets,
  });

  final String title;
  final String body;
  final String asset;
  final List<String> bullets;
}

const _slides = <_Slide>[
  _Slide(
    title: 'A record book for backyard chickens',
    body: 'Eggbound Rush is for people who keep hens at home. Add each of '
        'your birds and the app keeps her own page: name, breed, age, egg '
        'colour and whether she is currently laying.',
    asset: 'assets/app/images/chicken_idle.png',
    bullets: [
      'One record per hen, however many you keep',
      'Tells you which birds have stopped laying',
    ],
  ),
  _Slide(
    title: 'Log eggs, health and feed',
    body: 'Record the eggs each hen lays, the worming and mite treatments '
        'you give, and what you pay for feed. Those entries become weekly '
        'output, per-hen productivity and a real cost per egg.',
    asset: 'assets/app/images/egg_golden.png',
    bullets: [
      'Next treatment dates worked out for you',
      'See exactly which hens earn their feed',
    ],
  ),
  _Slide(
    title: 'Everything stays on this device',
    body: 'Your flock records are stored locally and the app works with no '
        'internet connection. There is no account, no sync and no server '
        'holding your data.',
    asset: 'assets/app/images/nest.png',
    bullets: [
      'Export or erase your records at any time',
      'Works offline, in the run, with no signal',
    ],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/app/backgrounds/pasture_green_meadow.webp',
            fit: BoxFit.cover,
          ),
          // The artwork is atmosphere only; the wash keeps text contrast
          // within accessibility limits over any part of it.
          Container(color: AppColors.canvas.withValues(alpha: 0.9)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 620;

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: compact ? AppGap.sm : AppGap.lg,
                        bottom: compact ? 0 : AppGap.sm,
                      ),
                      child: Image.asset(
                        'assets/app/branding/wordmark.png',
                        width: compact ? 140 : 178,
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemBuilder: (context, index) => _SlideView(
                          slide: _slides[index],
                          compact: compact,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _index ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? AppColors.accent
                                  : AppColors.lineStrong,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          24, compact ? AppGap.md : AppGap.lg, 24, AppGap.sm),
                      child: PillButton(
                        label: isLast ? 'Add my first hen' : 'Continue',
                        icon: isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        expand: true,
                        onPressed: _next,
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onFinished(),
                      child: Text(
                        isLast ? 'Skip the tour' : 'Skip',
                        style: AppText.label,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : AppGap.sm),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.compact});

  final _Slide slide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;

    final artwork = Container(
      width: compact ? 108 : 150,
      height: compact ? 108 : 150,
      padding: EdgeInsets.all(compact ? 18 : 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line, width: 2),
        boxShadow: AppShadow.card,
      ),
      child: Image.asset(slide.asset, fit: BoxFit.contain),
    );

    final copy = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          slide.title,
          style: compact ? AppText.title : AppText.display,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: AppGap.sm + 2),
        Text(
          slide.body,
          style: AppText.body,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: AppGap.md + 2),
        for (final bullet in slide.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppGap.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 17, color: AppColors.accent),
                const SizedBox(width: AppGap.sm),
                Flexible(child: Text(bullet, style: AppText.label)),
              ],
            ),
          ),
      ],
    );

    // Scrolling is what actually removes the overflow stripe: on a short
    // screen or with large system text the content simply scrolls instead of
    // being clipped.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? AppGap.sm : AppGap.md,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (MediaQuery.sizeOf(context).height * 0.32)
              .clamp(0.0, double.infinity),
        ),
        child: wide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  artwork,
                  const SizedBox(width: AppGap.xl),
                  Flexible(child: copy),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  artwork,
                  SizedBox(height: compact ? AppGap.md : AppGap.lg),
                  copy,
                ],
              ),
      ),
    );
  }
}
