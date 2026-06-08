"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Booking,
  DashboardData,
  ExpertSummary,
  Slot,
  apiFetch,
  clearSession,
  formatDateTime,
  fullName,
  loadDashboard,
  readStoredSession,
} from "@/lib/api";
import {
  AnimatedActionButton,
  AnimatedTabBar,
  PenkrowdCard,
  SectionCard,
  StatusChip,
} from "@/components/penkrowd";

export default function DashboardPage() {
  const router = useRouter();
  const [token, setToken] = useState("");
  const [data, setData] = useState<DashboardData | null>(null);
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const [message, setMessage] = useState("");

  const role = useMemo(() => {
    if (!data) return undefined;
    return data.me.roles.includes("EXPERT") ? "EXPERT" : "CANDIDATE";
  }, [data]);

  useEffect(() => {
    const session = readStoredSession();
    if (!session) {
      router.replace("/login");
      return;
    }
    setToken(session.accessToken);
    refresh(session.accessToken);
  }, [router]);

  async function refresh(activeToken = token) {
    setStatus("loading");
    setMessage("");
    try {
      const nextData = await loadDashboard(activeToken);
      setData(nextData);
      setStatus("ready");
    } catch (err) {
      setStatus("error");
      setMessage(err instanceof Error ? err.message : "Panel verileri alınamadı");
    }
  }

  function logout() {
    clearSession();
    router.push("/");
  }

  return (
    <main className="app-shell">
      <aside className="side-rail">
        <Link className="brand-block link-reset" href="/">
          <span className="brand-mark">IV</span>
          <div>
            <p className="eyebrow">Internview</p>
            <h1>{role === "EXPERT" ? "Mülakatçı Paneli" : "Aday Paneli"}</h1>
          </div>
        </Link>

        <nav className="nav-stack" aria-label="Panel menüsü">
          <a className="nav-item is-active" href="#overview">
            <span>●</span>
            Genel
          </a>
          <a className="nav-item" href="#bookings">
            <span>■</span>
            Randevular
          </a>
          <a className="nav-item" href={role === "EXPERT" ? "#availability" : "#experts"}>
            <span>◆</span>
            {role === "EXPERT" ? "Müsaitlik" : "Uzmanlar"}
          </a>
          <button className="nav-item nav-button" onClick={logout}>
            <span>▲</span>
            Çıkış
          </button>
        </nav>

        <section className="neo-card compact-card accent-orange">
          <p className="small-label">Oturum</p>
          <h2>{data ? fullName(data.me) : "Yükleniyor"}</h2>
          <p>{data?.me.email ?? status}</p>
        </section>
      </aside>

      <section className="workspace">
        <header className="top-bar">
          <AnimatedTabBar tabs={[role === "EXPERT" ? "Mülakatçı" : "Aday", "Backend", status]} />
          <div className="top-actions">
            <button className="icon-button" onClick={() => refresh()} aria-label="Yenile">
              ↻
            </button>
            <AnimatedActionButton color="cyan" href={role === "EXPERT" ? "#availability" : "#experts"}>
              {role === "EXPERT" ? "Slot ekle" : "Uzman bul"}
            </AnimatedActionButton>
          </div>
        </header>

        {message ? <p className="form-error">{message}</p> : null}
        {!data ? <LoadingPanel /> : role === "EXPERT" ? <ExpertDashboard data={data} token={token} refresh={refresh} /> : <CandidateDashboard data={data} token={token} refresh={refresh} />}
      </section>
    </main>
  );
}

function LoadingPanel() {
  return (
    <PenkrowdCard>
      <p className="eyebrow">Backend</p>
      <h2>Panel verileri yükleniyor</h2>
    </PenkrowdCard>
  );
}

function CandidateDashboard({ data, token, refresh }: { data: DashboardData; token: string; refresh: () => Promise<void> }) {
  const bookings = data.bookings?.items ?? [];
  const experts = data.experts?.items ?? [];

  return (
    <>
      <section className="hero-grid" id="overview">
        <SummaryCard title="Aktif randevu" value={bookings.length} label="/bookings/me/candidate" accent="cyan" />
        <SummaryCard title="Uygun uzman" value={data.experts?.totalElements ?? 0} label="/experts?is_available=true" accent="yellow" />
      </section>

      <section className="content-grid">
        <SectionCard
          action={<StatusChip>{experts.length}</StatusChip>}
          className="transcript-panel"
          id="experts"
          subtitle="Backend /experts"
          title="Uzman seç"
        >
          <div className="expert-list">
            {experts.map((expert) => (
              <CandidateExpertCard expert={expert} token={token} refresh={refresh} key={expert.id} />
            ))}
            {experts.length === 0 ? <p className="muted-copy">Backend uygun uzman döndürmedi.</p> : null}
          </div>
        </SectionCard>

        <BookingsPanel bookings={bookings} token={token} role="CANDIDATE" refresh={refresh} />
      </section>
    </>
  );
}

