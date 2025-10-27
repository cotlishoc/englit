import 'package:cloud_firestore/cloud_firestore.dart';

class WordModel {
  final String id;
  final String word;
  final String translation;
  final String transcription;
  final String example;
  final DocumentReference? category;

  WordModel({
    required this.id,
    required this.word,
    required this.translation,
    required this.transcription,
    required this.example,
    this.category,
  });

  factory WordModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return WordModel(
      id: documentId,
      word: data['word'] ?? '',
      translation: data['translation'] ?? '',
      transcription: data['transcription'] ?? '',
      example: data['example'] ?? '',
      category: data['category'] as DocumentReference?,
    );
  }
  
  factory WordModel.fromCustom(Map<String, dynamic> data, String documentId) {
    return WordModel(
      id: documentId,
      word: data['word'] ?? '',
      translation: data['translation'] ?? '',
      transcription: '', // У кастомных слов нет этих полей
      example: '',
      category: null,
    );
  }
}