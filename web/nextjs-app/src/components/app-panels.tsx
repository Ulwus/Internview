"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Booking,
  DashboardData,
  ExpertSummary,
  Industry,
  PageResponse,
  ShopSummary,
  Skill,
  Slot,
  UserProfile,
  apiFetch,
  formatDateTime,
  fullName,
  listShops,
  normalizeMediaUrl,
  searchExperts,
  shopExpertName,
  uploadAvatar,
} from "@/lib/api";
import { AnimatedActionButton, PenkrowdCard, RadialStatGauge, SectionCard, StatusChip } from "@/components/penkrowd";
import type { AppSession } from "@/components/app-shell";

type Reloadable = {
  session: AppSession;
};

export function OverviewPanel({ session }: Reloadable) {
  const [data, setData] = useState<DashboardData | null>(null);
  const [message, setMessage] = useState("");
  const [now] = useState(() => Date.now());

  const load = useCallback(async () => {
    setMessage("");
    try {
      const isExpert = session.role === "EXPERT";
      if (isExpert) {
        const [bookings, availability, ownShop, ownExpertProfile] = await Promise.all([
          apiFetch<PageResponse<Booking>>("/bookings/me/expert?size=50", { token: session.token }),
          apiFetch<Slot[]>("/experts/me/availability", { token: session.token }),
          apiFetch<ShopSummary | null>("/shops/me", { token: session.token }).catch(() => null),
          apiFetch<DashboardData["ownExpertProfile"]>("/experts/me", { token: session.token }).catch(() => undefined),
        ]);
        setData({ me: session.me, bookings, availability, ownShop, ownExpertProfile });
      } else {
        const [bookings, experts, shops] = await Promise.all([
          apiFetch<PageResponse<Booking>>("/bookings/me/candidate?size=50", { token: session.token }),
          apiFetch<PageResponse<ExpertSummary>>("/experts?is_available=true&size=20"),
          apiFetch<PageResponse<ShopSummary>>("/shops?published_only=true&is_available=true&size=20").catch(() => undefined),
        ]);
        setData({ me: session.me, bookings, experts, shops });
      }
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Panel verisi alınamadı");
    }
  }, [session]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  const bookings = data?.bookings?.items ?? [];
  const completed = bookings.filter((booking) => booking.status === "COMPLETED");
  const pending = bookings.filter((booking) => booking.status === "PENDING");
  const upcoming = bookings.filter((booking) => booking.status === "CONFIRMED" && new Date(booking.scheduledEnd).getTime() > now);
  const avg = average(session.role === "EXPERT" ? bookings.map((booking) => booking.candidateRating) : bookings.map((booking) => booking.expertRating));

  return (
    <>
      {message ? <p className="form-error">{message}</p> : null}
      <section className="overview-grid">
        <MetricCard title="Ortalama puan" label="Tamamlanan mülakatlardan" accent="cyan">
          <RadialStatGauge value={avg} max={10} label="Puan" />
        </MetricCard>
        <MetricCard title="Yaklaşan" label="Onaylı randevu" accent="yellow">
          <strong className="huge-number">{upcoming.length}</strong>
        </MetricCard>
        <MetricCard title={session.role === "EXPERT" ? "Onay bekleyen" : "Geçmiş"} label="Randevu durumu" accent="purple">
          <strong className="huge-number">{session.role === "EXPERT" ? pending.length : completed.length}</strong>
        </MetricCard>
        <MetricCard title={session.role === "EXPERT" ? "Açık slot" : "Uygun uzman"} label={session.role === "EXPERT" ? "Müsaitlik" : "Pazar"} accent="orange">
          <strong className="huge-number">{session.role === "EXPERT" ? data?.availability?.length ?? 0 : data?.experts?.totalElements ?? 0}</strong>
        </MetricCard>
      </section>

      <section className="content-grid">
        <SectionCard title="Sıradaki randevu" subtitle="Saat aralığında mülakat odası açılır">
          <div className="segment-list">
            {upcoming.slice(0, 3).map((booking) => (
              <BookingRow booking={booking} role={session.role} token={session.token} key={booking.id} />
            ))}
            {upcoming.length === 0 ? <p className="muted-copy">Yaklaşan onaylı randevu yok.</p> : null}
          </div>
        </SectionCard>
        <SectionCard title={session.role === "EXPERT" ? "Vitrin" : "Keşif"} subtitle={session.role === "EXPERT" ? "Shop ve müsaitlik durumu" : "Uygun mülakatçılar"}>
          {session.role === "EXPERT" ? (
            <div className="mini-stack">
              <p className="muted-copy">{data?.ownShop?.description || data?.ownExpertProfile?.headline || "Vitrin bilgilerini Profil/Pazar sayfasından doldur."}</p>
              <StatusChip tone={data?.ownShop?.isPublished ? "cyan" : "white"}>{data?.ownShop?.isPublished ? "Yayında" : "Taslak"}</StatusChip>
            </div>
          ) : (
            <div className="mini-stack">
              <strong>{data?.shops?.totalElements ?? 0} pazar ilanı</strong>
              <p className="muted-copy">Pazar sayfasından saat seçip randevu isteği gönderebilirsin.</p>
            </div>
          )}
        </SectionCard>
      </section>
    </>
  );
}

export function BookingsPanel({ session }: Reloadable) {
  const [items, setItems] = useState<Booking[]>([]);
  const [tab, setTab] = useState<"pending" | "upcoming" | "past">("upcoming");
  const [message, setMessage] = useState("");
  const [now, setNow] = useState(() => Date.now());

  const load = useCallback(async () => {
    setMessage("");
    try {
      const path = session.role === "EXPERT" ? "/bookings/me/expert?size=50" : "/bookings/me/candidate?size=50";
      const page = await apiFetch<PageResponse<Booking>>(path, { token: session.token });
      setItems(page.items);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Randevular alınamadı");
    }
  }, [session]);

  useEffect(() => {
    void Promise.resolve().then(load);
    const timer = window.setInterval(() => {
      setNow(Date.now());
      void load();
    }, 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  const visible = items.filter((booking) => {
    if (tab === "pending") return booking.status === "PENDING";
    if (tab === "upcoming") return booking.status === "CONFIRMED" && new Date(booking.scheduledEnd).getTime() > now;
    return booking.status === "COMPLETED" || booking.status === "CANCELLED" || new Date(booking.scheduledEnd).getTime() < now;
  });

  return (
    <SectionCard title="Randevular" subtitle="Bekleyen, yaklaşan ve geçmiş mülakatlar" action={<StatusChip>{visible.length}</StatusChip>}>
      <div className="pk-tabs page-tabs" role="tablist">
        <i style={{ left: `${["pending", "upcoming", "past"].indexOf(tab) * 33.333}%`, width: "33.333%" }} />
        <button className={tab === "pending" ? "is-selected" : ""} onClick={() => setTab("pending")}>Bekleyen</button>
        <button className={tab === "upcoming" ? "is-selected" : ""} onClick={() => setTab("upcoming")}>Yaklaşan</button>
        <button className={tab === "past" ? "is-selected" : ""} onClick={() => setTab("past")}>Geçmiş</button>
      </div>
      {message ? <p className="form-error">{message}</p> : null}
      <div className="segment-list page-list">
        {visible.map((booking) => (
          <BookingRow booking={booking} role={session.role} token={session.token} reload={load} key={booking.id} />
        ))}
        {visible.length === 0 ? <p className="muted-copy">Bu sekmede randevu yok.</p> : null}
      </div>
    </SectionCard>
  );
}

export function ExpertsPanel({ session }: Reloadable) {
  const [experts, setExperts] = useState<ExpertSummary[]>([]);
  const [industries, setIndustries] = useState<Industry[]>([]);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [search, setSearch] = useState("");
  const [industry, setIndustry] = useState("");
  const [skill, setSkill] = useState("");
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    setMessage("");
    try {
      const [expertPage, nextIndustries, nextSkills] = await Promise.all([
        searchExperts({ search, industry, skill, isAvailable: true, size: 30 }),
        apiFetch<Industry[]>("/industries").catch(() => []),
        apiFetch<Skill[]>("/skills").catch(() => []),
      ]);
      setExperts(expertPage.items);
      setIndustries(nextIndustries);
      setSkills(nextSkills);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Uzmanlar alınamadı");
    }
  }, [industry, search, skill]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  if (session.role === "EXPERT") return <AvailabilityPanel session={session} />;

  return (
    <SectionCard title="Uzmanlar" subtitle="Filtrele, slot seç, randevu talebi gönder" action={<StatusChip>{experts.length}</StatusChip>}>
      <form className="filter-row" onSubmit={(event) => { event.preventDefault(); void load(); }}>
        <input placeholder="İsim, şirket, başlık" value={search} onChange={(event) => setSearch(event.target.value)} />
        <select value={industry} onChange={(event) => setIndustry(event.target.value)}>
          <option value="">Tüm sektörler</option>
          {industries.map((item) => <option value={item.slug} key={item.id}>{item.name}</option>)}
        </select>
        <select value={skill} onChange={(event) => setSkill(event.target.value)}>
          <option value="">Tüm yetenekler</option>
          {skills.map((item) => <option value={item.slug} key={item.id}>{item.name}</option>)}
        </select>
        <AnimatedActionButton color="cyan">Ara</AnimatedActionButton>
      </form>
      {message ? <p className="form-error">{message}</p> : null}
      <div className="catalog-grid">
        {experts.map((expert) => <ExpertBookingCard expert={expert} token={session.token} key={expert.id} />)}
      </div>
    </SectionCard>
  );
}

export function MarketplacePanel({ session }: Reloadable) {
  if (session.role === "EXPERT") return <ShopEditorPanel session={session} />;
  return <CandidateMarketplacePanel session={session} />;
}

export function ProfilePanel({ session }: Reloadable) {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [firstName, setFirstName] = useState(session.me.first_name ?? "");
  const [lastName, setLastName] = useState(session.me.last_name ?? "");
  const [avatarUrl, setAvatarUrl] = useState("");
  const [uploading, setUploading] = useState(false);
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    try {
      const next = await apiFetch<UserProfile>("/users/profile", { token: session.token });
      setProfile(next);
      setFirstName(next.firstName);
      setLastName(next.lastName);
      setAvatarUrl(next.avatarUrl ?? "");
    } catch {
      setProfile(null);
    }
  }, [session.token]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    try {
      await apiFetch<UserProfile>("/users/profile", {
        method: "PUT",
        token: session.token,
        body: JSON.stringify({ firstName, lastName, avatarUrl: avatarUrl || null }),
      });
      setMessage("Profil güncellendi.");
      await load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Profil güncellenemedi");
    }
  }

  async function uploadProfileAvatar(file?: File | null) {
    if (!file) return;
    setUploading(true);
    setMessage("");
    try {
      const url = await uploadAvatar(file, session.token);
      await apiFetch<UserProfile>("/users/profile", {
        method: "PUT",
        token: session.token,
        body: JSON.stringify({ firstName, lastName, avatarUrl: url }),
      });
      setMessage("Profil fotoğrafı güncellendi.");
      await load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Fotoğraf yüklenemedi");
    } finally {
      setUploading(false);
    }
  }

  return (
    <section className="content-grid">
      <SectionCard title="Profil" subtitle="Kullanıcı bilgileri">
        <div className="profile-head-card">
          <span className="profile-avatar image-avatar">
            {avatarUrl ? <img src={normalizeMediaUrl(avatarUrl)} alt="" /> : (firstName || session.me.email).slice(0, 1).toUpperCase()}
          </span>
          <div>
            <strong>{`${firstName} ${lastName}`.trim() || fullName(session.me)}</strong>
            <p>{session.me.email}</p>
            <label className="file-upload-button">
              {uploading ? "Yükleniyor..." : "Fotoğrafı değiştir"}
              <input accept="image/*" disabled={uploading} onChange={(event) => void uploadProfileAvatar(event.target.files?.[0])} type="file" />
            </label>
          </div>
          <StatusChip tone="yellow">{session.role}</StatusChip>
        </div>
        <form className="form-stack compact-form" onSubmit={submit}>
          <div className="form-grid">
            <label>Ad<input value={firstName} onChange={(event) => setFirstName(event.target.value)} required /></label>
            <label>Soyad<input value={lastName} onChange={(event) => setLastName(event.target.value)} required /></label>
          </div>
          {message ? <p className={message.includes("güncellendi") ? "muted-copy" : "form-error"}>{message}</p> : null}
          <AnimatedActionButton color="purple" fullWidth>Kaydet</AnimatedActionButton>
        </form>
      </SectionCard>
      <SectionCard title="Hesap" subtitle={session.role === "EXPERT" ? "Mülakatçı" : "Aday"}>
        <div className="profile-summary">
          <span className="profile-avatar image-avatar">
            {avatarUrl ? <img src={normalizeMediaUrl(avatarUrl)} alt="" /> : (firstName || session.me.email).slice(0, 1).toUpperCase()}
          </span>
          <strong>{profile ? `${profile.firstName} ${profile.lastName}` : fullName(session.me)}</strong>
          <p>{session.me.email}</p>
          <StatusChip tone="cyan">{session.role}</StatusChip>
        </div>
      </SectionCard>
    </section>
  );
}

function AvailabilityPanel({ session }: Reloadable) {
  const [slots, setSlots] = useState<Slot[]>([]);
  const [startTime, setStartTime] = useState("");
  const [endTime, setEndTime] = useState("");
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    const next = await apiFetch<Slot[]>("/experts/me/availability", { token: session.token });
    setSlots(next);
  }, [session.token]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    try {
      await apiFetch<Slot>("/experts/me/availability", {
        method: "POST",
        token: session.token,
        body: JSON.stringify({ startTime: new Date(startTime).toISOString(), endTime: new Date(endTime).toISOString() }),
      });
      setStartTime("");
      setEndTime("");
      await load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Slot oluşturulamadı");
    }
  }

  async function remove(slotId: string) {
    await apiFetch(`/experts/me/availability/${slotId}`, { method: "DELETE", token: session.token });
    await load();
  }

  return (
    <section className="content-grid">
      <SectionCard title="Müsaitlik" subtitle="Adayların seçebileceği saatler" action={<StatusChip>{slots.length}</StatusChip>}>
        <form className="form-stack compact-form" onSubmit={submit}>
          <div className="form-grid">
            <label>Başlangıç<input value={startTime} onChange={(event) => setStartTime(event.target.value)} type="datetime-local" required /></label>
            <label>Bitiş<input value={endTime} onChange={(event) => setEndTime(event.target.value)} type="datetime-local" required /></label>
          </div>
          {message ? <p className="form-error">{message}</p> : null}
          <AnimatedActionButton color="cyan" fullWidth>Slot ekle</AnimatedActionButton>
        </form>
      </SectionCard>
      <SectionCard title="Açık saatler" subtitle="Tıklayınca silinir">
        <div className="file-list">
          {slots.map((slot) => (
            <button className="slot-button subtle" onClick={() => void remove(slot.id)} key={slot.id}>
              {formatDateTime(slot.startTime)} - {formatDateTime(slot.endTime)}
            </button>
          ))}
          {slots.length === 0 ? <p className="muted-copy">Açık slot yok.</p> : null}
        </div>
      </SectionCard>
    </section>
  );
}

