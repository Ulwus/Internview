"use client";

import { AppPageState, AppShell, useAppSession } from "@/components/app-shell";
import { BookingsPanel } from "@/components/app-panels";

export default function BookingsPage() {
  const state = useAppSession();

  if (state.status === "loading") return <AppPageState message="Randevular yükleniyor" />;
  if (state.status === "error" || !state.session) return <AppPageState message={state.error ?? "Randevular açılamadı"} />;

  return (
    <AppShell active="/bookings" session={state.session} title="Randevular">
      <BookingsPanel session={state.session} />
    </AppShell>
  );
}
