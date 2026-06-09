import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
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
    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Uzman')),
        body: expert.when(
          loading: () => const Center(child: SkeletonContainer(width: 220, height: 14, borderRadius: 8)),
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
                const SizedBox(height: 8),
                slots.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SkeletonContainer(width: double.infinity, height: 14, borderRadius: 8),
                  ),
                  error: (e, _) => Text('$e'),
                  data: (list) {
                    final open = list.where((s) => !s.booked).toList();
                    if (open.isEmpty) {
                      return const Text('Uygun slot yok.');
                    }
                    return Column(
                      children: open
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('${s.startTime.toLocal()} — ${s.endTime.toLocal()}'),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedActionButton(
                                    onTap: () async {
                                      try {
                                        final b = await ref.read(bookingRemoteProvider).createBooking(
                                              expertId: d.userId,
                                              slotId: s.id,
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Talep gönderildi (uzman onayı bekleniyor)')),
                                          );
                                          context.push('/booking/${b.id}');
                                        }
                                      } on ApiException catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                                        }
                                      }
                                    },
                                    width: 140,
                                    height: 44,
                                    color: const Color(0xFFFF9100),
                                    pressedColor: const Color(0xFFFF9100),
                                    borderColor: Colors.black,
                                    borderWidth: 3,
                                    borderRadius: 14,
                                    shadowOffset: const Offset(4, 4),
                                    child: const Center(
                                      child: Text(
                                        'Rezerve et',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ],
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
      ),
    );
  }
}
