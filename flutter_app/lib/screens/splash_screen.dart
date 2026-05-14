import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D3D26),
              Color(0xFF1A5C3A),
              Color(0xFF2A7D52),
              Color(0xFF4AA070),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 배경 원형 장식
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              top: 200,
              left: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            // 메인 콘텐츠
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 아이콘 영역
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: const Color(0xFF4AA070).withOpacity(0.4),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                'assets/app_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      // 텍스트 영역
                      SlideTransition(
                        position: _slideAnim,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFB8F0D5)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(bounds),
                                child: const Text(
                                  '냉집사',
                                  style: TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 6,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withOpacity(0.08),
                                ),
                                child: Text(
                                  'AI 냉장고 집사',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withOpacity(0.85),
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                      // 로딩 인디케이터
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
