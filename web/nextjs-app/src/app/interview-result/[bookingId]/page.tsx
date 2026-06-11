"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppPageState, AppShell, useAppSession } from "@/components/app-shell";
import { AnimatedActionButton, RadialStatGauge, SectionCard, StatusChip } from "@/components/penkrowd";
import { AnalysisReport, Booking, apiFetch, formatDateTime } from "@/lib/api";

export default function InterviewResultPage() {
  const state = useAppSession();
  const params = useParams<{ bookingId: string }>();

  if (state.status === "loading") return <AppPageState message="Sonuç yükleniyor" />;
  if (state.status === "error" || !state.session) return <AppPageState message={state.error ?? "Sonuç açılamadı"} />;

  return (
    <AppShell active="/bookings" session={state.session} title="Geçmiş Mülakat">
      <ResultContent bookingId={params.bookingId} role={state.session.role} token={state.session.token} />
    </AppShell>
  );
}

function ResultContent({ bookingId, role, token }: { bookingId: string; role: "CANDIDATE" | "EXPERT"; token: string }) {
  const router = useRouter();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [report, setReport] = useState<AnalysisReport | null>(null);
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState("");
  const [message, setMessage] = useState("");
  const [formHydrated, setFormHydrated] = useState(false);
  const [lastUpdatedAt, setLastUpdatedAt] = useState<Date | null>(null);
  const isExpert = role === "EXPERT";

  const load = useCallback(async ({ syncForm = false }: { syncForm?: boolean } = {}) => {
    try {
      const next = await apiFetch<Booking>(`/bookings/${bookingId}`, { token });
      setBooking(next);
      if (syncForm || !formHydrated) {
        setRating(isExpert ? next.expertRating ?? 5 : next.candidateRating ?? 5);
        setComment(isExpert ? next.expertComment ?? "" : next.candidateComment ?? "");
        setFormHydrated(true);
      }
      const session = await apiFetch<{ sessionId: string }>(`/interviews/sessions/booking/${bookingId}`, { token }).catch(() => null);
      if (session?.sessionId) {
        const nextReport = await apiFetch<AnalysisReport>(`/interviews/${session.sessionId}/report`, { token }).catch(() => null);
        if (nextReport) setReport(nextReport);
      }
      setLastUpdatedAt(new Date());
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Sonuç alınamadı");
    }
  }, [bookingId, formHydrated, isExpert, token]);

  useEffect(() => {
    void Promise.resolve().then(() => load({ syncForm: true }));
  }, [load]);

  useEffect(() => {
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") {
        void load();
      }
    }, 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!booking) return;
    setMessage("");
    try {
      if (booking.status !== "COMPLETED") {
        setMessage("Değerlendirme için randevu COMPLETED olmalı.");
        return;
      }
      await apiFetch<Booking>(isExpert ? `/bookings/${booking.id}/feedback` : `/bookings/${booking.id}/candidate-feedback`, {
        method: "PATCH",
        token,
        body: JSON.stringify(isExpert ? { expertRating: rating, expertComment: comment } : { candidateRating: rating, candidateComment: comment }),
      });
      setMessage("Değerlendirme kaydedildi.");
      await load({ syncForm: true });
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Değerlendirme kaydedilemedi");
    }
  }

  if (!booking) return <SectionCard title="Randevu" subtitle="Yükleniyor"><p className="muted-copy">{message || "Veriler alınıyor."}</p></SectionCard>;

  const readonlyRating = isExpert ? booking.candidateRating : booking.expertRating;
  const readonlyComment = isExpert ? booking.candidateComment : booking.expertComment;
  const isCompleted = booking.status === "COMPLETED";

  return (
    <section className="result-stack">
      <SectionCard title="Randevu" subtitle="Özet" accent="yellow">
        <div className="result-summary">
          <strong>{formatDateTime(booking.scheduledStart)} - {formatDateTime(booking.scheduledEnd)}</strong>
          <StatusChip tone={booking.status === "COMPLETED" ? "cyan" : "white"}>{booking.status}</StatusChip>
        </div>
        <p className="muted-copy">
          {lastUpdatedAt ? `Otomatik yenilendi: ${lastUpdatedAt.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit", second: "2-digit" })}` : "Sonuçlar otomatik yenilenir."}
        </p>
      </SectionCard>

      {isExpert ? null : (
        <SectionCard title="Uzmanın değerlendirmesi" subtitle="Bu alanı sadece uzman doldurur" accent="cyan">
          <ReadOnlyReview rating={readonlyRating} comment={readonlyComment} empty="Uzman henüz seni değerlendirmedi." />
        </SectionCard>
      )}

      <SectionCard
        title={isExpert ? "Adayı değerlendir" : "Uzmanı değerlendir"}
        subtitle={isCompleted ? (isExpert ? "Adaya 10 üzerinden puan ver ve nedenini yaz" : "Uzmanı ve mağazasını 10 üzerinden değerlendir") : "Sadece COMPLETED randevuda değerlendirme yapılır"}
        accent={isExpert ? "cyan" : "yellow"}
      >
        <form className="form-stack" onSubmit={submit}>
          <RatingSelector enabled={isCompleted} value={rating} onChange={setRating} label={isExpert ? "Aday puanı" : "Uzman puanı"} />
          <label>{isExpert ? "Adaya yorum" : "Uzman yorumu"}<textarea disabled={!isCompleted} value={comment} onChange={(event) => setComment(event.target.value)} rows={5} required /></label>
          {message ? <p className={message.includes("kaydedildi") ? "muted-copy" : "form-error"}>{message}</p> : null}
          <AnimatedActionButton color="cyan" disabled={!isCompleted} fullWidth>Kaydet</AnimatedActionButton>
        </form>
      </SectionCard>

      {isExpert ? (
        <SectionCard title="Adayın değerlendirmesi" subtitle="Bu alanı sadece aday doldurur. Yorum mağaza yorumlarında da görünür." accent="yellow">
          <ReadOnlyReview rating={readonlyRating} comment={readonlyComment} empty="Aday henüz seni değerlendirmedi." />
        </SectionCard>
      ) : null}

      <SectionCard title="AI Yorumu" subtitle={report ? "Konuşma analizi" : "Rapor bekleniyor"} accent="purple">
        {report ? (
          <AiReview report={report} />
        ) : (
          <p className="muted-copy">AI analizi henüz hazır değil.</p>
        )}
      </SectionCard>

      <AnimatedActionButton color="yellow" onClick={() => router.push("/bookings")}>Kapat</AnimatedActionButton>
    </section>
  );
}

