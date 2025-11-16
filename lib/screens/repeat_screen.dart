import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';
import '../services/tts_service.dart';
import 'dart:math';

// Тип упражнения в викторине
enum ExerciseType { none, multipleChoice, writeTranslation, flashcards }

class RepeatScreen extends StatefulWidget {
  const RepeatScreen({super.key});

  @override
  State<RepeatScreen> createState() => _RepeatScreenState();
}

class _RepeatScreenState extends State<RepeatScreen> {
  // --- СЕРВИСЫ И ДАННЫЕ ---
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<WordModel>> _wordsToRepeatFuture;
  late Future<List<WordModel>> _allWordsFuture;
  
  // --- СОСТОЯНИЕ ВИКТОРИНЫ ---
  ExerciseType _exerciseType = ExerciseType.none;
  List<WordModel> _sessionWords = [];
  WordModel? _currentQuestion;
  List<String> _options = [];
  int _questionIndex = 0;
  bool _showPostAnswerOptions = false;
  final _textController = TextEditingController();
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    final categoryId = Provider.of<CategoryState>(context, listen: false).selectedCategoryId!;
    // Загружаем слова, которые пользователь сейчас учит
    _wordsToRepeatFuture = _firestoreService.getWordsToRepeat(categoryId);
    // Загружаем все слова категории для генерации неверных вариантов в тесте
    _allWordsFuture = _firestoreService.getAllWordsInCategory(categoryId);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // --- МЕТОДЫ ЛОГИКИ ВИКТОРИНЫ ---

  /// Запускает викторину после выбора типа упражнения, получив список слов.
  void _startQuiz(ExerciseType type, List<WordModel> words) {
    setState(() {
      _sessionWords = words;
      _exerciseType = type;
      _sessionWords.shuffle();
      _questionIndex = 0;
      _generateQuestion();
    });
  }

  /// Готовит следующий вопрос и варианты ответов.
  void _generateQuestion() {
    if (_questionIndex >= _sessionWords.length) {
      setState(() => _currentQuestion = null); // Викторина закончена
      return;
    }
    
    setState(() {
      _currentQuestion = _sessionWords[_questionIndex];
      _showPostAnswerOptions = false;
      _textController.clear();

      if (_exerciseType == ExerciseType.multipleChoice) {
        _allWordsFuture.then((allWords) {
          final random = Random();
          final tempOptions = <String>{_currentQuestion!.translation};
          final otherWords = allWords.where((w) => w.id != _currentQuestion!.id).toList();
          while (tempOptions.length < 4 && otherWords.isNotEmpty) {
            tempOptions.add(otherWords.removeAt(random.nextInt(otherWords.length)).translation);
          }
          setState(() => _options = tempOptions.toList()..shuffle());
        });
      }
    });
  }

  /// Проверяет ответ пользователя.
  void _checkAnswer(String answer) {
    if (_currentQuestion == null) return;
    final isCorrect = answer.trim().toLowerCase() == _currentQuestion!.translation.toLowerCase();
    
    // После правильного ответа показываем кнопки "Продолжить" / "Знаю слово"
    if (isCorrect) {
      setState(() => _showPostAnswerOptions = true);
    } else {
      // При неверном ответе показываем правильный и автоматически идем дальше
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Неверно! Правильный ответ: ${_currentQuestion!.translation}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Future.delayed(const Duration(seconds: 2), _nextQuestion);
    }
  }

  /// Переключает на следующий вопрос и обновляет статус слова в базе данных.
  void _nextQuestion([bool markAsLearned = false]) {
    if (_currentQuestion == null) return;
    
    // Определяем, какой статус установить слову
    final newStatus = markAsLearned ? 'learned' : 'learning';
    _firestoreService.updateUserWordStatus(_currentQuestion!.id, newStatus);
    
    setState(() => _questionIndex++);
    _generateQuestion();
  }

  // --- МЕТОДЫ-БИЛДЕРЫ ДЛЯ UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Повторение слов')),
      body: FutureBuilder<List<WordModel>>(
        future: _wordsToRepeatFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Произошла ошибка загрузки слов.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'У вас пока нет слов для повторения.\nНачните их учить на главном экране!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }
          
          // Если еще не в викторине, показываем выбор типа упражнения.
          if (_exerciseType == ExerciseType.none) {
            return _buildTypeSelection(snapshot.data!);
          } else {
            // Иначе показываем саму викторину.
            return _buildQuizBody();
          }
        },
      ),
    );
  }

  /// Виджет для выбора типа упражнения.
  Widget _buildTypeSelection(List<WordModel> words) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Слов для повторения: ${words.length}', style: TextStyle(fontSize: 18, color: theme.textTheme.bodyMedium?.color)),
            const SizedBox(height: 20),
            const Text('Выберите тип упражнения', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startQuiz(ExerciseType.multipleChoice, words),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
                child: const Text('Выбор из вариантов', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startQuiz(ExerciseType.writeTranslation, words),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text('Написать перевод', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startQuiz(ExerciseType.flashcards, words),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text('Пролистывание карточек', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Основной виджет викторины.
  Widget _buildQuizBody() {
    if (_currentQuestion == null) {
      // Экран завершения викторины.
      return SizedBox.expand(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Сессия завершена!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: (){
                    Navigator.of(context).pop(); // Возвращаемся на главный экран
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Отлично', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- Новый режим: пролистывание карточек ---
    if (_exerciseType == ExerciseType.flashcards) {
      return SizedBox.expand(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.04, // 4% от ширины экрана
            vertical: 24.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.of(context).size.height * 0.04, // 4% от высоты экрана
                    horizontal: MediaQuery.of(context).size.width * 0.04,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _currentQuestion!.word,
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.volume_up, color: Theme.of(context).colorScheme.primary),
                            iconSize: 30,
                            onPressed: () => _ttsService.speak(_currentQuestion!.word),
                          ),
                        ],
                      ),
                      if (_currentQuestion!.transcription.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_currentQuestion!.transcription, style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))),
                        ),
                      const SizedBox(height: 16),
                      Text(_currentQuestion!.translation, style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _nextQuestion(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Дальше'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _nextQuestion(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Я знаю'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Основной полноэкранный вид викторины: вопрос сверху по центру, варианты — полноширинные кнопки
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Вопрос
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _currentQuestion!.word,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_exerciseType == ExerciseType.multipleChoice) ..._buildMultipleChoiceOptions(),
                    if (_exerciseType == ExerciseType.writeTranslation) _buildWriteTranslation(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Виджеты для ответов (варианты или поле ввода).
  List<Widget> _buildMultipleChoiceOptions() {
    if (_showPostAnswerOptions) return _buildPostAnswerOptions();
    return _options.map((option) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _checkAnswer(option),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
            foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: Text(option, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
      ),
    )).toList();
  }

  Widget _buildWriteTranslation() {
    if (_showPostAnswerOptions) return Column(children: _buildPostAnswerOptions());
    // В режиме ввода (проверка)
    return Column(
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Введите перевод',
            filled: true,
            // Используем theme
            fillColor: null,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
          onSubmitted: (value) => _checkAnswer(value),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _checkAnswer(_textController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white, // явный цвет, чтобы был виден в темной теме
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Проверить', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  /// Виджет, который показыется после правильного ответа.
  List<Widget> _buildPostAnswerOptions() {
    return [
      const Text('Правильно!', style: TextStyle(fontSize: 26, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _nextQuestion(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Продолжить', style: TextStyle(fontSize: 18)),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => _nextQuestion(true),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Я знаю это слово (убрать из повторений)', style: TextStyle(fontSize: 16)),
      ),
    ];
  }
}