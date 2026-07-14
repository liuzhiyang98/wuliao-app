import 'package:flutter/material.dart';
import 'daily_repository.dart';

class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  final _repo = DailyRepository();
  Map<String, dynamic> _st = {};
  final _ctl = TextEditingController();
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

  Future<void> _submit() async {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    await _repo.answer(t);
    _ctl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final question = _st['question'] ?? '';
    final mine = _st['mine'];
    final partner = _st['partner'];
    final both = _st['both'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('每日一问')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今天的提问', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(question,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (mine == null) ...[
              TextField(
                controller: _ctl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '写下你的回答',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _submit, child: const Text('提交')),
            ] else ...[
              const Text('你的回答', style: TextStyle(color: Colors.black54)),
              Text(mine, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              if (!both)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('等待 Ta 的回答… 💌'),
                  ),
                )
              else ...[
                const Text('Ta 的回答', style: TextStyle(color: Colors.black54)),
                Text(partner ?? '', style: const TextStyle(fontSize: 16)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
