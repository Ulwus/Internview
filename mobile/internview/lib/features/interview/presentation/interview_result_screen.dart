import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/session_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/action_group.dart';
import '../../../core/presentation/widgets/penkrowd/radial_stat_gauge.dart';
import '../../../core/presentation/widgets/penkrowd/section_card.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../booking/data/booking_remote_data_source.dart';
import '../../booking/presentation/booking_ui_helpers.dart';
import '../data/session_remote_data_source.dart';

final _resultBookingProvider = FutureProvider.family
    .autoDispose<BookingDto, String>((ref, bookingId) {
      return ref.watch(bookingRemoteProvider).getBooking(bookingId);
    });

final _analysisReportProvider = FutureProvider.family
    .autoDispose<AnalysisReport, String>((ref, bookingId) async {
      final session = await ref
          .watch(sessionRemoteProvider)
          .getSessionByBooking(bookingId);
      return ref
          .watch(sessionRemoteProvider)
          .getAnalysisReport(session.sessionId);
    });

class InterviewResultScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const InterviewResultScreen({super.key, required this.bookingId});

  @override
  ConsumerState<InterviewResultScreen> createState() =>
      _InterviewResultScreenState();
}

class _InterviewResultScreenState extends ConsumerState<InterviewResultScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  int _candidateRating = 5;
  final _candidateComment = TextEditingController();
  bool _candidateSaving = false;
  bool _didSyncBooking = false;
  bool _completionSyncRequested = false;
  Timer? _bookingPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bookingPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        ref.invalidate(_resultBookingProvider(widget.bookingId));
      });
    });
  }

  @override
  void dispose() {
    _bookingPollTimer?.cancel();
    _comment.dispose();
    _candidateComment.dispose();
    super.dispose();
  }

  Future<void> _saveExpertFeedback(BookingDto booking) async {
    if (booking.status != BookingStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Değerlendirme için randevu COMPLETED olmalı'),
        ),
      );
      return;
    }
    if (_comment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen puanın nedenini yaz')),
      );
      return;
    }
    setState(() => _saving = true);
    final expertComment = _comment.text.trim();
    try {
      await ref
          .read(bookingRemoteProvider)
          .updateExpertFeedback(
            bookingId: booking.id,
            expertRating: _rating.clamp(1, 10),
            expertComment: expertComment,
          );
      ref.invalidate(_resultBookingProvider(widget.bookingId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değerlendirme kaydedildi')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _syncCompletedStatus() async {
    if (_completionSyncRequested) return;
    _completionSyncRequested = true;
    try {
      await ref.read(bookingRemoteProvider).completeBooking(widget.bookingId);
    } catch (_) {}
    if (mounted) {
      ref.invalidate(_resultBookingProvider(widget.bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    final bookingAsync = ref.watch(_resultBookingProvider(widget.bookingId));
    final reportAsync = ref.watch(_analysisReportProvider(widget.bookingId));

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Geçmiş Mülakat')),
        body: bookingAsync.when(
          loading: () => const Center(
            child: SkeletonContainer(width: 220, height: 14, borderRadius: 8),
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (b) {
            if (!_didSyncBooking) {
              _comment.text = b.expertComment ?? '';
              _rating = b.expertRating ?? 5;
              _candidateComment.text = b.candidateComment ?? '';
              _candidateRating = b.candidateRating ?? 5;
              _didSyncBooking = true;
            }

            final whenText = formatBookingWhen(b);
            final isCompleted = b.status == BookingStatus.completed;
            if (!isCompleted) {
              Future<void>.microtask(_syncCompletedStatus);
              Future<void>.delayed(const Duration(milliseconds: 600), () {
                if (mounted) {
                  ref.invalidate(_resultBookingProvider(widget.bookingId));
                }
              });
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  title: 'Randevu',
                  subtitle: 'Özet',
                  color: const Color(0xFFFFD600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        whenText,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Durum: ${bookingStatusMiniLabel(b)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isExpert)
                  SectionCard(
                    title: 'Adayı değerlendir',
                    subtitle: isCompleted
                        ? 'Adaya 10 üzerinden puan ver ve nedenini yaz'
                        : 'Oturum sonlanınca değerlendirme açılır',
                    color: const Color(0xFF00E5FF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RatingSelector(
                          label: 'Aday puanı',
                          value: _rating,
                          enabled: isCompleted && !_saving,
                          onChanged: (v) => setState(() => _rating = v),
                        ),
                        const SizedBox(height: 14),
                        _ReviewInput(
                          controller: _comment,
                          enabled: isCompleted && !_saving,
                          label: 'Adaya yorum',
                          hintText: 'Bu puanı neden verdiğini açıkla...',
                        ),
                        const SizedBox(height: 14),
                        ActionGroup(
                          primary: primaryAction(
                            label: _saving ? 'Kaydediliyor...' : 'Kaydet',
                            onTap: _saving
                                ? null
                                : () async => _saveExpertFeedback(b),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SectionCard(
                    title: 'Uzmanın değerlendirmesi',
                    subtitle: 'Bu alanı sadece uzman doldurur',
                    color: const Color(0xFF00E5FF),
                    child: _ReadOnlyReview(
                      rating: b.expertRating,
                      comment: b.expertComment,
                      emptyText: 'Uzman henüz seni değerlendirmedi.',
                    ),
                  ),
                if (!isExpert) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Uzmanı değerlendir',
                    subtitle: isCompleted
                        ? 'Uzmanı ve mağazasını 10 üzerinden değerlendir'
                        : 'Sadece COMPLETED randevuda değerlendirme yapılır',
                    color: const Color(0xFFFFD600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RatingSelector(
                          label: 'Uzman puanı',
                          value: _candidateRating,
                          enabled: isCompleted && !_candidateSaving,
                          onChanged: (v) =>
                              setState(() => _candidateRating = v),
                        ),
                        const SizedBox(height: 14),
                        _ReviewInput(
                          controller: _candidateComment,
                          enabled: isCompleted,
                          label: 'Uzman yorumu',
                          hintText: 'Bu puanı neden verdiğini açıkla...',
                        ),
                        const SizedBox(height: 14),
                        ActionGroup(
                          primary: primaryAction(
                            label: _candidateSaving
                                ? 'Kaydediliyor…'
                                : 'Kaydet',
                            onTap: _candidateSaving
                                ? null
                                : () async {
                                    if (b.status != BookingStatus.completed) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Değerlendirme için randevu COMPLETED olmalı',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (_candidateComment.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Lütfen puanın nedenini yaz',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => _candidateSaving = true);
                                    try {
                                      await ref
                                          .read(bookingRemoteProvider)
                                          .updateCandidateFeedback(
                                            bookingId: b.id,
                                            candidateRating: _candidateRating
                                                .clamp(1, 10),
                                            candidateComment: _candidateComment
                                                .text
                                                .trim(),
                                          );
                                      ref.invalidate(
                                        _resultBookingProvider(
                                          widget.bookingId,
                                        ),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Değerlendirme kaydedildi',
                                            ),
                                          ),
                                        );
                                      }
                                    } on ApiException catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(e.message)),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => _candidateSaving = false,
                                        );
                                      }
                                    }
                                  },
                            color: const Color(0xFF00E5FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Adayın değerlendirmesi',
                    subtitle:
                        'Bu alanı sadece aday doldurur. Yorum mağaza yorumlarında da görünür.',
                    color: const Color(0xFFFFD600),
                    child: _ReadOnlyReview(
                      rating: b.candidateRating,
                      comment: b.candidateComment,
                      emptyText: 'Aday henüz seni değerlendirmedi.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SectionCard(
                  title: 'AI Yorumu',
                  subtitle: 'Yapay zeka mülakat değerlendirmesi',
                  color: const Color(0xFFB388FF),
                  child: reportAsync.when(
                    loading: () => const SkeletonContainer(
                      width: double.infinity,
                      height: 70,
                      borderRadius: 12,
                    ),
                    error: (error, stackTrace) => const Text(
                      'AI analizi henüz hazır değil.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    data: (report) => _AiReview(report: report),
                  ),
                ),
                const SizedBox(height: 24),
                ActionGroup(
                  primary: primaryAction(
                    label: 'Kapat',
                    onTap: () => context.go('/home'),
                    color: const Color(0xFFFFD600),
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

class _AiReview extends StatelessWidget {
  const _AiReview({required this.report});

  final AnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final evaluation = report.aiEvaluation;
    if (evaluation == null) {
      return const Text(
        'AI değerlendirmesi henüz oluşmadı.',
        style: TextStyle(fontWeight: FontWeight.w800),
      );
    }

    final score = evaluation.score?.clamp(1, 10).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Row(
            children: [
              RadialStatGauge(
                value: score,
                max: 10,
                label: 'AI Puan',
                size: 82,
                accentColor: const Color(0xFFB388FF),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score == null
                          ? '-/10'
                          : '${score.toStringAsFixed(score >= 10 ? 0 : 1)}/10',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      evaluation.reason.trim().isEmpty
                          ? 'AI değerlendirmesi oluşturuldu.'
                          : evaluation.reason.trim(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (evaluation.strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AiBulletBlock(
            title: 'Güçlü yanlar',
            color: const Color(0xFF00E5FF),
            items: evaluation.strengths,
          ),
        ],
        if (evaluation.improvements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AiBulletBlock(
            title: 'Gelişim önerileri',
            color: const Color(0xFFFFD600),
            items: evaluation.improvements,
          ),
        ],
      ],
    );
  }
}

class _AiBulletBlock extends StatelessWidget {
  const _AiBulletBlock({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $item',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value.clamp(1, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Text(
                '$selected/10',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var rating = 1; rating <= 10; rating++)
              _RatingChip(
                rating: rating,
                selected: selected == rating,
                enabled: enabled,
                onTap: () => onChanged(rating),
              ),
          ],
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.rating,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int rating;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFD600) : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? bg : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.black.withValues(alpha: enabled ? 1 : 0.35),
              width: selected ? 3 : 2,
            ),
            boxShadow: selected && enabled
                ? const [BoxShadow(color: Colors.black, offset: Offset(3, 3))]
                : null,
          ),
          child: Text(
            '$rating',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black.withValues(alpha: enabled ? 1 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewInput extends StatelessWidget {
  const _ReviewInput({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.hintText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: 4,
      maxLines: 7,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        alignLabelWithHint: true,
        filled: true,
        fillColor: enabled
            ? Colors.white
            : Colors.white.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyReview extends StatelessWidget {
  const _ReadOnlyReview({
    required this.rating,
    required this.comment,
    required this.emptyText,
  });

  final int? rating;
  final String? comment;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final hasComment = comment != null && comment!.trim().isNotEmpty;
    if (!hasComment && rating == null) {
      return Text(
        emptyText,
        style: const TextStyle(fontWeight: FontWeight.w800),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${rating ?? '-'}/10',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          if (hasComment) ...[
            const SizedBox(height: 8),
            Text(
              comment!.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
