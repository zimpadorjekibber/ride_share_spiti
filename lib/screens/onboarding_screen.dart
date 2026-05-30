import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      emoji: '🏔️',
      gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      glowColor: Color(0xFF6366F1),
      title: 'Explore Spiti\nValley',
      subtitle:
          'Find shared rides to one of India\'s most remote and breathtaking mountain regions. Connect with local drivers who know every pass.',
      badge: '6,000m passes',
    ),
    _OnboardingData(
      emoji: '🎫',
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      glowColor: Color(0xFF10B981),
      title: 'Book Your\nSeat Instantly',
      subtitle:
          'See available vehicles on a live map, pick your seats visually, and confirm your booking with a single tap. No phone calls needed.',
      badge: 'Real-time seats',
    ),
    _OnboardingData(
      emoji: '🆘',
      gradientColors: [Color(0xFFEF4444), Color(0xFFDC2626)],
      glowColor: Color(0xFFEF4444),
      title: 'Travel Safe\nin Mountains',
      subtitle:
          'Built-in SOS emergency screen with Spiti rescue contacts, live driver tracking, and offline mock data — even without network.',
      badge: 'SOS always ready',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          // PageView
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) =>
                _OnboardingPage(data: _pages[i], size: size),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF090D16).withValues(alpha: 0.95),
                    const Color(0xFF090D16),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? _pages[_currentPage].gradientColors[0]
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons row
                  Row(
                    children: [
                      // Skip
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _finish,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.w500),
                          ),
                        ),

                      const Spacer(),

                      // Next / Get Started
                      GestureDetector(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _pages[_currentPage].gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: _pages[_currentPage]
                                    .glowColor
                                    .withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage < _pages.length - 1
                                    ? 'Next'
                                    : 'Get Started',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage < _pages.length - 1
                                    ? Icons.arrow_forward_rounded
                                    : Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final String emoji;
  final List<Color> gradientColors;
  final Color glowColor;
  final String title;
  final String subtitle;
  final String badge;

  const _OnboardingData({
    required this.emoji,
    required this.gradientColors,
    required this.glowColor,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final Size size;

  const _OnboardingPage({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: size.height * 0.12),

          // Emoji illustration
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: data.glowColor.withValues(alpha: 0.25),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              // Gradient circle
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      data.gradientColors[0].withValues(alpha: 0.2),
                      data.gradientColors[1].withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: data.gradientColors[0].withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(data.emoji, style: const TextStyle(fontSize: 72)),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: data.gradientColors[0].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: data.gradientColors[0].withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '✦  ${data.badge}',
              style: TextStyle(
                color: data.gradientColors[0],
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
