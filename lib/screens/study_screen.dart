import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart'; // <--- Импорт
import '../models/word_model.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayer _audioPlayer = AudioPlayer(); // <--- Создаем плеер
  Future<WordModel?>? _wordFuture;
  Key _cardKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Загружаем первое слово
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNextWord();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // <--- Очищаем ресурсы плеера
    super.dispose();
  }

  void _loadNextWord() {
    final categoryId = Provider.of<CategoryState>(context, listen: false).selectedCategoryId;
    if (categoryId != null) {
      setState(() {
        _wordFuture = _firestoreService.getWordToStudy(categoryId);
        _cardKey = UniqueKey();
      });
    }
  }

  void _updateWordStatusAndLoadNext(String wordId, String status) {
    if (wordId.isNotEmpty) {
       _firestoreService.updateUserWordStatus(wordId, status);
    }
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Text('Слова в этой категории закончились!');
            }

            final word = snapshot.data!;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Card(
                key: _cardKey,
                elevation: 4,
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(word.word, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                          // --- ИЗМЕНЕНИЕ: Кнопка для аудио ---
                          if (word.audioUrl.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              onPressed: () async {
                                try {
                                  await _audioPlayer.setUrl(word.audioUrl);
                                  _audioPlayer.play();
                                } catch (e) {
                                  print("Error playing audio: $e");
                                }
                              },
                            ),
                        ],
                      ),
                      if(word.transcription.isNotEmpty) Text(word.transcription, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 20),
                      Text(word.translation, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            onPressed: () => _updateWordStatusAndLoadNext(word.id, 'изучено'),
                            child: const Text('Знаю слово'),
                          ),
                          ElevatedButton(
                            onPressed: () => _updateWordStatusAndLoadNext(word.id, 'изучаю'),
                            child: const Text('Изучить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}