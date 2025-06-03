import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/firebase_messaging_service.dart';
import '../services/logger_service.dart';

/// Bildirim durumları
enum NotificationState {
  initial,
  loading,
  success,
  error,
}

/// Bildirim verisi modeli
class NotificationData {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  final bool isRead;

  NotificationData({
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  factory NotificationData.fromRemoteMessage(RemoteMessage message) {
    return NotificationData(
      title: message.notification?.title ?? 'Bildirim',
      body: message.notification?.body ?? '',
      data: message.data,
      receivedAt: DateTime.now(),
    );
  }

  NotificationData markAsRead() {
    return NotificationData(
      title: title,
      body: body,
      data: data,
      receivedAt: receivedAt,
      isRead: true,
    );
  }

  @override
  String toString() {
    return 'NotificationData(title: $title, body: $body, data: $data, receivedAt: $receivedAt, isRead: $isRead)';
  }
}

/// Bildirimleri yöneten ViewModel
class NotificationViewModel extends ChangeNotifier {
  final FirebaseMessagingService _messagingService;
  final LoggerService _logger = LoggerService();
  
  NotificationState _state = NotificationState.initial;
  String? _errorMessage;
  List<NotificationData> _notifications = [];
  bool _hasPermission = false;
  String? _fcmToken;
  int _unreadCount = 0;

  NotificationViewModel(this._messagingService) {
    _logger.i('NotificationViewModel başlatıldı');
    _initialize();
  }

  // Getters
  NotificationState get state => _state;
  String? get errorMessage => _errorMessage;
  List<NotificationData> get notifications => List.unmodifiable(_notifications);
  bool get hasPermission => _hasPermission;
  String? get fcmToken => _fcmToken;
  int get unreadCount => _unreadCount;

  /// ViewModel'i başlat
  Future<void> _initialize() async {
    _logger.i('NotificationViewModel başlatılıyor...');
    _setState(NotificationState.loading);
    
    try {
      // Bildirim tıklama dinleyicisi ekle
      _messagingService.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // İzin kontrolü
      final NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
      _hasPermission = settings.authorizationStatus == AuthorizationStatus.authorized;
      _logger.i('Bildirim izni: $_hasPermission');
      
      // FCM token'ı al
      await fetchFcmToken();
      
      // Başarılı
      _setState(NotificationState.success);
    } catch (e) {
      _logger.e('Bildirim servisi başlatılamadı: $e');
      _setError('Bildirim servisi başlatılamadı: $e');
    }
  }

  /// FCM token'ını al
  Future<void> fetchFcmToken() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      _logger.i('FCM Token alındı: $_fcmToken');
      notifyListeners();
    } catch (e) {
      _logger.e('FCM Token alınamadı: $e');
    }
  }

  /// FCM token'ını kopyalamak için
  String getFcmToken() {
    return _fcmToken ?? 'Token bulunamadı';
  }

  /// Bildirim tıklanma olayını işle
  void _handleNotificationTap(RemoteMessage message) {
    _logger.i('Bildirime tıklandı: ${message.messageId}');
    final notification = NotificationData.fromRemoteMessage(message);
    _addNotification(notification);
    
    // Not: Burada bildirime özel işlemler yapılabilir
    // Örneğin: Navigator.of(context).pushNamed('/detailPage', arguments: {...})
  }

  /// Yeni bildirimlerin kontrolü
  void checkForNewNotifications() {
    _updateUnreadCount();
  }

  /// Bildirimi listeye ekle
  void _addNotification(NotificationData notification) {
    _logger.i('Bildirim ekleniyor: ${notification.title}');
    _notifications.insert(0, notification);
    _updateUnreadCount();
    notifyListeners();
  }

  /// Okunmamış bildirim sayısını güncelle
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  /// Bildirimi okundu olarak işaretle
  void markNotificationAsRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      if (!_notifications[index].isRead) {
        final updatedNotification = _notifications[index].markAsRead();
        _notifications[index] = updatedNotification;
        _updateUnreadCount();
      }
    } else {
      _logger.w('Geçersiz bildirim indeksi: $index');
    }
  }

  /// Tüm bildirimleri okundu olarak işaretle
  void markAllNotificationsAsRead() {
    final List<NotificationData> updatedNotifications = [];
    
    for (final notification in _notifications) {
      if (!notification.isRead) {
        updatedNotifications.add(notification.markAsRead());
      } else {
        updatedNotifications.add(notification);
      }
    }
    
    _notifications = updatedNotifications;
    _unreadCount = 0;
    notifyListeners();
  }

  /// Belirli bir bildirimi kaldır
  void removeNotification(int index) {
    _logger.i('$index indeksindeki bildirim kaldırılıyor');
    if (index >= 0 && index < _notifications.length) {
      final wasUnread = !_notifications[index].isRead;
      _notifications.removeAt(index);
      if (wasUnread) {
        _updateUnreadCount();
      } else {
        notifyListeners();
      }
    } else {
      _logger.w('Geçersiz bildirim indeksi: $index');
    }
  }

  /// Bildirimleri temizle
  void clearNotifications() {
    _logger.i('Bildirimler temizleniyor');
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  /// Belirli bir bildirim konusuna abone ol
  Future<void> subscribeToTopic(String topic) async {
    _logger.i('$topic konusuna abone olunuyor');
    try {
      await _messagingService.subscribeToTopic(topic);
      _logger.i('$topic konusuna abone olundu');
    } catch (e) {
      _logger.e('$topic konusuna abone olunamadı: $e');
      _setError('$topic konusuna abone olunamadı: $e');
    }
  }

  /// Belirli bir bildirim konusundan aboneliği kaldır
  Future<void> unsubscribeFromTopic(String topic) async {
    _logger.i('$topic konusundan abonelik kaldırılıyor');
    try {
      await _messagingService.unsubscribeFromTopic(topic);
      _logger.i('$topic konusundan abonelik kaldırıldı');
    } catch (e) {
      _logger.e('$topic konusundan abonelik kaldırılamadı: $e');
      _setError('$topic konusundan abonelik kaldırılamadı: $e');
    }
  }

  /// Test amaçlı yerel bildirim ekle
  void addTestNotification() {
    _logger.i('Test bildirimi ekleniyor');
    
    final notification = NotificationData(
      title: 'Test Bildirimi',
      body: 'Bu bir test bildirimidir',
      data: {'test': 'data', 'type': 'test'},
      receivedAt: DateTime.now(),
    );
    
    _addNotification(notification);
  }

  /// Durumu güncelle
  void _setState(NotificationState state) {
    _state = state;
    if (state != NotificationState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// Hata durumunu ayarla
  void _setError(String message) {
    _errorMessage = message;
    _setState(NotificationState.error);
  }
} 