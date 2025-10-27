import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  late FlutterTts _flutterTts;
  bool _isSoundEnabled = true; // По умолчанию звук включен

  // --- ИСПОЛЬЗУЕМ СИНГЛТОН, ЧТОБЫ БЫЛ ТОЛЬКО ОДИН ЭКЗЕМПЛЯР TTS НА ВСЕ ПРИЛОЖЕНИЕ ---
  static final TtsService _instance = TtsService._internal();
  factory TtsService() {
    return _instance;
  }
  TtsService._internal() {
    _flutterTts = FlutterTts();
    _setupTts();
  }
  // --------------------------------------------------------------------------

  Future<void> _setupTts() async {
    // Устанавливаем язык. 'en-US' - американский английский.
    await _flutterTts.setLanguage("en-US");
    // Устанавливаем скорость речи (0.0 - медленно, 1.0 - быстро)
    await _flutterTts.setSpeechRate(0.5);
  }

  // Метод для обновления настроек звука из профиля
  void setSoundEnabled(bool isEnabled) {
    _isSoundEnabled = isEnabled;
    if (!isEnabled) {
      stop();
    }
  }

  Future<void> speak(String text) async {
    // Озвучиваем, только если звук включен в настройках
    if (_isSoundEnabled && text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}