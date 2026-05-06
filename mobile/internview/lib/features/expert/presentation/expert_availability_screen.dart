import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../booking/data/booking_remote_data_source.dart';

final mySlotsProvider = FutureProvider.autoDispose<List<SlotDto>>((ref) {
  return ref.watch(bookingRemoteProvider).listMySlots();
});

class ExpertAvailabilityScreen extends ConsumerWidget {
  const ExpertAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(mySlotsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müsaitlik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _pickSlot(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(mySlotsProvider),
          ),
        ],
      ),
      body: slots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Henüz slot yok. + ile ekleyin.'));
          }
          list.sort((a, b) => a.startTime.compareTo(b.startTime));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return ListTile(
                title: Text('${s.startTime.toLocal()} — ${s.endTime.toLocal()}'),
                subtitle: Text(s.booked ? 'Dolu' : 'Boş'),
                trailing: s.booked
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await ref.read(bookingRemoteProvider).deleteMySlot(s.id);
                            ref.invalidate(mySlotsProvider);
                          } on ApiException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          }
                        },
                      ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _pickSlot(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final startT = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (startT == null || !context.mounted) return;
    final endT = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (startT.hour + 1) % 24, minute: startT.minute),
    );
    if (endT == null || !context.mounted) return;
    final start = DateTime(date.year, date.month, date.day, startT.hour, startT.minute);
    var end = DateTime(date.year, date.month, date.day, endT.hour, endT.minute);
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    try {
      await ref.read(bookingRemoteProvider).createMySlot(start: start, end: end);
      ref.invalidate(mySlotsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot eklendi')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
