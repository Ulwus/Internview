import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../data/expert_remote_data_source.dart';

final expertRemoteProvider = Provider<ExpertRemoteDataSource>(
  (ref) => ExpertRemoteDataSource(ref.watch(dioProvider)),
);

class ExpertListScreen extends ConsumerStatefulWidget {
  const ExpertListScreen({super.key});

  @override
  ConsumerState<ExpertListScreen> createState() => _ExpertListScreenState();
}

class _ExpertListScreenState extends ConsumerState<ExpertListScreen> {
  final _search = TextEditingController();
  int _page = 0;
  final List<ExpertSummary> _items = [];
  bool _loading = false;
  bool _hasNext = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 0;
      _items.clear();
      _hasNext = true;
    }
    if (!_hasNext) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(expertRemoteProvider).searchExperts(
            search: _search.text.trim().isEmpty ? null : _search.text.trim(),
            page: _page,
          );
      setState(() {
        _items.addAll(res.items);
        _hasNext = res.hasNext;
        if (res.hasNext) _page++;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = (e is DioException)
          ? (e.response?.data is Map
              ? ((e.response?.data as Map)['error']?['message']?.toString() ?? e.message ?? 'İstek başarısız')
              : (e.message ?? 'İstek başarısız'))
          : 'İstek başarısız';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Uzmanlar')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Ara…',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _load(refresh: true),
                    ),
                  ),
                  AnimatedActionButton(
                    onTap: () => _load(refresh: true),
                    width: 46,
                    height: 46,
                    color: Colors.white,
                    pressedColor: Colors.white,
                    borderColor: Colors.black,
                    borderWidth: 3,
                    borderRadius: 14,
                    shadowOffset: const Offset(4, 4),
                    child: const Icon(Icons.refresh, color: Colors.black),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                    _load();
                  }
                  return false;
                },
                child: ListView.builder(
                  itemCount: (_items.isEmpty && _loading) ? 8 : _items.length + (_loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_items.isEmpty && _loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            SkeletonContainer(width: 44, height: 44, borderRadius: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonContainer(width: double.infinity, height: 14, borderRadius: 8),
                                  SizedBox(height: 8),
                                  SkeletonContainer(width: 180, height: 12, borderRadius: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SkeletonContainer(width: 140, height: 14, borderRadius: 8)),
                      );
                    }
                    final e = _items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (e.avatarUrl != null && e.avatarUrl!.isNotEmpty) ? NetworkImage(e.avatarUrl!) : null,
                        child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
                            ? Text(e.firstName.isNotEmpty ? e.firstName[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text('${e.firstName} ${e.lastName}'),
                      subtitle: Text(e.headline ?? ''),
                      trailing: Text(e.hourlyRate != null ? '${e.hourlyRate} ${e.currency ?? ''}' : ''),
                      onTap: () => context.push('/expert/${e.id}'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
