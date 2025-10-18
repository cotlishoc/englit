import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENGLIT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784), // светло-зелёный
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FFF8), // очень светлый зелёный
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE8F5E9),
          surfaceTintColor: Color(0xFFE8F5E9),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF388E3C)),
          titleTextStyle: TextStyle(
            color: Color(0xFF388E3C),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF388E3C)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// Заглушки для экранов, на которые будут переходить кнопки
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор категорий')),
      body: const Center(
        child: _ModernCard(child: Text('Экран выбора категорий', style: TextStyle(fontSize: 18))),
      ),
    );
  }
}

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Изучить новые слова')),
      body: const Center(
        child: _ModernCard(child: Text('Экран изучения новых слов', style: TextStyle(fontSize: 18))),
      ),
    );
  }
}

class RepeatScreen extends StatelessWidget {
  const RepeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Повторение слов')),
      body: const Center(
        child: _ModernCard(child: Text('Экран повторения изученных слов', style: TextStyle(fontSize: 18))),
      ),
    );
  }
}

class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Словарь')),
      body: const Center(
        child: _ModernCard(child: Text('Экран словаря', style: TextStyle(fontSize: 18))),
      ),
    );
  }
}

class AddWordScreen extends StatelessWidget {
  const AddWordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить свое слово')),
      body: const Center(
        child: _ModernCard(child: Text('Экран добавления своего слова', style: TextStyle(fontSize: 18))),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Личный кабинет')),
      body: const Center(
        child: _ModernCard(child: Text('Экран личного кабинета', style: TextStyle(fontSize: 18))),
      ),
    );
  }
}

// --- Главный экран ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      color: Colors.green.withOpacity(0.15),
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            _buildCategorySelector(context),
            const SizedBox(height: 16.0),
            _buildLargeCard(
              context,
              title: 'Изучить новые слова',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudyScreen()),
                );
              },
            ),
            const SizedBox(height: 16.0),
            Row(
              children: <Widget>[
                _buildSmallButton(
                  context,
                  text: 'повторение слов',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RepeatScreen()),
                    );
                  },
                ),
                const SizedBox(width: 16.0),
                _buildSmallButton(
                  context,
                  text: 'словарь',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DictionaryScreen()),
                    );
                  },
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
              title: 'статистика',
              height: 250,
              content: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'График изучения слов по дням/неделям, общее количество изученных слов, количество повторений, прогресс по тематикам.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  SizedBox(height: 10),
                ],
              ),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
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
          children: const [
            Text(
              'выбор категории',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500),
            ),
            Icon(Icons.arrow_forward_ios, size: 20, color: Color(0xFF388E3C)),
          ],
        ),
      ),
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

// --- Современная карточка с мягкой тенью и скруглениями ---
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
} 