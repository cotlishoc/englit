import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../state/category_state.dart';
import 'add_word_screen.dart';
import 'categories_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';
import 'repeat_screen.dart';
import 'study_screen.dart';

// --- Современная карточка (вспомогательный виджет) ---
class _ModernCard extends StatelessWidget {
  final Widget child;
  final double? height;
  const _ModernCard({required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3FFF5), Color(0xFFE8F8EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// --- Главный экран ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _navigateToScreen(BuildContext context, Widget screen) {
    final categoryState = Provider.of<CategoryState>(context, listen: false);
    if (categoryState.selectedCategoryId == null && screen is! AddWordScreen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, сначала выберите категорию.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFB9F6CA),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF388E3C).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.person_outline, size: 28, color: Color(0xFF388E3C)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: firestoreService.getUserStream(),
          builder: (context, snapshot) {
            int totalLearned = 0;
            int repetitions = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              totalLearned = data['stats']?['totalLearnedWords'] ?? 0;
              repetitions = data['stats']?['repetitionsCount'] ?? 0;
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: <Widget>[
                _buildCategorySelector(context),
                const SizedBox(height: 16.0),
                _buildLargeCard(
                  context,
                  title: 'Изучить новые слова',
                  onTap: () => _navigateToScreen(context, const StudyScreen()),
                ),
                const SizedBox(height: 16.0),
                Row(
                  children: <Widget>[
                    _buildSmallButton(
                      context,
                      text: 'повторение слов',
                      onTap: () => _navigateToScreen(context, const RepeatScreen()),
                    ),
                    const SizedBox(width: 16.0),
                    _buildSmallButton(
                      context,
                      text: 'словарь',
                      onTap: () => _navigateToScreen(context, const DictionaryScreen()),
                    ),
                    const SizedBox(width: 16.0),
                    _buildSmallButton(
                      context,
                      text: 'добавить свое слово',
                      onTap: () {
                         Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddWordScreen()),
                          );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                _buildLargeCard(
                  context,
                  title: 'Статистика',
                  height: 250,
                  content: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : _buildStatsContent(totalLearned, repetitions),
                  onTap: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsContent(int learnedCount, int repetitionCount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatRow(Icons.check_circle_outline, 'Всего изучено слов', '$learnedCount'),
        _buildStatRow(Icons.repeat, 'Всего повторений', '$repetitionCount'),
        const Expanded(
          child: Center(
            child: Text("График прогресса в разработке", style: TextStyle(color: Colors.grey))
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildCategorySelector(BuildContext context) {
    return Consumer<CategoryState>(
      builder: (context, categoryState, child) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoriesScreen()),
            );
          },
          child: _ModernCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Категория: ${categoryState.selectedCategoryName}',
                    style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB9F6CA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLargeCard(BuildContext context, {required String title, VoidCallback? onTap, double height = 150, Widget? content}) {
    return GestureDetector(
      onTap: onTap,
      child: _ModernCard(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            if (content != null) Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton(BuildContext context, {required String text, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: _ModernCard(
          height: 80,
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}