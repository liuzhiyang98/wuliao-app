import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import 'daily_repository.dart';
import 'milestone_repository.dart';

/// 「我们」中心页：聚合展示在一起天数、纪念日、早晚安、心情、每日一问，
/// 并作为各情感功能的入口。
class UsHubScreen extends StatefulWidget {
  const UsHubScreen({super.key});

  @override
  State<UsHubScreen> createState() => _UsHubScreenState();
}

class _UsHubScreenState extends State<UsHubScreen> {
  final _ms = MilestoneRepository();
  final _daily = DailyRepository();

  int _days = 0;
  bool _hasTogether = false;
  Map<String, dynamic>? _nextMilestone;
  bool _morningBoth = false;
  bool _eveningBoth = false;
  String? _partnerMood;
  bool _dailyBoth = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = await currentCoupleId();
    if (cid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ts = await _ms.togetherSince();
    final items = await _ms.list();
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    Map<String, dynamic>? next;
    for (final m in items) {
      final md = DateTime.parse(m['m_date']);
      if (!md.isBefore(today)) {
        next = m;
        break;
      }
    }

    final me = supabase.auth.currentUser!.id;
    final t = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final g = await supabase
        .from('greetings')
        .select()
        .eq('couple_id', cid)
        .eq('g_date', t);
    bool mMe = false, mP = false, eMe = false, eP = false;
    for (final r in g) {
      final isMe = r['user_id'] == me;
      if (r['kind'] == 'morning') {
        if (isMe) {
          mMe = true;
        } else {
          mP = true;
        }
      } else {
        if (isMe) {
          eMe = true;
        } else {
          eP = true;
        }
      }
    }
    final mRows = await supabase
        .from('moods')
        .select()
        .eq('couple_id', cid)
        .eq('m_date', t);
    String? pm;
    for (final r in mRows) {
      if (r['user_id'] != me) pm = r['mood'];
    }
    final dStatus = await _daily.status();

    if (mounted) {
      setState(() {
        _hasTogether = ts != null;
        _days = ts == null ? 0 : DateTime.now().difference(ts).inDays;
        _nextMilestone = next;
        _morningBoth = mMe && mP;
        _eveningBoth = eMe && eP;
        _partnerMood = pm;
        _dailyBoth = dStatus['both'] == true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFFCEAF0),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('$_days',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE96A8B),
                        )),
                    const Text('天 · 我们已经在一起',
                        style: TextStyle(color: Colors.black54)),
                    if (!_hasTogether)
                      TextButton(
                        onPressed: () =>
                            context.push('/milestones').then((_) => _load()),
                        child: const Text('设置在一起的日子 💞'),
                      ),
                  ],
                ),
              ),
            ),
            if (_nextMilestone != null) ...[
              const SizedBox(height: 12),
              _Row(
                icon: _nextMilestone!['emoji'] ?? '💖',
                title: '${_nextMilestone!['title']} 还有',
                sub:
                    '${DateTime.parse(_nextMilestone!['m_date']).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays} 天',
                onTap: () => context.push('/milestones').then((_) => _load()),
              ),
            ],
            const SizedBox(height: 12),
            _Row(
              icon: _morningBoth ? '☀️' : '🌙',
              title: '今天早晚安',
              sub: _morningBoth && _eveningBoth
                  ? '都已互道 💞'
                  : '点进去互道一声',
              onTap: () => context.push('/today').then((_) => _load()),
            ),
            _Row(
              icon: _partnerMood ?? '💗',
              title: '今天的心情',
              sub: _partnerMood == null ? '看看 Ta 今天怎样' : 'Ta 的心情',
              onTap: () => context.push('/today').then((_) => _load()),
            ),
            _Row(
              icon: '💬',
              title: '每日一问',
              sub: _dailyBoth ? '今天都答完啦' : '今天的问题等你们',
              onTap: () => context.push('/daily').then((_) => _load()),
            ),
            const SizedBox(height: 16),
            const Text('更多', style: TextStyle(color: Colors.black54)),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              children: [
                _Tile(
                  icon: '🎯',
                  label: '100 件小事',
                  onTap: () => context.push('/bucket').then((_) => _load()),
                ),
                _Tile(
                  icon: '🎵',
                  label: '共同歌单',
                  onTap: () => context.push('/media').then((_) => _load()),
                ),
                _Tile(
                  icon: '🎬',
                  label: '一起看片',
                  onTap: () => context.push('/media').then((_) => _load()),
                ),
                _Tile(
                  icon: '🧩',
                  label: '默契测试',
                  onTap: () => context.push('/quiz').then((_) => _load()),
                ),
                _Tile(
                  icon: '📸',
                  label: 'AR 合照',
                  onTap: () => context.push('/arphoto').then((_) => _load()),
                ),
                _Tile(
                  icon: '💖',
                  label: '纪念日',
                  onTap: () => context.push('/milestones').then((_) => _load()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Text(icon, style: const TextStyle(fontSize: 24)),
          title: Text(title),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _Tile extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      );
}
