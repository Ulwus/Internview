import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/dio_client.dart';
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
    return Scaffold(
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
                IconButton(onPressed: () => _load(refresh: true), icon: const Icon(Icons.refresh)),
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
                itemCount: _items.length + (_loading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
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
    );
  }
}
