import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/group_models.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  final LoggerService _logger = LoggerService();
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Anahtar sabitleri
  static const String keyUserToken = 'user_token';
  static const String keyUserId = 'user_id';
  static const String keyIsLoggedIn = 'is_logged_in';
  
  // Önbellek anahtarları
  static const String keyUserData = 'user_data';
  static const String keyUserTasks = 'user_tasks';
  static const String keyUpcomingEvents = 'upcoming_events';
  static const String keyGroupList = 'group_list';
  static const String keyLastUpdated = 'last_updated';

  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      _logger.i('StorageService başlatıldı');
    }
  }

  // Token işlemleri
  Future<bool> saveToken(String token) async {
    await _ensureInitialized();
    final result = await _prefs.setString(keyUserToken, token);
    _logger.d('Token kaydedildi: $token');
    return result;
  }

  String? getToken() {
    _ensureInitializedSync();
    return _prefs.getString(keyUserToken);
  }

  // Kullanıcı ID işlemleri
  Future<bool> saveUserId(int userId) async {
    await _ensureInitialized();
    final result = await _prefs.setInt(keyUserId, userId);
    _logger.d('Kullanıcı ID kaydedildi: $userId');
    return result;
  }

  int? getUserId() {
    _ensureInitializedSync();
    return _prefs.getInt(keyUserId);
  }

  // Giriş durumu işlemleri
  Future<bool> setLoggedIn(bool value) async {
    await _ensureInitialized();
    final result = await _prefs.setBool(keyIsLoggedIn, value);
    _logger.d('Giriş durumu kaydedildi: $value');
    return result;
  }

  bool isLoggedIn() {
    _ensureInitializedSync();
    return _prefs.getBool(keyIsLoggedIn) ?? false;
  }

  // Çıkış işlemi
  Future<bool> clearUserData() async {
    await _ensureInitialized();
    await _prefs.remove(keyUserToken);
    await _prefs.remove(keyUserId);
    await _prefs.remove(keyUserData);
    await _prefs.remove(keyUserTasks);
    await _prefs.remove(keyUpcomingEvents);
    await _prefs.remove(keyGroupList);
    await _prefs.remove(keyLastUpdated);
    final result = await _prefs.setBool(keyIsLoggedIn, false);
    _logger.i('Kullanıcı verileri temizlendi');
    return result;
  }

  // Kullanıcı bilgilerini kaydetme
  Future<void> saveUserFirstname(String userFirstname) async {
    await _ensureInitialized();
    await _prefs.setString('user_firstname', userFirstname);
    _logger.d('Kullanıcı adı kaydedildi: $userFirstname');
  }

  // Kullanıcı adını getirme
  String? getUserFirstname() {
    _ensureInitializedSync();
    return _prefs.getString('user_firstname');
  }

  // Kullanıcı e-postasını kaydetme
  Future<void> saveUserEmail(String userEmail) async {
    await _ensureInitialized();
    await _prefs.setString('user_email', userEmail);
    _logger.d('Kullanıcı e-postası kaydedildi: $userEmail');
  }

  // Kullanıcı e-postasını getirme
  String? getUserEmail() {
    _ensureInitializedSync();
    return _prefs.getString('user_email');
  }

  // Servisin başlatıldığından emin olma
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  void _ensureInitializedSync() {
    if (!_initialized) {
      _logger.w('StorageService henüz başlatılmadı');
    }
  }
  
  // Kullanıcı görevlerini önbelleğe alma
  Future<void> cacheUserTasks(List<UserProjectWork> tasks) async {
    try {
      await _ensureInitialized();
      final tasksJson = tasks.map((task) => task.toJson()).toList();
      final tasksString = jsonEncode(tasksJson);
      await _prefs.setString(keyUserTasks, tasksString);
      await _updateLastCacheTime();
      _logger.d('${tasks.length} görev önbelleğe kaydedildi');
    } catch (e) {
      _logger.e('Görevler önbelleğe kaydedilemedi: $e');
    }
  }
  
  // Önbellekteki kullanıcı görevlerini getirme
  List<UserProjectWork>? getCachedUserTasks() {
    _ensureInitializedSync();
    final tasksString = _prefs.getString(keyUserTasks);
    if (tasksString == null) {
      return null;
    }
    
    try {
      final List<dynamic> tasksList = jsonDecode(tasksString);
      final tasks = tasksList.map((taskJson) => UserProjectWork.fromJson(taskJson)).toList();
      _logger.d('${tasks.length} görev önbellekten alındı');
      return tasks;
    } catch (e) {
      _logger.e('Görevler önbellekten alınamadı: $e');
      return null;
    }
  }
  
  // Kullanıcı bilgisini önbelleğe alma
  Future<void> cacheUserData(User user) async {
    try {
      await _ensureInitialized();
      final userJson = user.toJson();
      final userString = jsonEncode(userJson);
      await _prefs.setString(keyUserData, userString);
      await _updateLastCacheTime();
      _logger.d('Kullanıcı bilgileri önbelleğe kaydedildi');
    } catch (e) {
      _logger.e('Kullanıcı bilgileri önbelleğe kaydedilemedi: $e');
    }
  }
  
  // Önbellekteki kullanıcı bilgisini getirme
  User? getCachedUserData() {
    _ensureInitializedSync();
    final userString = _prefs.getString(keyUserData);
    if (userString == null) {
      return null;
    }
    
    try {
      final userJson = jsonDecode(userString);
      final user = User.fromJson(userJson);
      _logger.d('Kullanıcı bilgileri önbellekten alındı');
      return user;
    } catch (e) {
      _logger.e('Kullanıcı bilgileri önbellekten alınamadı: $e');
      return null;
    }
  }
  
  // Etkinlikleri önbelleğe alma
  Future<void> cacheUpcomingEvents(List<GroupEvent> events) async {
    try {
      await _ensureInitialized();
      final eventsJson = events.map((event) => event.toJson()).toList();
      final eventsString = jsonEncode(eventsJson);
      await _prefs.setString(keyUpcomingEvents, eventsString);
      await _updateLastCacheTime();
      _logger.d('${events.length} etkinlik önbelleğe kaydedildi');
    } catch (e) {
      _logger.e('Etkinlikler önbelleğe kaydedilemedi: $e');
    }
  }
  
  // Önbellekteki etkinlikleri getirme
  List<GroupEvent>? getCachedUpcomingEvents() {
    _ensureInitializedSync();
    final eventsString = _prefs.getString(keyUpcomingEvents);
    if (eventsString == null) {
      return null;
    }
    
    try {
      final List<dynamic> eventsList = jsonDecode(eventsString);
      final events = eventsList.map((eventJson) => GroupEvent.fromJson(eventJson)).toList();
      _logger.d('${events.length} etkinlik önbellekten alındı');
      return events;
    } catch (e) {
      _logger.e('Etkinlikler önbellekten alınamadı: $e');
      return null;
    }
  }
  
  // Grup listesini önbelleğe alma
  Future<void> cacheGroups(List<Group> groups) async {
    try {
      await _ensureInitialized();
      final groupsJson = groups.map((group) => group.toJson()).toList();
      final groupsString = jsonEncode(groupsJson);
      await _prefs.setString(keyGroupList, groupsString);
      await _updateLastCacheTime();
      _logger.d('${groups.length} grup önbelleğe kaydedildi');
    } catch (e) {
      _logger.e('Gruplar önbelleğe kaydedilemedi: $e');
    }
  }
  
  // Önbellekteki grup listesini getirme
  List<Group>? getCachedGroups() {
    _ensureInitializedSync();
    
    try {
      final groupsString = _prefs.getString(keyGroupList);
      if (groupsString == null) {
        return null;
      }
      
      final List<dynamic> groupsList = jsonDecode(groupsString);
      final groups = groupsList.map((groupJson) => Group.fromJson(groupJson)).toList();
      _logger.d('${groups.length} grup önbellekten alındı');
      return groups;
    } catch (e) {
      _logger.e('Gruplar önbellekten alınamadı: $e');
      // Önbellek hatalıysa onu temizle
      _prefs.remove(keyGroupList);
      return null;
    }
  }

  // Son güncelleme zamanını kaydet
  Future<void> _updateLastCacheTime() async {
    await _ensureInitialized();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(keyLastUpdated, now);
  }
  
  // Son güncelleme zamanını al
  DateTime? getLastCacheTime() {
    _ensureInitializedSync();
    
    try {
      final timestamp = _prefs.getInt(keyLastUpdated);
      if (timestamp == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      _logger.e('Son güncelleme zamanı alınamadı: $e');
      return null;
    }
  }
  
  // Önbellek güncel mi kontrol et (2 dakikadan eski ise güncel değil)
  bool isCacheStale() {
    try {
      final lastUpdate = getLastCacheTime();
      if (lastUpdate == null) {
        return true;
      }
      
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);
      return difference.inMinutes > 2; // 2 dakikadan eski ise güncel değil
    } catch (e) {
      _logger.e('Önbellek güncelliği kontrol edilirken hata: $e');
      return true; // Hata durumunda güncel değil kabul et
    }
  }
  
  // Önbelleği tamamen temizle
  Future<void> clearCache() async {
    await _ensureInitialized();
    await _prefs.remove(keyUserTasks);
    await _prefs.remove(keyUpcomingEvents);
    await _prefs.remove(keyGroupList);
    await _prefs.remove(keyLastUpdated);
    _logger.i('Önbellek tamamen temizlendi');
  }
} 