function CandidateMarketplacePanel({ session }: Reloadable) {
  const [shops, setShops] = useState<ShopSummary[]>([]);
  const [industries, setIndustries] = useState<Industry[]>([]);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [industry, setIndustry] = useState("");
  const [skill, setSkill] = useState("");
  const [minRating, setMinRating] = useState("");
  const [minPrice, setMinPrice] = useState("");
  const [maxPrice, setMaxPrice] = useState("");
  const [availability, setAvailability] = useState("");
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    setMessage("");
    try {
      const [page, nextIndustries, nextSkills] = await Promise.all([
        listShops({
          token: session.token,
          industry,
          skill,
          minRating,
          minPrice,
          maxPrice,
          isAvailable: availability === "" ? undefined : availability === "true",
          publishedOnly: true,
          size: 30,
        }),
        apiFetch<Industry[]>("/industries").catch(() => []),
        apiFetch<Skill[]>("/skills").catch(() => []),
      ]);
      setShops(page.items);
      setIndustries(nextIndustries);
      setSkills(nextSkills);
    } catch (err) {
      setShops([]);
      setMessage(err instanceof Error ? err.message : "Pazar verisi alınamadı");
    }
  }, [availability, industry, maxPrice, minPrice, minRating, session.token, skill]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  return (
    <SectionCard title="Pazar" subtitle="Mülakatçı vitrinleri" action={<StatusChip>{shops.length}</StatusChip>}>
      <form className="filter-row" onSubmit={(event) => { event.preventDefault(); void load(); }}>
        <select value={industry} onChange={(event) => setIndustry(event.target.value)}>
          <option value="">Tüm sektörler</option>
          {industries.map((item) => <option value={item.slug} key={item.id}>{item.name}</option>)}
        </select>
        <select value={skill} onChange={(event) => setSkill(event.target.value)}>
          <option value="">Tüm yetenekler</option>
          {skills.map((item) => <option value={item.slug} key={item.id}>{item.name}</option>)}
        </select>
        <select value={minRating} onChange={(event) => setMinRating(event.target.value)}>
          <option value="">Tüm puanlar</option>
          <option value="8">8+ puan</option>
          <option value="6">6+ puan</option>
          <option value="4">4+ puan</option>
        </select>
        <input placeholder="Min fiyat" value={minPrice} onChange={(event) => setMinPrice(event.target.value)} type="number" min="0" />
        <input placeholder="Max fiyat" value={maxPrice} onChange={(event) => setMaxPrice(event.target.value)} type="number" min="0" />
        <select value={availability} onChange={(event) => setAvailability(event.target.value)}>
          <option value="">Tüm müsaitlik</option>
          <option value="true">Müsait</option>
          <option value="false">Müsait değil</option>
        </select>
        <AnimatedActionButton color="yellow">Filtrele</AnimatedActionButton>
      </form>
      {message ? <p className="form-error">{message}</p> : null}
      <div className="catalog-grid">
        {shops.map((shop) => <ShopBookingCard shop={shop} key={shop.id} />)}
        {!message && shops.length === 0 ? <p className="muted-copy">Yayında pazar ilanı yok.</p> : null}
      </div>
    </SectionCard>
  );
}

