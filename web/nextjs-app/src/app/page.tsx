"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ExpertSummary, Industry, fullName, loadLandingData } from "@/lib/api";
import { AnimatedActionButton, DetailHeaderCard, PenkrowdCard, SectionCard, StatusChip } from "@/components/penkrowd";

export default function LandingPage() {
  const [experts, setExperts] = useState<ExpertSummary[]>([]);
  const [industries, setIndustries] = useState<Industry[]>([]);
  const [totalExperts, setTotalExperts] = useState(0);
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const [error, setError] = useState("");

  useEffect(() => {
    loadLandingData()
      .then((data) => {
        setExperts(data.experts.items);
        setIndustries(data.industries);
        setTotalExperts(data.experts.totalElements);
        setStatus("ready");
      })
      .catch((err: Error) => {
        setStatus("error");
        setError(err.message);
      });
  }, []);

  return (
    <main className="landing-shell">
      <header className="landing-nav">
        <Link className="brand-block link-reset" href="/">
          <span className="brand-mark">IV</span>
          <div>
            <p className="eyebrow">Internview</p>
            <h1>Canlı mülakat, kayıt, analiz</h1>
          </div>
        </Link>
        <div className="top-actions">
          <AnimatedActionButton href="/login" color="white">
            Giriş yap
          </AnimatedActionButton>
          <AnimatedActionButton href="/register" color="cyan">
            Kayıt ol
          </AnimatedActionButton>
        </div>
      </header>

      <section className="landing-hero">
        <div className="hero-copy">
          <p className="eyebrow">Web, mobil ve sunucu taraflı kayıt</p>
          <h2>Mülakatı yürüt. Kaydı al. Konuşmayı rapora çevir.</h2>
          <p>
            Adaylar uygun uzmanları seçer, mülakatçılar müsaitliklerini yönetir. Görüşme verileri,
            booking ve analiz akışı Internview servislerinden gelir.
          </p>
          <div className="top-actions hero-actions">
            <AnimatedActionButton href="/register" color="cyan">
              Hemen başla
            </AnimatedActionButton>
            <AnimatedActionButton href="/login" color="yellow">
              Panelime git
            </AnimatedActionButton>
          </div>
        </div>

        <PenkrowdCard accent="cyan" className="landing-live-card">
          <div className="section-title row">
            <div>
              <p className="eyebrow">Backend durumu</p>
              <h2>{status === "loading" ? "Veriler alınıyor" : status === "ready" ? "Servis verisi" : "Bağlantı gerekli"}</h2>
            </div>
            <StatusChip tone={status === "ready" ? "cyan" : status === "error" ? "red" : "white"}>
              {status === "loading" ? "yükleniyor" : status === "ready" ? "hazır" : "hata"}
            </StatusChip>
          </div>

          {status === "error" ? (
            <p className="muted-copy">{error}</p>
          ) : (
            <div className="landing-stats">
              <div>
                <strong>{status === "ready" ? totalExperts : "..."}</strong>
                <span>uygun uzman</span>
              </div>
              <div>
                <strong>{status === "ready" ? industries.length : "..."}</strong>
                <span>sektör</span>
              </div>
            </div>
          )}
        </PenkrowdCard>
      </section>

      <section className="landing-data-grid">
        <SectionCard title="Uygun uzmanlar" subtitle="/marketplace" action={<StatusChip>{experts.length}</StatusChip>}>
          <div className="expert-list">
            {experts.map((expert) => (
              <DetailHeaderCard
                accent="cyan"
                fallbackLetter={fullName(expert).charAt(0) || "U"}
                key={expert.id}
                subtitle={expert.headline || expert.company || expert.industry?.name || "Profil bilgisi bekleniyor"}
                title={fullName(expert)}
              />
            ))}
            {status === "ready" && experts.length === 0 ? <p className="muted-copy">Backend uygun uzman döndürmedi.</p> : null}
          </div>
        </SectionCard>

        <SectionCard title="Sektörler" subtitle="/industries">
          <div className="tag-cloud">
            {industries.map((industry) => (
              <StatusChip tone="cyan" key={industry.id}>
                {industry.name}
              </StatusChip>
            ))}
            {status === "ready" && industries.length === 0 ? <p className="muted-copy">Backend sektör döndürmedi.</p> : null}
          </div>
        </SectionCard>
      </section>
    </main>
  );
}
