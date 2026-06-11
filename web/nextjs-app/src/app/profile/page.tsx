"use client";

import { AppPageState, AppShell, useAppSession } from "@/components/app-shell";
import { ProfilePanel } from "@/components/app-panels";

export default function ProfilePage() {
  const state = useAppSession();

  if (state.status === "loading") return <AppPageState message="Profil yükleniyor" />;
  if (state.status === "error" || !state.session) return <AppPageState message={state.error ?? "Profil açılamadı"} />;

  return (
    <AppShell active="/profile" session={state.session} title="Profil">
      <ProfilePanel session={state.session} />
    </AppShell>
  );
}