function ShopEditorPanel({ session }: Reloadable) {
  const [shop, setShop] = useState<ShopSummary | null>(null);
  const [industries, setIndustries] = useState<Industry[]>([]);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [description, setDescription] = useState("");
  const [yearsOfExperience, setYearsOfExperience] = useState("");
  const [hourlyRate, setHourlyRate] = useState("");
  const [currency, setCurrency] = useState("TRY");
  const [industrySlug, setIndustrySlug] = useState("");
  const [skillSlug, setSkillSlug] = useState("");
  const [isPublished, setPublished] = useState(true);
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    const [nextShop, nextIndustries, nextSkills] = await Promise.all([
      apiFetch<ShopSummary | null>("/shops/me", { token: session.token }).catch(() => null),
      apiFetch<Industry[]>("/industries").catch(() => []),
      apiFetch<Skill[]>("/skills").catch(() => []),
    ]);
    setShop(nextShop);
    setIndustries(nextIndustries);
    setSkills(nextSkills);
    if (nextShop) {
      setDescription(nextShop.description ?? "");
      setYearsOfExperience(String(nextShop.yearsOfExperience ?? ""));
      setHourlyRate(String(nextShop.hourlyRate ?? ""));
      setCurrency(nextShop.currency ?? "TRY");
      setIndustrySlug(nextShop.industry?.slug ?? "");
      setSkillSlug(nextShop.skills?.[0]?.slug ?? "");
      setPublished(nextShop.isPublished);
    }
  }, [session.token]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    try {
      await apiFetch<ShopSummary>("/shops/me", {
        method: "PUT",
        token: session.token,
        body: JSON.stringify({
          description,
          yearsOfExperience: Number(yearsOfExperience || 0),
          hourlyRate: Number(hourlyRate || 0),
          currency,
          industrySlug,
          skillSlugs: skillSlug ? [skillSlug] : [],
          isPublished,
        }),
      });
      setMessage("Vitrin güncellendi.");
      await load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Vitrin güncellenemedi");
    }
  }

  return (
    <section className="content-grid">
      <SectionCard title="Pazar vitrinim" subtitle="Adayların gördüğü mülakatçı kartı">
        <form className="form-stack compact-form" onSubmit={submit}>
          <label>Açıklama<textarea value={description} onChange={(event) => setDescription(event.target.value)} rows={5} /></label>
          <div className="form-grid">
            <label>Deneyim yılı<input value={yearsOfExperience} onChange={(event) => setYearsOfExperience(event.target.value)} type="number" min="0" /></label>
            <label>Saatlik ücret<input value={hourlyRate} onChange={(event) => setHourlyRate(event.target.value)} type="number" min="0" /></label>
          </div>
          <div className="form-grid">
            <label>Para birimi<input value={currency} onChange={(event) => setCurrency(event.target.value.toUpperCase())} maxLength={3} /></label>
            <label>Sektör<select value={industrySlug} onChange={(event) => setIndustrySlug(event.target.value)}>
              <option value="">Seç</option>
              {industries.map((item) => <option value={item.slug} key={item.id}>{item.name}</option>)}
            </select></label>
          </div>
          <label>Yetenek<select value={skillSlug} onChange={(event) => setSkillSlug(event.target.value)}>
            <option value="">Seç</option>
            {skills.map((item) => <option value={item.slug} key={item.id}>{item.name}</option>)}
          </select></label>
          <label className="check-row"><input checked={isPublished} onChange={(event) => setPublished(event.target.checked)} type="checkbox" /> Yayında</label>
          {message ? <p className={message.includes("güncellendi") ? "muted-copy" : "form-error"}>{message}</p> : null}
          <AnimatedActionButton color="orange" fullWidth>Vitrini kaydet</AnimatedActionButton>
        </form>
      </SectionCard>
      <SectionCard title="Önizleme" subtitle={shop?.isPublished ? "Yayında" : "Taslak"}>
        <div className="expert-card">
          <p className="eyebrow">{shop?.industry?.name ?? "Sektör"}</p>
          <h2>{fullName(session.me)}</h2>
          <p className="muted-copy">{description || "Açıklama henüz yok."}</p>
          <StatusChip tone={isPublished ? "cyan" : "white"}>{isPublished ? "Yayında" : "Taslak"}</StatusChip>
        </div>
      </SectionCard>
    </section>
  );
}

