import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/onboarding_service.dart';
import '../services/logger_service.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  final LoggerService _logger = LoggerService();
  int _currentIndex = 0;

  late List<VideoPlayerController> _controllers;
  List<bool> _videoStates = [false, false, false]; // Her videonun durumunu takip et
  bool _isInitialized = false;
  String _errorMessage = '';

  // Video asset path'leri
  final List<String> _videoPaths = [
    'assets/onboarding/1.mp4',
    'assets/onboarding/2.mp4', 
    'assets/onboarding/3.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    try {
      _logger.i('Video kontrolcüleri başlatılıyor...');
      
      _controllers = _videoPaths.map((path) => 
        VideoPlayerController.asset(path)
      ).toList();

      // Her video için ayrı ayrı initialization
      for (int i = 0; i < _controllers.length; i++) {
        try {
          await _controllers[i].initialize();
          _controllers[i].setLooping(true);
          _videoStates[i] = true;
          _logger.i('Video ${i + 1} başarıyla yüklendi');
        } catch (error) {
          _logger.e('Video ${i + 1} yüklenirken hata: $error');
          _videoStates[i] = false;
        }
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // İlk videoyu oynat (eğer yüklendiyse)
        if (_videoStates[0] && _controllers[0].value.isInitialized) {
          await _controllers[0].play();
          _logger.i('İlk video oynatılıyor');
        }
      }
    } catch (e) {
      _logger.e('Video kontrolcüleri başlatılırken hata: $e');
      setState(() {
        _errorMessage = 'Videolar yüklenirken hata oluştu: $e';
        _isInitialized = true; // Hata olsa bile UI'yi göster
      });
    }
  }

  @override
  void dispose() {
    _logger.i('Onboarding view dispose ediliyor');
    for (var controller in _controllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _controllers.length - 1) {
      // Mevcut videoyu durdur
      if (_videoStates[_currentIndex] && _controllers[_currentIndex].value.isInitialized) {
        _controllers[_currentIndex].pause();
      }
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      await OnboardingService.setOnboardingCompleted();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      _logger.e('Onboarding tamamlanırken hata: $e');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      // Önceki videoyu durdur
      if (_currentIndex < _controllers.length && 
          _videoStates[_currentIndex] && 
          _controllers[_currentIndex].value.isInitialized) {
        _controllers[_currentIndex].pause();
      }
      
      _currentIndex = index;
      
      // Yeni videoyu oynat
      if (index < _controllers.length && 
          _videoStates[index] && 
          _controllers[index].value.isInitialized) {
        _controllers[index].play();
        _logger.i('Video ${index + 1} oynatılıyor');
      }
    });
  }

  Widget _buildVideoPage(int index) {
    // Video yüklenmediyse placeholder göster
    if (!_videoStates[index] || !_controllers[index].value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Video ${index + 1} yükleniyor...',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controllers[index].value.size.width,
              height: _controllers[index].value.size.height,
              child: VideoPlayer(_controllers[index]),
            ),
          ),
        ),
        // Video mute/unmute kontrolü
        Positioned(
          top: 50,
          right: 20,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (_controllers[index].value.volume > 0) {
                  _controllers[index].setVolume(0);
                } else {
                  _controllers[index].setVolume(1);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _controllers[index].value.volume > 0 
                    ? Icons.volume_up 
                    : Icons.volume_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Videolar hazırlanıyor...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Eğer hiçbir video yüklenmediyse, basit bir onboarding göster
    if (_videoStates.every((state) => !state)) {
      return _buildFallbackOnboarding();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _controllers.length,
            itemBuilder: (context, index) => _buildVideoPage(index),
          ),
          
          // Sayfa göstergeleri
          Positioned(
            bottom: 120,
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
          
          // Skip butonu
          Positioned(
            top: 50,
            left: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Geç'),
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
                elevation: 4,
              ),
              child: Text(
                _currentIndex < _controllers.length - 1 ? 'İlerle' : 'Başla',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Videolar yüklenmediğinde gösterilecek fallback onboarding
  Widget _buildFallbackOnboarding() {
    final List<Map<String, String>> onboardingData = [
      {
        'title': 'TodoBus\'a Hoş Geldiniz',
        'description': 'Görevlerinizi ve projelerinizi kolayca yönetin',
      },
      {
        'title': 'Ekibinizle İşbirliği Yapın',
        'description': 'Grup projelerinde etkin bir şekilde çalışın',
      },
      {
        'title': 'Başarıya Ulaşın',
        'description': 'Hedeflerinizi takip edin ve başarıya ulaşın',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: onboardingData.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  index == 0 ? Icons.task_alt : 
                  index == 1 ? Icons.group : Icons.emoji_events,
                  size: 120,
                  color: Colors.white,
                ),
                const SizedBox(height: 48),
                Text(
                  onboardingData[index]['title']!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  onboardingData[index]['description']!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 