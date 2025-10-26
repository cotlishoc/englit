import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';
import 'dart:math';

enum ExerciseType { none, multipleChoice, writeTranslation }

class RepeatScreen extends StatefulWidget {
  const RepeatScreen({super.key});

  @override
  State<RepeatScreen> createState() => _RepeatScreenState();
}

class _RepeatScreenState extends State<RepeatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<WordModel>> _wordsToRepeatFuture;
  late Future<List<WordModel>> _allWordsFuture;
  List<WordModel> _sessionWords = [];
  
  ExerciseType _exerciseType = ExerciseType.none;
  WordModel? _currentQuestion;
  List<String> _options = [];
  int _questionIndex = 0;
  bool _showPostAnswerOptions = false;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final categoryId = Provider.of<CategoryState>(context, listen: false).selectedCategoryId!;
    _wordsToRepeatFuture = _firestoreService.getWordsToRepeat(categoryId);
    _allWordsFuture = _firestoreService.getAllWordsInCategory(categoryId);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _startQuiz(ExerciseType type, List<WordModel> words) {
    setState(() {
      _exerciseType = type;
      _sessionWords = List.from(words)..shuffle(); // Копируем и перемешиваем слова для сессии
      _questionIndex = 0;
      _generateQuestion();
    });
  }

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

  void _checkAnswer(String answer) {
    if (answer.trim().toLowerCase() == _currentQuestion!.translation.toLowerCase()) {
      setState(() => _showPostAnswerOptions = true);
    } else {
      // Показываем Snackbar с ошибкой
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Неверно! Правильный ответ: ${_currentQuestion!.translation}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Через 2 секунды переходим к следующему слову, оставляя статус "изучаю"
      Future.delayed(const Duration(seconds: 2), _nextQuestion);
    }
  }

  void _nextQuestion([String? status]) {
    if(status != null) {
      _firestoreService.updateUserWordStatus(_currentQuestion!.id, status);
    }
    setState(() => _questionIndex++);
    _generateQuestion();
  }

  // --- ВИДЖЕТЫ ДЛЯ РАЗНЫХ ЧАСТЕЙ ЭКРАНА ---

  Widget _buildTypeSelection(List<WordModel> words) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

  Widget _buildQuizBody() {
    if (_currentQuestion == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Отлично!', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: (){
              setState(() => _exerciseType = ExerciseType.none);
            }, child: const Text('Закончить')),
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
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => _checkAnswer(_textController.text), child: const Text('Проверить'))
      ],
    );
  }

  List<Widget> _buildPostAnswerOptions() {
    return [
      const Text('Правильно!', style: TextStyle(fontSize: 22, color: Colors.green)),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => _nextQuestion('изучаю'),
        child: const Text('Продолжить учить'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => _nextQuestion('изучено'),
        child: const Text('Я знаю это слово'),
      ),
    ];
  }

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
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет слов для повторения.'));
          }
          
          if (_exerciseType == ExerciseType.none) {
            return _buildTypeSelection(snapshot.data!);
          } else {
            return _buildQuizBody();
          }
        },
      ),
    );
  }
}