function ExpertBookingCard({ expert, token }: { expert: ExpertSummary; token: string }) {
  const [slots, setSlots] = useState<Slot[]>([]);
  const [message, setMessage] = useState("");
  const expertUserId = expert.userId || expert.id;

  async function loadSlots() {
    setMessage("");
    try {
      setSlots(await apiFetch<Slot[]>(`/availability/${expertUserId}`));
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Saatler alınamadı");
    }
  }

  return (
    <PenkrowdCard accent="cyan" className="expert-card">
      <div className="section-title row">
        <div>
          <p className="eyebrow">{expert.industry?.name ?? "Uzman"}</p>
          <h2>{fullName(expert) || "Mülakatçı"}</h2>
        </div>
        <StatusChip>{expert.averageRating ?? "—"} puan</StatusChip>
      </div>
      <p className="muted-copy">{expert.headline || expert.company || "Profil bilgisi bekleniyor."}</p>
      <AnimatedActionButton color="black" fullWidth onClick={loadSlots}>Saatleri göster</AnimatedActionButton>
      {message ? <p className="form-error">{message}</p> : null}
      <SlotPicker expertId={expertUserId} slots={slots} token={token} />
    </PenkrowdCard>
  );
}

function ShopBookingCard({ shop }: { shop: ShopSummary }) {
  return (
    <PenkrowdCard accent="yellow" className="expert-card">
      <div className="section-title row">
        <div className="shop-card-main">
          <span className="profile-avatar image-avatar small-avatar">
            {shop.expertAvatarUrl ? <img src={normalizeMediaUrl(shop.expertAvatarUrl)} alt="" /> : (shop.expertFirstName || "?").slice(0, 1).toUpperCase()}
          </span>
          <div>
          <p className="eyebrow">{shop.industry?.name ?? "Pazar"}</p>
          <h2>{shopExpertName(shop) || "Mülakatçı"}</h2>
          </div>
        </div>
        <RadialStatGauge value={shop.averageRating} max={10} label="Puan" accent="purple" />
      </div>
      <p className="muted-copy">{shop.description || "Açıklama bekleniyor."}</p>
      <div className="shop-meta-row">
        <StatusChip tone={shop.isAvailable ? "cyan" : "yellow"}>{shop.isAvailable ? "Müsait" : "Kısıtlı"}</StatusChip>
        {shop.hourlyRate != null ? <StatusChip tone="white">{shop.hourlyRate} {shop.currency ?? ""}</StatusChip> : null}
      </div>
      <div className="tag-cloud">{shop.skills?.slice(0, 4).map((item) => <StatusChip tone="white" key={item.id}>{item.name}</StatusChip>)}</div>
      <AnimatedActionButton color="black" fullWidth href={`/shop/${shop.id}`}>Dükkanı aç</AnimatedActionButton>
    </PenkrowdCard>
  );
}

