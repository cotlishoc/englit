import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';
import 'dart:math';

// Тип упражнения в викторине
enum ExerciseType { none, multipleChoice, writeTranslation }

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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Слов для повторения: ${words.length}', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
          const SizedBox(height: 20),
          const Text('Выберите тип упражнения', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _startQuiz(ExerciseType.multipleChoice, words),
            child: const Text('Выбор из вариантов'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _startQuiz(ExerciseType.writeTranslation, words),
            child: const Text('Написать перевод'),
          ),
        ],
      ),
    );
  }

  /// Основной виджет викторины.
  Widget _buildQuizBody() {
    if (_currentQuestion == null) {
      // Экран завершения викторины.
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Сессия завершена!', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: (){
              Navigator.of(context).pop(); // Возвращаемся на главный экран
            }, child: const Text('Отлично')),
          ],
        )
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(_currentQuestion!.word, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          if (_exerciseType == ExerciseType.multipleChoice) ..._buildMultipleChoiceOptions(),
          if (_exerciseType == ExerciseType.writeTranslation) _buildWriteTranslation(),
        ],
      ),
    );
  }

  /// Виджеты для ответов (варианты или поле ввода).
  List<Widget> _buildMultipleChoiceOptions() {
    if (_showPostAnswerOptions) return _buildPostAnswerOptions();
    return _options.map((option) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(onPressed: () => _checkAnswer(option), child: Text(option)),
    )).toList();
  }

  Widget _buildWriteTranslation() {
    if (_showPostAnswerOptions) return Column(children: _buildPostAnswerOptions());
    return Column(
      children: [
        TextField(
          controller: _textController,
          decoration: const InputDecoration(labelText: 'Введите перевод'),
          textAlign: TextAlign.center,
          onSubmitted: (value) => _checkAnswer(value),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => _checkAnswer(_textController.text), child: const Text('Проверить'))
      ],
    );
  }

  /// Виджет, который показывается после правильного ответа.
  List<Widget> _buildPostAnswerOptions() {
    return [
      const Text('Правильно!', style: TextStyle(fontSize: 22, color: Colors.green)),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => _nextQuestion(),
        child: const Text('Продолжить'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => _nextQuestion(true),
        child: const Text('Я знаю это слово (убрать из повторений)'),
      ),
    ];
  }
}