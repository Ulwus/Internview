"use client";

import { AppPageState, AppShell, useAppSession } from "@/components/app-shell";
import { MarketplacePanel } from "@/components/app-panels";

export default function MarketplacePage() {
  const state = useAppSession();

  if (state.status === "loading") return <AppPageState message="Pazar yükleniyor" />;
  if (state.status === "error" || !state.session) return <AppPageState message={state.error ?? "Pazar açılamadı"} />;

  return (
    <AppShell active="/marketplace" session={state.session} title={state.session.role === "EXPERT" ? "Vitrin" : "Pazar"}>
      <MarketplacePanel session={state.session} />
    </AppShell>
  );
}
