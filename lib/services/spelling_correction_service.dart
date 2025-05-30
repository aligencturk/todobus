import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'logger_service.dart';

class SpellingCorrectionService {
  static SpellingCorrectionService? _instance;
  static SpellingCorrectionService get instance {
    _instance ??= SpellingCorrectionService._internal();
    return _instance!;
  }

  SpellingCorrectionService._internal();

  late final GenerativeModel _model;
  final LoggerService _logger = LoggerService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // dotenv'in yüklendiğinden emin ol
      if (!dotenv.isInitialized) {
        _logger.i('dotenv henüz başlatılmamış, main.dart içinde başlatılması gerekiyor');
        return;
      }

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        _logger.e('GEMINI_API_KEY .env dosyasında bulunamadı. Lütfen .env dosyasına GEMINI_API_KEY=your_key_here ekleyin.');
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1, // Düşük temperature yazım düzeltme için daha tutarlı
          maxOutputTokens: 500,
        ),
      );
      _isInitialized = true;
      _logger.i('Gemini AI yazım düzeltme servisi başarıyla başlatıldı');
    } catch (e) {
      _logger.e('Gemini AI servisi başlatılamadı: $e');
    }
  }

  Future<String> correctSpelling(String text) async {
    if (text.trim().isEmpty || !_isInitialized) return text;
    
    try {
      final prompt = '''
Lütfen aşağıdaki Türkçe metindeki SADECE yazım hatalarını düzeltin. Metnin anlamını ve yapısını değiştirmeyin, sadece:
- Yanlış yazılmış kelimeleri düzeltin
- Noktalama işaretlerini düzeltin
- Büyük-küçük harf kullanımını düzeltin

Sadece düzeltilmiş metni döndürün, başka hiçbir açıklama yapmayın.

Metin: "$text"
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text != null) {
        String correctedText = response.text!.trim();
        // Eğer yanıt tırnak içindeyse, tırnakları kaldır
        if (correctedText.startsWith('"') && correctedText.endsWith('"')) {
          correctedText = correctedText.substring(1, correctedText.length - 1);
        }
        return correctedText;
      }
      
      return text; // Hata durumunda orijinal metni döndür
    } catch (e) {
      _logger.e('Yazım düzeltme hatası: $e');
      return text; // Hata durumunda orijinal metni döndür
    }
  }

  Future<bool> isServiceAvailable() async {
    if (!_isInitialized) return false;
    
    try {
      final response = await _model.generateContent([Content.text('Test')]);
      return response.text != null;
    } catch (e) {
      _logger.e('Yazım düzeltme servisi kullanılamıyor: $e');
      return false;
    }
  }
} 