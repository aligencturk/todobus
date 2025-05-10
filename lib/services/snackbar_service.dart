import 'package:flutter/material.dart';
import 'logger_service.dart';

/// Uygulama genelinde SnackBar yönetimi için servis
/// 
/// Bu servis, scaffold bağlantısı olmadan güvenli bir şekilde SnackBar
/// göstermeyi sağlar ve global bir mesaj gösterme mekanizması oluşturur.
class SnackBarService {
  static final SnackBarService _instance = SnackBarService._internal();
  final LoggerService _logger = LoggerService();
  
  // Global anahtar, MaterialApp'da tanımlanacak
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  factory SnackBarService() {
    return _instance;
  }
  
  SnackBarService._internal();
  
  /// Başarı mesajı göster
  void showSuccess(String message, {Duration? duration}) {
    _show(
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      duration: duration ?? const Duration(seconds: 2),
    );
  }
  
  /// Hata mesajı göster
  void showError(String message, {Duration? duration}) {
    _show(
      message,
      backgroundColor: Colors.red,
      icon: Icons.error,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
  
  /// Bilgi mesajı göster
  void showInfo(String message, {Duration? duration}) {
    _show(
      message,
      backgroundColor: Colors.blue,
      icon: Icons.info,
      duration: duration ?? const Duration(seconds: 2),
    );
  }
  
  /// Uyarı mesajı göster
  void showWarning(String message, {Duration? duration}) {
    _show(
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
  
  /// SnackBar göster
  void _show(
    String message, {
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    try {
      // ScaffoldMessenger hazır mı kontrol et
      if (scaffoldMessengerKey.currentState == null) {
        _logger.w('ScaffoldMessenger hazır değil, mesaj gösterilemiyor: $message');
        return;
      }
      
      // Mevcut mesajı kapat
      scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
      
      // Yeni mesajı göster
      scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      _logger.e('SnackBar gösterilirken hata: $e');
    }
  }
  
  /// Hata mesajını formatla (Exception: gibi prefix'leri kaldır)
  String formatErrorMessage(String errorMessage) {
    // Exception: hatası gibi prefix'leri kaldır
    if (errorMessage.startsWith('Exception: ')) {
      errorMessage = errorMessage.substring('Exception: '.length);
    }
    
    // HTTP kodlarını temizle
    final regExp = RegExp(r'\b\d{3}\b');
    errorMessage = errorMessage.replaceAll(regExp, '');
    
    // Teknik detayları içeren uzun hataları kısalt
    if (errorMessage.length > 120) {
      return '${errorMessage.substring(0, 120)}...';
    }
    
    return errorMessage;
  }
} 