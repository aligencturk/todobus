import 'package:logger/logger.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  
  factory LoggerService() {
    return _instance;
  }
  
  LoggerService._internal();
  
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  void d(String message) {
    _logger.d(message);
  }

  void i(String message) {
    _logger.i(message);
  }

  void w(String message) {
    _logger.w(message);
  }

  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
} 