function SlotPicker({ expertId, slots, token }: { expertId: string; slots: Slot[]; token: string }) {
  const [message, setMessage] = useState("");
  const [selectedDay, setSelectedDay] = useState("");
  const [selectedSlot, setSelectedSlot] = useState("");

  const slotsByDay = groupSlotsByDay(slots.filter((slot) => !slot.booked));
  const daySlots = selectedDay ? slotsByDay.find(([day]) => day === selectedDay)?.[1] ?? [] : [];

  async function createBooking() {
    setMessage("");
    if (!selectedSlot) {
      setMessage("Önce gün ve saat seç.");
      return;
    }
    try {
      await apiFetch<Booking>("/bookings", {
        method: "POST",
        token,
        body: JSON.stringify({ expertId, slotId: selectedSlot }),
      });
      setMessage("Randevu isteği gönderildi.");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Randevu oluşturulamadı");
    }
  }

  return (
    <div className="slot-picker-panel">
      <div className="slot-step-title"><span>1</span><strong>Gün seç</strong><em>{slotsByDay.reduce((sum, [, items]) => sum + items.length, 0)} seans</em></div>
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
              {formatTimeRange(slot)}
            </button>
          ))}
        </div>
      ) : (
        <p className="muted-copy">Müsait günlerden birini seç.</p>
      )}
      {message ? <p className={message.includes("gönderildi") ? "muted-copy" : "form-error"}>{message}</p> : null}
      <AnimatedActionButton color="cyan" disabled={!selectedSlot} fullWidth onClick={createBooking}>Randevu isteği gönder</AnimatedActionButton>
    </div>
  );
}

