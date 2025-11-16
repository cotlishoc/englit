import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../services/tts_service.dart';
import '../state/category_state.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  // --- СЕРВИСЫ ---
  final FirestoreService _firestoreService = FirestoreService();
  final TtsService _ttsService = TtsService();
  
  // --- СОСТОЯНИЕ ЭКРАНА ---
  Future<WordModel?>? _wordFuture;
  // Ключ для корректной работы анимации смены карточек
  Key _cardKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Безопасно вызываем загрузку слова после того, как первый кадр будет отрисован
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNextWord();
    });
  }

  /// Загружает следующее НОВОЕ слово из выбранной категории.
  void _loadNextWord() {
    final categoryId = Provider.of<CategoryState>(context, listen: false).selectedCategoryId;
    if (categoryId != null) {
      setState(() {
        // Вызываем метод, который ищет именно неизученные слова
        _wordFuture = _firestoreService.getNewWordToStudy(categoryId);
        // Обновляем ключ, чтобы анимация сработала
        _cardKey = UniqueKey();
      });
    }
  }

  // --- ИЗМЕНЕНИЕ: Упрощенная логика ---
  
  /// Обрабатывает нажатие на кнопку "Начать учить".
  /// Слово добавляется в список для повторений со статусом 'learning'.
  void _startLearning(String wordId) {
    _firestoreService.startLearningWord(wordId);
    _loadNextWord();
  }
  
  /// Обрабатывает нажатие на кнопку "Знаю слово".
  /// Слово сразу помечается как выученное ('learned') и не попадает в повторения.
  void _markAsLearnedAndLoadNext(String wordId) {
    _firestoreService.updateUserWordStatus(wordId, 'learned');
    _loadNextWord();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Изучить новые слова')),
      body: Center(
        child: FutureBuilder<WordModel?>(
          future: _wordFuture,
          builder: (context, snapshot) {
            // 1. Пока идет загрузка, показываем индикатор
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            // 2. Если слов нет (или все уже изучены), показываем сообщение
            if (!snapshot.hasData || snapshot.data == null) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Новых слов в этой категории нет. Отличная работа!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            // 3. Если слово есть, показываем карточку
            final word = snapshot.data!;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Container(
                key: _cardKey,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7FFF8), Color(0xFFE8F8EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Английское слово и кнопка озвучки ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            word.word, 
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                            textAlign: TextAlign.center,
                          )
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF2E7D32)),
                          iconSize: 30,
                          onPressed: () => _ttsService.speak(word.word),
                        ),
                      ],
                    ),

                    // --- Транскрипция (если есть) ---
                    if (word.transcription.isNotEmpty)
                      Text(
                        word.transcription, 
                        style: const TextStyle(fontSize: 18, color: Colors.grey)
                      ),
                    
                    const SizedBox(height: 20),

                    // --- Перевод ---
                    Text(
                      word.translation, 
                      style: const TextStyle(fontSize: 28, color: Color(0xFF2E7D32)),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),

                    // --- Кнопки действий ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: () => _markAsLearnedAndLoadNext(word.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Знаю слово'),
                        ),
                        ElevatedButton(
                          onPressed: () => _startLearning(word.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Начать учить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
             );
           },
         ),
       ),
     );
   }
 }