import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  final Duration duration;
  
  const SplashScreen({
    Key? key,
    required this.child,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    _controller.forward();
    
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() {
          _showChild = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showChild) {
      return widget.child;
    }
    
    return Scaffold(
      body: Container(
        color: const Color(0xFF3949AB),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Animasyonu
              ScaleTransition(
                scale: _animation,
                child: Image.asset(
                  'assets/icon.png',
                  width: 150,
                  height: 150,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Animasyonlu Yazı
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    'TODOBUS',
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                    speed: const Duration(milliseconds: 200),
                  ),
                ],
                totalRepeatCount: 1,
              ),
              
              const SizedBox(height: 50),
              
              // Yükleniyor animasyonu
              const SpinKitThreeBounce(
                color: Colors.white,
                size: 30.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 