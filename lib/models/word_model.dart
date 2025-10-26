import 'package:cloud_firestore/cloud_firestore.dart';

class WordModel {
  final String id;
  final String word;
  final String translation;
  final String transcription;
  final String example;
  final String audioUrl;
  final DocumentReference? category; // Сделаем необязательным для кастомных слов

  WordModel({
    required this.id,
    required this.word,
    required this.translation,
    required this.transcription,
    required this.example,
    required this.audioUrl,
    this.category,
  });

  /// Конструктор для создания объекта из данных Firestore (для обычных слов)
  factory WordModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return WordModel(
      id: documentId,
      word: data['word'] ?? '',
      translation: data['translation'] ?? '',
      transcription: data['transcription'] ?? '',
      example: data['example'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      category: data['category'] as DocumentReference?,
    );
  }

  /// --- ВОТ НЕДОСТАЮЩИЙ МЕТОД ---
  /// Конструктор для создания объекта из данных Firestore (для кастомных слов пользователя)
  factory WordModel.fromCustom(Map<String, dynamic> data, String documentId) {
    return WordModel(
      id: documentId,
      word: data['word'] ?? '',
      translation: data['translation'] ?? '',
      // У кастомных слов нет этих полей, поэтому оставляем их пустыми
      transcription: '',
      example: '',
      audioUrl: '',
      // У кастомных слов нет ссылки на общую категорию
      category: null,
    );
  }
}