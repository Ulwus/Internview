"use client";

import { AppPageState, AppShell, useAppSession } from "@/components/app-shell";
import { OverviewPanel } from "@/components/app-panels";

export default function DashboardPage() {
  const state = useAppSession();

  if (state.status === "loading") return <AppPageState message="Panel yükleniyor" />;
  if (state.status === "error" || !state.session) return <AppPageState message={state.error ?? "Panel açılamadı"} />;

  return (
    <AppShell active="/dashboard" session={state.session} title="Genel">
      <OverviewPanel session={state.session} />
    </AppShell>
  );
}
