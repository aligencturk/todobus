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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splash.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
} 