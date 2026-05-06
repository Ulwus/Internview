import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/neo/neo_box.dart';
import '../../../core/presentation/widgets/neo/neo_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../booking/data/booking_remote_data_source.dart';

final _resultBookingProvider = FutureProvider.family.autoDispose<BookingDto, String>((ref, bookingId) {
  return ref.watch(bookingRemoteProvider).getBooking(bookingId);
});

class InterviewResultScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const InterviewResultScreen({super.key, required this.bookingId});

  @override
  ConsumerState<InterviewResultScreen> createState() => _InterviewResultScreenState();
}

class _InterviewResultScreenState extends ConsumerState<InterviewResultScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    final bookingAsync = ref.watch(_resultBookingProvider(widget.bookingId));

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Geçmiş Mülakat'),
        ),
        body: bookingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (b) {
            // init form once
            if (_comment.text.isEmpty && (b.expertComment?.isNotEmpty ?? false)) {
              _comment.text = b.expertComment!;
            }
            if (b.expertRating != null) _rating = b.expertRating!;

            final start = b.scheduledStart.toLocal();
            final end = b.scheduledEnd.toLocal();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                NeoBox(
                  color: const Color(0xFFFF9100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Randevu', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Başlangıç: $start'),
                      Text('Bitiş: $end'),
                      const SizedBox(height: 12),
                      Text('Durum: ${b.status.name.toUpperCase()}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NeoBox(
                  color: const Color(0xFF00E5FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Uzman Değerlendirmesi', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Puan: ', style: TextStyle(fontWeight: FontWeight.w900)),
                          DropdownButton<int>(
                            value: _rating.clamp(1, 5),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1')),
                              DropdownMenuItem(value: 2, child: Text('2')),
                              DropdownMenuItem(value: 3, child: Text('3')),
                              DropdownMenuItem(value: 4, child: Text('4')),
                              DropdownMenuItem(value: 5, child: Text('5')),
                            ],
                            onChanged: (!isExpert || b.status != BookingStatus.completed)
                                ? null
                                : (v) => setState(() => _rating = v ?? 5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _comment,
                        minLines: 3,
                        maxLines: 6,
                        enabled: isExpert && b.status == BookingStatus.completed,
                        decoration: const InputDecoration(
                          labelText: 'Yorum (opsiyonel)',
                          hintText: 'Güçlü yönler, geliştirme alanları...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isExpert)
                        NeoButton(
                          color: Colors.white,
                          onPressed: () async {
                            if (b.status != BookingStatus.completed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Değerlendirme için randevu COMPLETED olmalı')),
                              );
                              return;
                            }
                            if (_saving) return;
                            setState(() => _saving = true);
                            try {
                              await ref.read(bookingRemoteProvider).updateExpertFeedback(
                                    bookingId: b.id,
                                    expertRating: _rating.clamp(1, 5),
                                    expertComment: _comment.text.trim(),
                                  );
                              ref.invalidate(_resultBookingProvider(widget.bookingId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Değerlendirme kaydedildi')),
                                );
                              }
                            } on ApiException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Kaydet',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                          ),
                        )
                      else
                        Text(
                          (b.expertComment?.isNotEmpty ?? false) ? b.expertComment! : 'Henüz yorum yok.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                NeoBox(
                  color: const Color(0xFFB388FF),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('AI Yorumu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 8),
                      Text('Yakında: AI analizi daha sonra eklenecek.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                NeoButton(
                  color: const Color(0xFFFFD600),
                  onPressed: () => context.go('/home'),
                  child: const Center(
                    child: Text('Kapat', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
