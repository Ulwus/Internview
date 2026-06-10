"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppPageState, AppShell, useAppSession } from "@/components/app-shell";
import { AnimatedActionButton, PenkrowdCard, RadialStatGauge, SectionCard, StatusChip } from "@/components/penkrowd";
import {
  Booking,
  ExpertReview,
  ExpertStats,
  PageResponse,
  ShopSummary,
  Slot,
  apiFetch,
  formatDateTime,
  getExpertReviews,
  getExpertStats,
  getShop,
  normalizeMediaUrl,
  shopExpertName,
} from "@/lib/api";

const REVIEWS_PER_PAGE = 4;

export default function ShopDetailPage() {
  const state = useAppSession();
  const params = useParams<{ id: string }>();

  if (state.status === "loading") return <AppPageState message="Dükkan yükleniyor" />;
  if (state.status === "error" || !state.session) return <AppPageState message={state.error ?? "Dükkan açılamadı"} />;

  return (
    <AppShell active="/marketplace" session={state.session} title="Uzman dükkanı">
      <ShopDetailContent shopId={params.id} token={state.session.token} />
    </AppShell>
  );
}

function ShopDetailContent({ shopId, token }: { shopId: string; token: string }) {
  const router = useRouter();
  const [shop, setShop] = useState<ShopSummary | null>(null);
  const [stats, setStats] = useState<ExpertStats | null>(null);
  const [reviews, setReviews] = useState<ExpertReview[]>([]);
  const [slots, setSlots] = useState<Slot[]>([]);
  const [selectedDay, setSelectedDay] = useState("");
  const [selectedSlot, setSelectedSlot] = useState("");
  const [reviewPage, setReviewPage] = useState(0);
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    setMessage("");
    try {
      const nextShop = await getShop(shopId, token);
      setShop(nextShop);
      const [nextStats, nextReviews, nextSlots] = await Promise.all([
        getExpertStats(nextShop.expertUserId, token).catch(() => null),
        getExpertReviews(nextShop.expertUserId, token).catch((): PageResponse<ExpertReview> => ({
          items: [],
          page: 0,
          size: 0,
          totalElements: 0,
          totalPages: 0,
          hasNext: false,
          hasPrevious: false,
        })),
        apiFetch<Slot[]>(`/availability/${nextShop.expertUserId}`),
      ]);
      setStats(nextStats);
      setReviews(nextReviews.items);
      setReviewPage(0);
      setSlots(nextSlots.filter((slot) => !slot.booked));
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Dükkan alınamadı");
    }
  }, [shopId, token]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  const slotsByDay = useMemo(() => {
    const grouped = new Map<string, Slot[]>();
    for (const slot of slots) {
      const day = localDayKey(slot.startTime);
      grouped.set(day, [...(grouped.get(day) ?? []), slot]);
    }
    return [...grouped.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [slots]);

  const daySlots = selectedDay ? slotsByDay.find(([day]) => day === selectedDay)?.[1] ?? [] : [];
  const totalReviewPages = Math.max(1, Math.ceil(reviews.length / REVIEWS_PER_PAGE));
  const visibleReviews = reviews.slice(reviewPage * REVIEWS_PER_PAGE, reviewPage * REVIEWS_PER_PAGE + REVIEWS_PER_PAGE);

  async function createBooking() {
    if (!shop || !selectedSlot) {
      setMessage("Önce gün ve saat seç.");
      return;
    }
    try {
      const booking = await apiFetch<Booking>("/bookings", {
        method: "POST",
        token,
        body: JSON.stringify({ expertId: shop.expertUserId, slotId: selectedSlot }),
      });
      router.push(`/bookings?created=${booking.id}`);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Randevu oluşturulamadı");
    }
  }

  if (message && !shop) return <p className="form-error">{message}</p>;
  if (!shop) return <SectionCard title="Dükkan" subtitle="Yükleniyor"><p className="muted-copy">Veriler alınıyor.</p></SectionCard>;

  return (
    <>
      <PenkrowdCard accent="cyan" className="shop-hero-card">
        <span className="profile-avatar image-avatar">
          {shop.expertAvatarUrl ? <img src={normalizeMediaUrl(shop.expertAvatarUrl)} alt="" /> : shop.expertFirstName.slice(0, 1).toUpperCase()}
        </span>
        <div>
          <h2>{shopExpertName(shop)}</h2>
          <p>{[shop.industry?.name, shop.hourlyRate != null ? `${shop.hourlyRate} ${shop.currency ?? ""}` : null].filter(Boolean).join(" • ")}</p>
        </div>
        <RadialStatGauge value={stats?.averageRating ?? shop.averageRating} max={10} label="Puan" accent="purple" />
      </PenkrowdCard>

      <section className="content-grid">
        <section className="right-stack">
          <SectionCard title="Açıklama" subtitle="Uzman profili">
            <p className="muted-copy">{shop.description || "Açıklama yok."}</p>
          </SectionCard>
          <div className="shop-stat-grid">
            <MiniStat label="Tamamlanan" value={stats?.completedCount ?? 0} />
            <MiniStat label="İptal" value={stats?.cancelledCount ?? 0} />
            <MiniStat label="İncelemeler" value={stats?.totalRated ?? 0} />
          </div>
          <SectionCard
            title="Yorumlar"
            subtitle="Aday değerlendirmeleri"
            action={reviews.length > 0 ? <StatusChip>{reviews.length}</StatusChip> : undefined}
          >
            <div className="review-grid">
              {visibleReviews.map((review) => (
                <PenkrowdCard accent="purple" className="review-card marketplace-review-card" key={review.bookingId}>
                  <div className="review-card-head">
                    <span>Senin yorumun</span>
                    <strong>{review.rating == null ? "Puan yok" : `${review.rating}/10`}</strong>
                  </div>
                  <p>{review.comment || "Yorum yazılmamış."}</p>
                  {review.scheduledEnd ? <small>{formatDateTime(review.scheduledEnd)}</small> : null}
                </PenkrowdCard>
              ))}
              {reviews.length === 0 ? <p className="muted-copy">Henüz yorum yok.</p> : null}
            </div>
            {reviews.length > REVIEWS_PER_PAGE ? (
              <div className="pagination-bar" aria-label="Yorum sayfaları">
                <button disabled={reviewPage === 0} onClick={() => setReviewPage((page) => Math.max(0, page - 1))}>Önceki</button>
                <span>{reviewPage + 1} / {totalReviewPages}</span>
                <button disabled={reviewPage >= totalReviewPages - 1} onClick={() => setReviewPage((page) => Math.min(totalReviewPages - 1, page + 1))}>Sonraki</button>
              </div>
            ) : null}
          </SectionCard>
        </section>

        <SectionCard title="Müsaitlik" subtitle="Gün ve saat seç">
          <div className="calendar-card slot-picker-panel">
            <div className="slot-step-title"><span>1</span><strong>Gün seç</strong><em>{slots.length} seans</em></div>
            <div className="day-grid">
              {slotsByDay.map(([day, dayItems]) => (
                <button className={selectedDay === day ? "day-cell is-selected" : "day-cell"} onClick={() => { setSelectedDay(day); setSelectedSlot(""); }} key={day}>
                  <strong>{new Intl.DateTimeFormat("tr-TR", { day: "2-digit", month: "short" }).format(new Date(day))}</strong>
                  <span>{dayItems.length} seans</span>
                </button>
              ))}
              {slotsByDay.length === 0 ? <p className="muted-copy">Uygun slot yok.</p> : null}
            </div>
            <div className="slot-step-title"><span>2</span><strong>Saat seç</strong></div>
            {daySlots.length > 0 ? (
              <div className="time-grid">
                {daySlots.map((slot) => (
                  <button className={selectedSlot === slot.id ? "time-cell is-selected" : "time-cell"} onClick={() => setSelectedSlot(slot.id)} key={slot.id}>
                    {new Intl.DateTimeFormat("tr-TR", { hour: "2-digit", minute: "2-digit" }).format(new Date(slot.startTime))} - {new Intl.DateTimeFormat("tr-TR", { hour: "2-digit", minute: "2-digit" }).format(new Date(slot.endTime))}
                  </button>
                ))}
              </div>
            ) : <p className="muted-copy">Müsait günlerden birini seç.</p>}
          </div>
          {message ? <p className="form-error">{message}</p> : null}
          <AnimatedActionButton color="cyan" fullWidth onClick={createBooking}>İstek at</AnimatedActionButton>
        </SectionCard>
      </section>
    </>
  );
}

function localDayKey(value: string) {
  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function MiniStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="mini-stat-card">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