function ExpertDashboard({ data, token, refresh }: { data: DashboardData; token: string; refresh: () => Promise<void> }) {
  const bookings = data.bookings?.items ?? [];
  const availability = data.availability ?? [];
  return (
    <>
      <section className="hero-grid" id="overview">
        <SummaryCard title="Randevu" value={bookings.length} label="/bookings/me/expert" accent="cyan" />
        <SummaryCard title="Slot" value={availability.length} label="/experts/me/availability" accent="yellow" />
      </section>

      <section className="content-grid">
        <BookingsPanel bookings={bookings} token={token} role="EXPERT" refresh={refresh} />
        <section className="right-stack">
          <ExpertProfileCard data={data} token={token} refresh={refresh} />
          <AvailabilityPanel slots={availability} token={token} refresh={refresh} />
        </section>
      </section>
    </>
  );
}

function SummaryCard({ title, value, label, accent }: { title: string; value: number; label: string; accent: "cyan" | "yellow" }) {
  return (
    <PenkrowdCard accent={accent} className="analysis-card">
      <p className="eyebrow">{label}</p>
      <h2>{title}</h2>
      <div className={`metric-circle ${accent}`}>
        <strong>{value}</strong>
      </div>
    </PenkrowdCard>
  );
}

function CandidateExpertCard({ expert, token, refresh }: { expert: ExpertSummary; token: string; refresh: () => Promise<void> }) {
  const [slots, setSlots] = useState<Slot[]>([]);
  const [loadingSlots, setLoadingSlots] = useState(false);
  const [message, setMessage] = useState("");

  async function loadSlots() {
    setLoadingSlots(true);
    setMessage("");
    try {
      setSlots(await apiFetch<Slot[]>(`/availability/${expert.id}`));
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Slotlar alınamadı");
    } finally {
      setLoadingSlots(false);
    }
  }

  async function createBooking(slotId: string) {
    setMessage("");
    try {
      await apiFetch<Booking>("/bookings", {
        method: "POST",
        token,
        body: JSON.stringify({ expertId: expert.id, slotId }),
      });
      await refresh();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Booking oluşturulamadı");
    }
  }

  return (
    <PenkrowdCard accent="cyan" className="expert-card">
      <div className="section-title row">
        <div>
          <p className="eyebrow">{expert.industry?.name ?? "Uzman"}</p>
          <h2>{fullName(expert)}</h2>
        </div>
        <StatusChip>{expert.averageRating ?? "—"} puan</StatusChip>
      </div>
      <p className="muted-copy">{expert.headline || expert.company || "Backend profil bilgisi bekleniyor."}</p>
      <AnimatedActionButton color="black" fullWidth onClick={loadSlots}>
        {loadingSlots ? "Slotlar alınıyor" : "Uygun saatleri getir"}
      </AnimatedActionButton>
      {message ? <p className="form-error">{message}</p> : null}
      {slots.length > 0 ? (
        <div className="file-list">
          {slots.map((slot) => (
            <button className="slot-button" key={slot.id} onClick={() => createBooking(slot.id)}>
              {formatDateTime(slot.startTime)} - {formatDateTime(slot.endTime)}
            </button>
          ))}
        </div>
      ) : null}
    </PenkrowdCard>
  );
}

function BookingsPanel({
  bookings,
  token,
  role,
  refresh,
}: {
  bookings: Booking[];
  token: string;
  role: "CANDIDATE" | "EXPERT";
  refresh: () => Promise<void>;
}) {
  async function postAction(path: string) {
    await apiFetch<Booking>(path, { method: "POST", token });
    await refresh();
  }

  async function openSession(bookingId: string) {
    const session = await apiFetch<{ sessionId: string }>(`/interviews/sessions/booking/${bookingId}`, { token });
    window.location.href = `/dashboard#session-${session.sessionId}`;
  }

  return (
    <SectionCard
      action={<StatusChip>{bookings.length}</StatusChip>}
      className="transcript-panel"
      id="bookings"
      subtitle="Backend /bookings"
      title="Randevular"
    >
      <div className="segment-list">
        {bookings.map((booking) => (
          <article className="penkrowd-row" key={booking.id}>
            <StatusChip tone="cyan">{booking.status}</StatusChip>
            <div>
              <strong>{formatDateTime(booking.scheduledStart)}</strong>
              <p>{booking.id}</p>
            </div>
            <div className="row-actions">
              <button className="tone-chip" onClick={() => openSession(booking.id)}>
                Oturum
              </button>
              {role === "EXPERT" && booking.status === "PENDING" ? (
                <>
                  <button className="tone-chip" onClick={() => postAction(`/bookings/${booking.id}/approve`)}>
                    Onayla
                  </button>
                  <button className="tone-chip danger" onClick={() => postAction(`/bookings/${booking.id}/reject`)}>
                    Reddet
                  </button>
                </>
              ) : null}
            </div>
          </article>
        ))}
        {bookings.length === 0 ? <p className="muted-copy">Backend randevu döndürmedi.</p> : null}
      </div>
    </SectionCard>
  );
}

