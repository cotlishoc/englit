import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Stream<DocumentSnapshot> getUserStream() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).snapshots();
  }

  Stream<QuerySnapshot> getCategoriesStream() {
    return _db.collection('category').orderBy('name').snapshots();
  }

  Future<List<Map<String, dynamic>>> getWordsWithStatusForCategory(String categoryId) async {
    if (_uid == null) return [];
    List<WordModel> wordsInCategory = await getAllWordsInCategory(categoryId);
    final userWordsSnapshot = await _db.collection('users').doc(_uid).collection('userWords').get();
    final userStatuses = { for (var doc in userWordsSnapshot.docs) doc.id : doc.data()['status'] };
    List<Map<String, dynamic>> result = [];
    for (var word in wordsInCategory) {
      result.add({
        'word': word,
        'status': userStatuses[word.id] ?? 'new'
      });
    }
    return result;
  }

  Future<List<WordModel>> getAllWordsInCategory(String categoryId) async {
    QuerySnapshot snapshot;
    if (categoryId == 'user_words') {
      if (_uid == null) return [];
      snapshot = await _db.collection('users').doc(_uid).collection('customWords').get();
      return snapshot.docs.map((doc) => WordModel.fromCustom(doc.data() as Map<String, dynamic>, doc.id)).toList();
    } 
    else if (categoryId == 'all_words') {
      snapshot = await _db.collection('words').get();
    } 
    else {
      final categoryRef = _db.collection('category').doc(categoryId);
      snapshot = await _db.collection('words').where('category', isEqualTo: categoryRef).get();
    }
    return snapshot.docs.map((doc) => WordModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<WordModel?> getNewWordToStudy(String categoryId) async {
    if (_uid == null) return null;
    final allWords = await getAllWordsInCategory(categoryId);
    if (allWords.isEmpty) return null;
    final userWordsSnapshot = await _db.collection('users').doc(_uid).collection('userWords').get();
    final studiedWordIds = userWordsSnapshot.docs.map((doc) => doc.id).toSet();
    for (final word in allWords) {
      if (!studiedWordIds.contains(word.id)) {
        return word;
      }
    }
    return null;
  }

  Future<List<WordModel>> getWordsToRepeat(String categoryId) async {
    if (_uid == null) return [];
    final userWordsSnapshot = await _db.collection('users')
      .doc(_uid)
      .collection('userWords')
      .where('status', isEqualTo: 'learning')
      .get();
    if (userWordsSnapshot.docs.isEmpty) return [];
    final studyingWordIds = userWordsSnapshot.docs.map((doc) => doc.id).toList();
    if (studyingWordIds.isEmpty) return [];
    Query wordsQuery = _db.collection('words').where(FieldPath.documentId, whereIn: studyingWordIds);
    if (categoryId != 'all_words' && categoryId != 'user_words') {
      final categoryRef = _db.collection('category').doc(categoryId);
      wordsQuery = wordsQuery.where('category', isEqualTo: categoryRef);
    }
    final wordsSnapshot = await wordsQuery.get();
    // ИСПРАВЛЕНИЕ ЗДЕСЬ
    return wordsSnapshot.docs.map((doc) => WordModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  // Добавлен метод для получения ежедневной статистики по датам в диапазоне [from, to]
  Future<Map<String, Map<String, int>>> getDailyStats(DateTime from, DateTime to) async {
    if (_uid == null) return {};
    final snapshot = await _db.collection('users').doc(_uid).collection('userWords').get();
    final Map<String, Map<String, int>> daily = {};

    DateTime start = DateTime(from.year, from.month, from.day);
    DateTime end = DateTime(to.year, to.month, to.day, 23, 59, 59);

    String formatDate(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Учёт начала изучения
      if (data['startedAt'] != null) {
        final ts = data['startedAt'] as Timestamp;
        final dt = ts.toDate();
        if (!dt.isBefore(start) && !dt.isAfter(end)) {
          final key = formatDate(dt);
          daily.putIfAbsent(key, () => {'learned': 0, 'learning': 0});
          daily[key]!['learning'] = (daily[key]!['learning'] ?? 0) + 1;
        }
      }

      // Учёт изменения статуса (последнее изменение)
      if (data['lastReviewed'] != null) {
        final ts = data['lastReviewed'] as Timestamp;
        final dt = ts.toDate();
        if (!dt.isBefore(start) && !dt.isAfter(end)) {
          final key = formatDate(dt);
          daily.putIfAbsent(key, () => {'learned': 0, 'learning': 0});
          final status = data['status'] ?? 'learning';
          if (status == 'learned') {
            daily[key]!['learned'] = (daily[key]!['learned'] ?? 0) + 1;
          } else {
            daily[key]!['learning'] = (daily[key]!['learning'] ?? 0) + 1;
          }
        }
      }
    }

    // Не добавляем дни без изменений — возвращаем только дни, в которых были события

    // Сортируем по ключу (дате) перед возвратом
    final sortedEntries = daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(sortedEntries);
  }

  Future<void> startLearningWord(String wordId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('userWords').doc(wordId).set({
      'status': 'learning',
      'startedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  Future<void> updateUserWordStatus(String wordId, String newStatus) async {
    if (_uid == null) return;
    final userWordRef = _db.collection('users').doc(_uid).collection('userWords').doc(wordId);
    if (newStatus == 'learned') {
      await _db.collection('users').doc(_uid).update({
        'stats.totalLearnedWords': FieldValue.increment(1)
      });
    }
    await userWordRef.set({
      'status': newStatus,
      'lastReviewed': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'settings': settings
    }, SetOptions(merge: true));
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