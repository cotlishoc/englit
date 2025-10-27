import 'package:cloud_firestore/cloud_firestore.dart';

// --- ИЗМЕНЕНИЕ: Используем Enum для статусов, чтобы избежать ошибок с текстом ---
enum WordStatus { learning, learned }

class UserWordModel {
  final String wordId;
  WordStatus status; // "learning", "learned"
  
  // --- ИЗМЕНЕНИЕ: Поля для системы интервального повторения (SRS) ---
  int stage; // Уровень/коробка в системе SRS (например, от 0 до 8)
  Timestamp lastRepetition; // Когда последний раз отвечали
  Timestamp nextRepetition; // Когда нужно повторить в следующий раз

  // --- ИЗМЕНЕНИЕ: Поля для статистики ---
  int correctAnswers;
  int incorrectAnswers;

  UserWordModel({
    required this.wordId,
    this.status = WordStatus.learning,
    this.stage = 0,
    required this.lastRepetition,
    required this.nextRepetition,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
  });

  factory UserWordModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserWordModel(
      wordId: documentId,
      // Преобразуем строку из Firestore в наш Enum
      status: (data['status'] == 'learned') ? WordStatus.learned : WordStatus.learning,
      stage: data['stage'] ?? 0,
      lastRepetition: data['lastRepetition'] ?? Timestamp.now(),
      nextRepetition: data['nextRepetition'] ?? Timestamp.now(),
      correctAnswers: data['correctAnswers'] ?? 0,
      incorrectAnswers: data['incorrectAnswers'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // Преобразуем Enum обратно в строку для Firestore
      'status': status == WordStatus.learned ? 'learned' : 'learning',
      'stage': stage,
      'lastRepetition': lastRepetition,
      'nextRepetition': nextRepetition,
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
    };
  }
}