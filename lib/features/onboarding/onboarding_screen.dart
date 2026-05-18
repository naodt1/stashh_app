import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/router/app_router.dart';

// ─── Design tokens (matches DESIGN.md) ───────────────────────────────────────
const _black    = Color(0xFF000000);
const _white    = Color(0xFFFFFFFF);
const _grey100  = Color(0xFFF5F5F5);
const _grey300  = Color(0xFFD4D4D4);
const _grey500  = Color(0xFF737373);

// Greyscale color filter matrix
const _greyscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      label: 'SAVE',
      headline: 'Save anything,\nfrom anywhere.',
      body: 'Share reels, links, PDFs and messages from any app — Stowe catches everything automatically.',
      imageUrl: 'https://images.unsplash.com/photo-1611162616305-c69b3fa7fbe0?w=800&q=80',
    ),
    _SlideData(
      label: 'ORGANIZE',
      headline: 'AI sorts it\nthe second you save.',
      body: 'No folders to manage. No tagging needed. Just save and Stowe organises the rest.',
      imageUrl: 'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=800&q=80',
    ),
    _SlideData(
      label: 'FIND',
      headline: 'Find anything\nin two taps.',
      body: 'Every link, reel and note you\'ve ever saved — searchable in seconds.',
      imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=800&q=80',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    markOnboardingComplete(); // update in-memory flag so router allows /login
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomControls(
              currentPage: _currentPage,
              totalPages: _slides.length,
              onNext: _next,
              onSkip: _finish,
              pageController: _pageController,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide page ───────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _SlideData slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final imageHeight = size.height * 0.50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero image ──────────────────────────────────────────────────────
        SizedBox(
          height: imageHeight + topPad,
          width: double.infinity,
          child: ColorFiltered(
            colorFilter: _greyscale,
            child: CachedNetworkImage(
              imageUrl: slide.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: _grey100),
              errorWidget: (_, __, ___) => Container(
                color: _grey100,
                child: const Icon(Icons.image_outlined,
                    size: 48, color: _grey300),
              ),
            ),
          ),
        ),

        // ── Text content ─────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _grey100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      slide.label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _grey500,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ).animate()
                      .fadeIn(delay: 80.ms, duration: 350.ms)
                      .slideY(begin: 0.15, end: 0),

                  const SizedBox(height: 16),

                  // Headline
                  Text(
                    slide.headline,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: _black,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ).animate()
                      .fadeIn(delay: 140.ms, duration: 350.ms)
                      .slideY(begin: 0.15, end: 0),

                  const SizedBox(height: 14),

                  // Body
                  Text(
                    slide.body,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _grey500,
                      height: 1.65,
                    ),
                  ).animate()
                      .fadeIn(delay: 200.ms, duration: 350.ms)
                      .slideY(begin: 0.15, end: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom controls ──────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final PageController pageController;

  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onSkip,
    required this.pageController,
  });

  bool get _isLast => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(28, 16, 28, bottom + 20),
      decoration: const BoxDecoration(
        color: _white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page dots
          SmoothPageIndicator(
            controller: pageController,
            count: totalPages,
            effect: const ExpandingDotsEffect(
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 4,
              spacing: 6,
              activeDotColor: _black,
              dotColor: _grey300,
            ),
          ),

          const SizedBox(height: 24),

          // CTA button
          GestureDetector(
            onTap: onNext,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: _black,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _isLast ? 'Get Started' : 'Continue',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Skip
          AnimatedOpacity(
            opacity: _isLast ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: GestureDetector(
              onTap: _isLast ? null : onSkip,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Skip',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _grey300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _SlideData {
  final String label;
  final String headline;
  final String body;
  final String imageUrl;

  const _SlideData({
    required this.label,
    required this.headline,
    required this.body,
    required this.imageUrl,
  });
}
