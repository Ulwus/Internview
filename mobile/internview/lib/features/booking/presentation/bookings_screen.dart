import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../data/booking_remote_data_source.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, required this.asExpert});

  final bool asExpert;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  final List<BookingDto> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _hasNext = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      final res = widget.asExpert
          ? await ref.read(bookingRemoteProvider).listExpertBookings(page: _page)
          : await ref.read(bookingRemoteProvider).listCandidateBookings(page: _page);
      setState(() {
        _items.addAll(res.items);
        _hasNext = res.hasNext;
        if (res.hasNext) _page++;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Randevular')),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _load();
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
              final b = _items[i];
              return ListTile(
                title: Text(b.status.name),
                subtitle: Text('${b.scheduledStart.toLocal()}'),
                onTap: () => context.push('/booking/${b.id}'),
              );
            },
          ),
        ),
      ),
    );
  }
}
