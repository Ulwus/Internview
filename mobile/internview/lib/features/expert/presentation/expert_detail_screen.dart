import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../booking/data/booking_remote_data_source.dart';
import 'expert_list_screen.dart';

final expertDetailProvider = FutureProvider.family.autoDispose<ExpertDetail, String>((ref, id) {
  return ref.watch(expertRemoteProvider).getExpert(id);
});

final openSlotsProvider = FutureProvider.family.autoDispose<List<SlotDto>, String>((ref, expertUserId) {
  return ref.watch(bookingRemoteProvider).listOpenSlots(expertUserId);
});

class ExpertDetailScreen extends ConsumerWidget {
  const ExpertDetailScreen({super.key, required this.expertId});

  final String expertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expert = ref.watch(expertDetailProvider(expertId));
    return Scaffold(
      appBar: AppBar(title: const Text('Uzman')),
      body: expert.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final slots = ref.watch(openSlotsProvider(d.userId));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text('${d.firstName} ${d.lastName}', style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text(d.headline ?? ''),
              ),
              if (d.bio != null && d.bio!.isNotEmpty) Text(d.bio!),
              Text('Saatlik: ${d.hourlyRate ?? '-'} ${d.currency ?? ''}'),
              Text('Puan: ${d.averageRating ?? '-'}'),
              const SizedBox(height: 16),
              const Text('Açık zaman dilimleri', style: TextStyle(fontWeight: FontWeight.bold)),
              slots.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  final open = list.where((s) => !s.booked).toList();
                  if (open.isEmpty) {
                    return const Text('Uygun slot yok.');
                  }
                  return Column(
                    children: open
                        .map(
                          (s) => ListTile(
                            title: Text('${s.startTime.toLocal()} — ${s.endTime.toLocal()}'),
                            trailing: FilledButton(
                              child: const Text('Rezerve et'),
                              onPressed: () async {
                                try {
                                  final b = await ref.read(bookingRemoteProvider).createBooking(
                                        expertId: d.userId,
                                        slotId: s.id,
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Rezervasyon oluşturuldu')),
                                    );
                                    context.push('/booking/${b.id}');
                                  }
                                } on ApiException catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                                  }
                                }
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
