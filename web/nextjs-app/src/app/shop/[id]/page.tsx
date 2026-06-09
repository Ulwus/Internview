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
      const day = new Date(slot.startTime).toISOString().slice(0, 10);
      grouped.set(day, [...(grouped.get(day) ?? []), slot]);
    }
    return [...grouped.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [slots]);

  const daySlots = selectedDay ? slotsByDay.find(([day]) => day === selectedDay)?.[1] ?? [] : [];

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
          <SectionCard title="Yorumlar" subtitle="Aday değerlendirmeleri">
            <div className="segment-list">
              {reviews.map((review) => (
                <PenkrowdCard accent="purple" className="review-card" key={review.bookingId}>
                  <strong>{review.rating == null ? "Değerlendirme" : `Puan: ${review.rating}/10`}</strong>
                  <p className="muted-copy">{review.comment || "Yorum yok"}</p>
                  <AnimatedActionButton color="white" href={`/interview-result/${review.bookingId}`}>Sonucu aç</AnimatedActionButton>
                </PenkrowdCard>
              ))}
              {reviews.length === 0 ? <p className="muted-copy">Henüz yorum yok.</p> : null}
            </div>
          </SectionCard>
        </section>

        <SectionCard title="Müsaitlik" subtitle="Gün ve saat seç">
          <div className="calendar-card">
            <div className="day-grid">
              {slotsByDay.map(([day, dayItems]) => (
                <button className={selectedDay === day ? "day-cell is-selected" : "day-cell"} onClick={() => { setSelectedDay(day); setSelectedSlot(""); }} key={day}>
                  <strong>{new Intl.DateTimeFormat("tr-TR", { day: "2-digit", month: "short" }).format(new Date(day))}</strong>
                  <span>{dayItems.length} saat</span>
                </button>
              ))}
              {slotsByDay.length === 0 ? <p className="muted-copy">Uygun slot yok.</p> : null}
            </div>
            {daySlots.length > 0 ? (
              <div className="time-grid">
                {daySlots.map((slot) => (
                  <button className={selectedSlot === slot.id ? "time-cell is-selected" : "time-cell"} onClick={() => setSelectedSlot(slot.id)} key={slot.id}>
                    {new Intl.DateTimeFormat("tr-TR", { hour: "2-digit", minute: "2-digit" }).format(new Date(slot.startTime))}
                  </button>
                ))}
              </div>
            ) : null}
          </div>
          {message ? <p className="form-error">{message}</p> : null}
          <AnimatedActionButton color="cyan" fullWidth onClick={createBooking}>İstek at</AnimatedActionButton>
        </SectionCard>
      </section>
    </>
  );
}

function MiniStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="mini-stat-card">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
