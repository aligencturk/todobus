import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  final Duration duration;
  
  const SplashScreen({
    Key? key,
    required this.child,
    this.duration = const Duration(seconds: 1),
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() {
          _showChild = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showChild) {
      return widget.child;
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Center(
          child: Image.asset(
            'assets/splash.png',
            fit: BoxFit.contain,
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.3,
          ),
        ),
      ),
    );
  }
} 