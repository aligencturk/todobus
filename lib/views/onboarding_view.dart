import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/onboarding_service.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late List<VideoPlayerController> _controllers;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    try {
      _controllers = [
        VideoPlayerController.asset('assets/onboarding/1.mp4'),
        VideoPlayerController.asset('assets/onboarding/2.mp4'),
        VideoPlayerController.asset('assets/onboarding/3.mp4'),
      ];

      List<Future<void>> futures = [];
      for (var controller in _controllers) {
        futures.add(controller.initialize().then((_) {
          controller.setLooping(true);
        }).catchError((error) {
          print('Video yüklenirken hata: $error');
        }));
      }

      await Future.wait(futures);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (_controllers.isNotEmpty && _controllers[0].value.isInitialized) {
          _controllers[0].play();
        }
      }
    } catch (e) {
      print('Video kontrolcüleri başlatılırken hata: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _controllers.length - 1) {
      _controllers[_currentIndex].pause();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.setOnboardingCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      if (_currentIndex < _controllers.length) {
        _controllers[_currentIndex].pause();
      }
      _currentIndex = index;
      if (index < _controllers.length && _controllers[index].value.isInitialized) {
        _controllers[index].play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _controllers.length,
            itemBuilder: (context, index) {
              if (!_controllers[index].value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              return SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controllers[index].value.size.width,
                    height: _controllers[index].value.size.height,
                    child: VideoPlayer(_controllers[index]),
                  ),
                ),
              );
            },
          ),
          
          // Sayfa göstergeleri
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _controllers.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentIndex == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index 
                        ? Colors.white 
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          
          // İlerle/Başla butonu
          Positioned(
            bottom: 50,
            right: 32,
            child: ElevatedButton(
              onPressed: _currentIndex < _controllers.length - 1 
                  ? _nextPage 
                  : _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                _currentIndex < _controllers.length - 1 ? 'İlerle' : 'Başla',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 