function groupSlotsByDay(slots: Slot[]) {
  const grouped = new Map<string, Slot[]>();
  for (const slot of slots) {
    const day = localDayKey(slot.startTime);
    grouped.set(day, [...(grouped.get(day) ?? []), slot].sort((a, b) => new Date(a.startTime).getTime() - new Date(b.startTime).getTime()));
  }
  return [...grouped.entries()].sort(([a], [b]) => a.localeCompare(b));
}

function localDayKey(value: string) {
  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatTimeRange(slot: Slot) {
  const formatter = new Intl.DateTimeFormat("tr-TR", { hour: "2-digit", minute: "2-digit" });
  return `${formatter.format(new Date(slot.startTime))} - ${formatter.format(new Date(slot.endTime))}`;
}

function BookingRow({ booking, role, token, reload }: { booking: Booking; role: "CANDIDATE" | "EXPERT"; token: string; reload?: () => Promise<void> }) {
  const router = useRouter();
  const [now, setNow] = useState(() => Date.now());
  const canJoin = booking.status === "CONFIRMED" && joinWindowAllowed(booking, now);

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  async function post(path: string) {
    await apiFetch<Booking>(path, { method: "POST", token });
    await reload?.();
  }

  async function patchStatus(status: "CANCELLED" | "COMPLETED") {
    await apiFetch<Booking>(`/bookings/${booking.id}/status`, {
      method: "PATCH",
      token,
      body: JSON.stringify({ status }),
    });
    await reload?.();
  }

  async function enter() {
    const session = await apiFetch<{ sessionId: string }>(`/interviews/sessions/booking/${booking.id}`, { token });
    router.push(`/interview/${session.sessionId}?bookingId=${booking.id}&role=${role}`);
  }

  return (
    <article className="penkrowd-row booking-card-row">
      <StatusChip tone={booking.status === "CONFIRMED" ? "cyan" : booking.status === "PENDING" ? "yellow" : "white"}>{booking.status}</StatusChip>
      <div>
        <strong>{formatDateTime(booking.scheduledStart)}</strong>
        <p>{formatDateTime(booking.scheduledEnd)}</p>
        {booking.status === "CONFIRMED" && canJoin ? (
          <span className="join-hint is-open">
            Oda açık
          </span>
        ) : null}
      </div>
      <div className="row-actions">
        {role === "EXPERT" && booking.status === "PENDING" ? (
          <>
            <button className="tone-chip" onClick={() => void post(`/bookings/${booking.id}/approve`)}>Onayla</button>
            <button className="tone-chip danger" onClick={() => void post(`/bookings/${booking.id}/reject`)}>Reddet</button>
          </>
        ) : null}
        {canJoin ? <button className="tone-chip" onClick={() => void enter()}>Mülakata gir</button> : null}
        {role === "CANDIDATE" && booking.status === "PENDING" ? (
          <button className="tone-chip danger" onClick={() => void patchStatus("CANCELLED")}>Talebi iptal et</button>
        ) : null}
        {booking.status === "CONFIRMED" ? (
          <button className="tone-chip danger" onClick={() => void patchStatus("CANCELLED")}>İptal et</button>
        ) : null}
        {role === "EXPERT" && booking.status === "CONFIRMED" ? (
          <button className="tone-chip" onClick={() => void patchStatus("COMPLETED")}>Tamamlandı</button>
        ) : null}
        {booking.status === "COMPLETED" ? <AnimatedActionButton color="white" href={`/interview-result/${booking.id}`}>Sonucu gör</AnimatedActionButton> : null}
      </div>
    </article>
  );
}

function MetricCard({ title, label, accent, children }: { title: string; label: string; accent: "cyan" | "yellow" | "orange" | "purple"; children: React.ReactNode }) {
  return (
    <PenkrowdCard accent={accent} className="analysis-card metric-card">
      <div>
        <p className="eyebrow">{label}</p>
        <h2>{title}</h2>
      </div>
      {children}
    </PenkrowdCard>
  );
}

function average(values: Array<number | null | undefined>) {
  const nums = values.filter((value): value is number => typeof value === "number");
  if (nums.length === 0) return null;
  return nums.reduce((sum, value) => sum + value, 0) / nums.length;
}

function joinWindowAllowed(booking: Booking, now: number) {
  return now >= new Date(booking.scheduledStart).getTime() && now <= new Date(booking.scheduledEnd).getTime();
}