function ExpertProfileCard({ data, token, refresh }: { data: DashboardData; token: string; refresh: () => Promise<void> }) {
  const profile = data.ownExpertProfile;
  const [headline, setHeadline] = useState(profile?.headline ?? "");
  const [company, setCompany] = useState(profile?.company ?? "");
  const [yearsOfExperience, setYearsOfExperience] = useState(String(profile?.yearsOfExperience ?? ""));
  const [hourlyRate, setHourlyRate] = useState(String(profile?.hourlyRate ?? ""));
  const [currency, setCurrency] = useState(profile?.currency ?? "TRY");
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    try {
      await apiFetch("/experts/me", {
        method: "PUT",
        token,
        body: JSON.stringify({
          headline,
          company,
          yearsOfExperience: yearsOfExperience ? Number(yearsOfExperience) : null,
          hourlyRate: hourlyRate ? Number(hourlyRate) : null,
          currency,
          isAvailable: true,
        }),
      });
      await refresh();
      setMessage("Profil güncellendi.");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Profil güncellenemedi");
    }
  }

  return (
    <SectionCard id="profile" subtitle="Backend /experts/me" title="Uzman profili">
      <form className="form-stack compact-form" onSubmit={submit}>
        <label>
          Başlık
          <input value={headline} onChange={(event) => setHeadline(event.target.value)} />
        </label>
        <label>
          Şirket
          <input value={company} onChange={(event) => setCompany(event.target.value)} />
        </label>
        <div className="form-grid">
          <label>
            Yıl
            <input value={yearsOfExperience} onChange={(event) => setYearsOfExperience(event.target.value)} type="number" min="0" />
          </label>
          <label>
            Ücret
            <input value={hourlyRate} onChange={(event) => setHourlyRate(event.target.value)} type="number" min="0" />
          </label>
        </div>
        <label>
          Para birimi
          <input value={currency} onChange={(event) => setCurrency(event.target.value.toUpperCase())} maxLength={3} />
        </label>
        {message ? <p className={message.includes("güncellendi") ? "muted-copy" : "form-error"}>{message}</p> : null}
        <AnimatedActionButton color="yellow" fullWidth>
          Profili kaydet
        </AnimatedActionButton>
      </form>
    </SectionCard>
  );
}

function AvailabilityPanel({ slots, token, refresh }: { slots: Slot[]; token: string; refresh: () => Promise<void> }) {
  const [startTime, setStartTime] = useState("");
  const [endTime, setEndTime] = useState("");
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    try {
      await apiFetch<Slot>("/experts/me/availability", {
        method: "POST",
        token,
        body: JSON.stringify({
          startTime: new Date(startTime).toISOString(),
          endTime: new Date(endTime).toISOString(),
        }),
      });
      setStartTime("");
      setEndTime("");
      await refresh();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Slot oluşturulamadı");
    }
  }

  return (
    <SectionCard
      action={<StatusChip>{slots.length}</StatusChip>}
      id="availability"
      subtitle="Backend /experts/me/availability"
      title="Müsaitlik"
    >
      <form className="form-stack compact-form" onSubmit={submit}>
        <label>
          Başlangıç
          <input value={startTime} onChange={(event) => setStartTime(event.target.value)} type="datetime-local" required />
        </label>
        <label>
          Bitiş
          <input value={endTime} onChange={(event) => setEndTime(event.target.value)} type="datetime-local" required />
        </label>
        {message ? <p className="form-error">{message}</p> : null}
        <AnimatedActionButton color="cyan" fullWidth>
          Slot ekle
        </AnimatedActionButton>
      </form>
      <div className="file-list">
        {slots.map((slot) => (
          <span key={slot.id}>{formatDateTime(slot.startTime)} - {formatDateTime(slot.endTime)}</span>
        ))}
      </div>
    </SectionCard>
  );
}
