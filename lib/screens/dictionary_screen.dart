import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayer _audioPlayer = AudioPlayer();
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
    // Перезагружаем слова, если категория изменилась (хотя обычно на этот экран приходят с уже выбранной)
    _loadWords();
  }

  void _loadWords() {
    final categoryId = Provider.of<CategoryState>(context, listen: false).selectedCategoryId;
    if (categoryId != null) {
      setState(() {
        _wordsFuture = _firestoreService.getWordsWithStatusForCategory(categoryId);
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _playAudio(String url) async {
    if (url.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(url);
        _audioPlayer.play();
      } catch (e) {
        print("Error playing audio: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = context.watch<CategoryState>();
    final isCustomCategory = categoryState.selectedCategoryId == 'user_words';

    return Scaffold(
      appBar: AppBar(title: Text('Словарь: ${categoryState.selectedCategoryName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск',
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

                return ListView.builder(
                  itemCount: wordsWithStatus.length,
                  itemBuilder: (context, index) {
                    final item = wordsWithStatus[index];
                    final WordModel word = item['word'];
                    final String status = item['status'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(word.word),
                        subtitle: Text(word.translation),
                        // Кнопка аудио
                        leading: IconButton(
                          icon: Icon(Icons.volume_up, color: word.audioUrl.isNotEmpty ? Theme.of(context).primaryColor : Colors.grey),
                          onPressed: () => _playAudio(word.audioUrl),
                        ),
                        // Кнопка управления статусом
                        trailing: isCustomCategory
                          ? IconButton( // Для кастомных слов - кнопка удаления
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                _firestoreService.deleteUserCustomWord(word.id);
                                _loadWords(); // Обновляем список
                              },
                            )
                          : IconButton( // Для обычных слов - управление статусом
                              icon: status == 'изучено' 
                                ? const Icon(Icons.check_circle, color: Colors.green, semanticLabel: 'Знаю слово')
                                : const Icon(Icons.school_outlined, color: Colors.grey, semanticLabel: 'Начать учить'),
                              tooltip: status == 'изучено' ? 'Вернуть в изучение' : 'Отметить как "знаю"',
                              onPressed: () {
                                final newStatus = status == 'изучено' ? 'изучаю' : 'изучено';
                                _firestoreService.updateUserWordStatus(word.id, newStatus).then((_) {
                                  _loadWords(); // Перезагружаем слова, чтобы увидеть изменения
                                });
                              },
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