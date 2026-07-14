import 'package:flutter/material.dart';
import 'quiz_repository.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _repo = QuizRepository();
  Map<String, dynamic> _st = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await _repo.status();
    if (mounted) {
      setState(() {
        _st = st;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final q = _st['q'] as Map<String, String>;
    final mine = _st['myChoice'];
    final both = _st['both'] == true;
    final match = _st['match'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('默契测试')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('悄悄选，选完看默契 💞',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Text(q['q']!,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (mine == null) ...[
              ElevatedButton(
                onPressed: () async {
                  await _repo.choose('a');
                  _load();
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
                child: Text(q['a']!),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await _repo.choose('b');
                  _load();
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
                child: Text(q['b']!),
              ),
            ] else ...[
              if (!both)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('已选，等 Ta 也选完…'),
                  ),
                ),
              if (both)
                Card(
                  color: const Color(0xFFFCEAF0),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          match ? '💞 默契满分！选了一样' : '😄 不一样也很有趣',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE96A8B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('你选了：${mine == 'a' ? q['a'] : q['b']}'),
                        Text(
                            'Ta 选了：${(_st['partnerChoice'] == 'a' ? q['a'] : q['b'])}'),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