function AiReview({ report }: { report: AnalysisReport }) {
  const evaluation = report.analysis.aiEvaluation;
  if (!evaluation) {
    return <p className="muted-copy">AI değerlendirmesi henüz oluşmadı.</p>;
  }
  return (
    <div className="ai-review-panel">
      <div className="ai-score-row">
        <RadialStatGauge value={evaluation.score ?? null} max={10} label="AI Puan" accent="purple" />
        <div>
          <strong>{evaluation.score == null ? "-/10" : `${formatScore(evaluation.score)}/10`}</strong>
          <p>{evaluation.reason || "AI değerlendirmesi oluşturuldu."}</p>
        </div>
      </div>
      {evaluation.strengths?.length ? (
        <div className="ai-list-block">
          <strong>Güçlü yanlar</strong>
          {evaluation.strengths.map((item) => <p key={item}>{item}</p>)}
        </div>
      ) : null}
      {evaluation.improvements?.length ? (
        <div className="ai-list-block">
          <strong>Gelişim önerileri</strong>
          {evaluation.improvements.map((item) => <p key={item}>{item}</p>)}
        </div>
      ) : null}
    </div>
  );
}

function formatScore(value: number) {
  return value >= 10 ? value.toFixed(0) : value.toFixed(1);
}

function ReadOnlyReview({ rating, comment, empty }: { rating?: number | null; comment?: string | null; empty: string }) {
  if (rating == null && !comment) return <p className="muted-copy">{empty}</p>;
  return (
    <div className="readonly-review">
      <strong>{rating ?? "-"}/10</strong>
      {comment ? <p>{comment}</p> : null}
    </div>
  );
}

function RatingSelector({ enabled, label, value, onChange }: { enabled: boolean; label: string; value: number; onChange: (value: number) => void }) {
  return (
    <div className="rating-selector">
      <div className="section-title row">
        <strong>{label}</strong>
        <StatusChip>{value}/10</StatusChip>
      </div>
      <div className="rating-grid">
        {Array.from({ length: 10 }, (_, index) => index + 1).map((rating) => (
          <button className={rating === value ? "rating-chip is-selected" : "rating-chip"} disabled={!enabled} onClick={() => onChange(rating)} type="button" key={rating}>
            {rating}
          </button>
        ))}
      </div>
    </div>
  );
}
