import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word_model.dart';
import '../models/user_word_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // --- МЕТОДЫ ДЛЯ ОБЩИХ ДАННЫХ ---

  Stream<QuerySnapshot> getCategoriesStream() {
    return _db.collection('category').orderBy('name').snapshots();
  }
  
  // --- НОВЫЙ ГЛАВНЫЙ МЕТОД ДЛЯ СЛОВАРЯ ---
  /// Получает слова для категории вместе со статусом изучения для текущего пользователя.
  Future<List<Map<String, dynamic>>> getWordsWithStatusForCategory(String categoryId) async {
    if (_uid == null) return [];

    // 1. Получаем все слова для выбранной категории
    List<WordModel> wordsInCategory = await getAllWordsInCategory(categoryId);

    // 2. Получаем все статусы слов для пользователя
    final userWordsSnapshot = await _db.collection('users').doc(_uid).collection('userWords').get();
    final userStatuses = { for (var doc in userWordsSnapshot.docs) doc.id : doc.data()['status'] };

    // 3. Соединяем слова с их статусами
    List<Map<String, dynamic>> result = [];
    for (var word in wordsInCategory) {
      result.add({
        'word': word,
        'status': userStatuses[word.id] ?? 'new' // Статус: 'изучаю', 'изучено' или 'new'
      });
    }
    return result;
  }
  
  Future<List<WordModel>> getAllWordsInCategory(String categoryId) async {
    if (categoryId == 'user_words') {
      if (_uid == null) return [];
      final snapshot = await _db.collection('users').doc(_uid).collection('customWords').get();
      return snapshot.docs.map((doc) => WordModel.fromCustom(doc.data(), doc.id)).toList();
    }
    final categoryRef = _db.collection('category').doc(categoryId);
    final snapshot = await _db.collection('words').where('category', isEqualTo: categoryRef).get();
    return snapshot.docs.map((doc) => WordModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  // --- МЕТОДЫ ДЛЯ ИЗУЧЕНИЯ И ПОВТОРЕНИЯ ---

  Future<WordModel?> getWordToStudy(String categoryId) async {
    if (_uid == null) return null;
    final allWordsInCategory = await getAllWordsInCategory(categoryId);
    if (allWordsInCategory.isEmpty) return null;
    final userWordsSnapshot = await _db.collection('users').doc(_uid).collection('userWords').get();
    final userWords = userWordsSnapshot.docs.map((doc) => UserWordModel.fromFirestore(doc.data(), doc.id)).toList();
    List<WordModel> newWords = [];
    List<WordModel> studyingWords = [];
    for (var word in allWordsInCategory) {
      final userWord = userWords.where((uw) => uw.wordId == word.id);
      if (userWord.isEmpty) {
        newWords.add(word);
      } else if (userWord.first.status == 'изучаю') {
        studyingWords.add(word);
      }
    }
    final random = Random();
    List<WordModel> wordsPool = [];
    if (newWords.isNotEmpty && (studyingWords.isEmpty || random.nextDouble() < 0.7)) {
      wordsPool.addAll(newWords);
    } else if (studyingWords.isNotEmpty) {
      wordsPool.addAll(studyingWords);
    }
    if (wordsPool.isEmpty) return null;
    return wordsPool[random.nextInt(wordsPool.length)];
  }

  Future<List<WordModel>> getWordsToRepeat(String categoryId) async {
    if (_uid == null) return [];
    if (categoryId == 'user_words') {
        return getAllWordsInCategory(categoryId);
    }
    final userWordsSnapshot = await _db.collection('users').doc(_uid).collection('userWords').where('status', isEqualTo: 'изучаю').get();
    if (userWordsSnapshot.docs.isEmpty) return [];
    final studyingWordIds = userWordsSnapshot.docs.map((doc) => doc.id).toList();
    if (studyingWordIds.isEmpty) return [];
    final categoryRef = _db.collection('category').doc(categoryId);
    final wordsSnapshot = await _db.collection('words').where(FieldPath.documentId, whereIn: studyingWordIds).where('category', isEqualTo: categoryRef).get();
    return wordsSnapshot.docs.map((doc) => WordModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<void> updateUserWordStatus(String wordId, String status) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('userWords').doc(wordId).set({
      'status': status,
      'lastReviewed': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  // --- МЕТОДЫ ДЛЯ ЛИЧНОГО СЛОВАРЯ ---

  Stream<QuerySnapshot> getUserCustomWordsStream() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).collection('customWords').orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addUserCustomWord(String word, String translation) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('customWords').add({
      'word': word,
      'translation': translation,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserCustomWord(String docId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('customWords').doc(docId).delete();
  }
}