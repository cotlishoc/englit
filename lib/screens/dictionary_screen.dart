import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../services/tts_service.dart';
import '../state/category_state.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  // --- СЕРВИСЫ ---
  final FirestoreService _firestoreService = FirestoreService();
  final TtsService _ttsService = TtsService();

  // --- СОСТОЯНИЕ ЭКРАНА ---
  late Future<List<Map<String, dynamic>>> _wordsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWords();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Загружает слова с их статусами для выбранной категории.
  void _loadWords() {
    final categoryId = Provider.of<CategoryState>(context, listen: false).selectedCategoryId;
    if (categoryId != null) {
      setState(() {
        _wordsFuture = _firestoreService.getWordsWithStatusForCategory(categoryId);
      });
    }
  }

  /// Возвращает слово в список для повторений.
  void _resetToLearning(String wordId) {
    _firestoreService.updateUserWordStatus(wordId, 'learning').then((_) {
      _loadWords();
    });
  }

  /// Помечает слово как полностью изученное.
  void _markAsLearned(String wordId) {
    _firestoreService.updateUserWordStatus(wordId, 'learned').then((_) {
      _loadWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = context.watch<CategoryState>();
    final isCustomCategorySelected = categoryState.selectedCategoryId == 'user_words';

    return Scaffold(
      appBar: AppBar(title: Text('Словарь: ${categoryState.selectedCategoryName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск по слову или переводу',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _wordsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Произошла ошибка загрузки слов.'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Нет слов в этой категории.'));
                }

                var wordsWithStatus = snapshot.data!;

                if (_searchQuery.isNotEmpty) {
                  wordsWithStatus = wordsWithStatus.where((item) {
                    final word = item['word'] as WordModel;
                    return word.word.toLowerCase().contains(_searchQuery) ||
                           word.translation.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (wordsWithStatus.isEmpty) {
                  return const Center(child: Text('Ничего не найдено.'));
                }

                return ListView.builder(
                  itemCount: wordsWithStatus.length,
                  itemBuilder: (context, index) {
                    final item = wordsWithStatus[index];
                    final WordModel word = item['word'];
                    final String status = item['status'];

                    // --- Кастомное слово: если выбрана категория "Мои слова" ---
                    final bool isCustomWord = isCustomCategorySelected;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(word.translation, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        leading: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _ttsService.speak(word.word),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.volume_up, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCustomWord) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (status == 'learned') {
                                        _resetToLearning(word.id);
                                      } else {
                                        _markAsLearned(word.id);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark ? (status == 'learned' ? const Color(0xFF2A2A2A) : const Color(0xFF222222)) : (status == 'learned' ? const Color(0xFFDFF3E0) : const Color(0xFFF0FFF4)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            status == 'learned' ? Icons.check_circle : Icons.school_outlined,
                                            color: status == 'learned' ? Theme.of(context).colorScheme.primary : Colors.grey,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            status == 'learned' ? 'Знаю' : 'Учить',
                                            style: TextStyle(
                                              color: status == 'learned' ? Theme.of(context).colorScheme.primary : Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    tooltip: 'Удалить слово',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext ctx) {
                                          return AlertDialog(
                                            title: const Text('Подтвердить удаление'),
                                            content: Text('Вы уверены, что хотите удалить слово "${word.word}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: const Text('Отмена'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  _firestoreService.deleteUserCustomWord(word.id).then((_) {
                                                    _loadWords();
                                                  });
                                                  Navigator.of(ctx).pop();
                                                },
                                                child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ] else ...[
                              GestureDetector(
                                onTap: () {
                                  if (status == 'learned') {
                                    _resetToLearning(word.id);
                                  } else {
                                    _markAsLearned(word.id);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark ? (status == 'learned' ? const Color(0xFF2A2A2A) : const Color(0xFF222222)) : (status == 'learned' ? const Color(0xFFDFF3E0) : const Color(0xFFF0FFF4)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        status == 'learned' ? Icons.check_circle : Icons.school_outlined,
                                        color: status == 'learned' ? Theme.of(context).colorScheme.primary : Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        status == 'learned' ? 'Знаю' : 'Учить',
                                        style: TextStyle(
                                          color: status == 'learned' ? Theme.of(context).colorScheme.primary : Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}