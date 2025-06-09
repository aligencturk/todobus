import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'logger_service.dart';
import '../models/group_models.dart';
import '../models/user_model.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AIAssistantService {
  static AIAssistantService? _instance;
  static AIAssistantService get instance {
    _instance ??= AIAssistantService._internal();
    return _instance!;
  }

  AIAssistantService._internal();

  late final GenerativeModel _model;
  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;
  final List<ChatMessage> _chatHistory = [];

  // Kullanıcı verilerini tutmak için
  User? _currentUser;
  List<Group> _userGroups = [];
  List<UserProjectWork> _userTasks = [];
  List<dynamic> _userProjects = [];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!dotenv.isInitialized) {
        _logger.i('dotenv henüz başlatılmamış, main.dart içinde başlatılması gerekiyor');
        return;
      }

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        _logger.e('GEMINI_API_KEY .env dosyasında bulunamadı.');
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1000,
        ),
      );
      _isInitialized = true;
      _logger.i('AI Asistan servisi başarıyla başlatıldı');
    } catch (e) {
      _logger.e('AI Asistan servisi başlatılamadı: $e');
    }
  }

  // Kullanıcı verilerini güncelle
  void updateUserData({
    User? user,
    List<Group>? groups,
    List<UserProjectWork>? tasks,
    List<dynamic>? projects,
  }) {
    _currentUser = user;
    if (groups != null) _userGroups = groups;
    if (tasks != null) _userTasks = tasks;
    if (projects != null) _userProjects = projects;
  }

  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  Future<String> sendMessage(String message) async {
    if (!_isInitialized) {
      return 'AI Asistan henüz başlatılmamış. Lütfen daha sonra tekrar deneyin.';
    }

    try {
      // Kullanıcı mesajını ekle
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      );
      _chatHistory.add(userMessage);

      // Kullanıcı verilerinden context oluştur
      final userContext = _buildUserContext();
      
      final prompt = '''
Sen TodoBus uygulamasının AI asistanısın. Kullanıcıya Türkçe olarak yardım et.

Kullanıcı Bilgileri:
$userContext

Kullanıcının sorusu: "$message"

Lütfen:
- Sadece Türkçe yanıtla
- Samimi ve yardımsever ol
- Kullanıcının verilerini referans gösterebilirsin
- Proje yönetimi konularında tavsiyelerde bulunabilirsin
- Kısa ve net yanıt ver (maksimum 200 kelime)
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      String assistantResponse = 'Üzgünüm, şu anda yanıt veremiyorum.';
      if (response.text != null) {
        assistantResponse = response.text!.trim();
      }

      // Asistan yanıtını ekle
      final botMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString() + '1',
        text: assistantResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );
      _chatHistory.add(botMessage);

      return assistantResponse;
    } catch (e) {
      _logger.e('AI Asistan yanıt hatası: $e');
      return 'Üzgünüm, bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
    }
  }

  String _buildUserContext() {
    final buffer = StringBuffer();
    
    if (_currentUser != null) {
      buffer.writeln('İsim: ${_currentUser!.userFirstname} ${_currentUser!.userLastname}');
      buffer.writeln('Email: ${_currentUser!.userEmail}');
    }

    buffer.writeln('Grup Sayısı: ${_userGroups.length}');
    if (_userGroups.isNotEmpty) {
      buffer.writeln('Gruplar:');
      for (final group in _userGroups.take(5)) {
        buffer.writeln('- ${group.groupName} (${group.projects.length} proje)');
      }
    }

    buffer.writeln('Toplam Proje Sayısı: ${_userProjects.length}');
    if (_userProjects.isNotEmpty) {
      buffer.writeln('Son Projeler:');
      for (final project in _userProjects.take(5)) {
        final projectName = project is Map ? (project['projectName'] ?? 'Bilinmeyen') : 'Bilinmeyen';
        final groupName = project is Map ? (project['groupName'] ?? 'Bilinmeyen') : 'Bilinmeyen';
        buffer.writeln('- $projectName (Grup: $groupName)');
      }
    }

    final incompleteTasks = _userTasks.where((task) => !task.workCompleted).length;
    final completedTasks = _userTasks.where((task) => task.workCompleted).length;
    buffer.writeln('Görevler: $incompleteTasks tamamlanmamış, $completedTasks tamamlanmış');
    
    if (_userTasks.isNotEmpty) {
      buffer.writeln('Son Görevler:');
      for (final task in _userTasks.take(3)) {
        final status = task.workCompleted ? 'Tamamlandı' : 'Devam ediyor';
        buffer.writeln('- ${task.workName} ($status, ${task.projectName})');
      }
    }

    return buffer.toString();
  }

  void clearChat() {
    _chatHistory.clear();
  }

  bool get isInitialized => _isInitialized;
}

// Dashboard'da kullanmak için proje önizleme sınıfı
class ProjectPreviewItem {
  final int projectID;
  final String projectName;
  final int projectStatusID;
  final int groupID;
  final String groupName;
  
  ProjectPreviewItem({
    required this.projectID,
    required this.projectName,
    required this.projectStatusID,
    required this.groupID,
    required this.groupName,
  });
} 