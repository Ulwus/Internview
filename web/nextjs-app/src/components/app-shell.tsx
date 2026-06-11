"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useCallback, useEffect, useState } from "react";
import { Me, apiFetch, clearSession, fullName, readStoredSession } from "@/lib/api";

export type AppRole = "CANDIDATE" | "EXPERT";

export type AppSession = {
  token: string;
  me: Me;
  role: AppRole;
};

const navItems = [
  { href: "/dashboard", label: "Genel" },
  { href: "/bookings", label: "Randevular" },
  { href: "/marketplace", label: "Pazar" },
  { href: "/profile", label: "Profil" },
];

export function useAppSession() {
  const router = useRouter();
  const [state, setState] = useState<{ status: "loading" | "ready" | "error"; session?: AppSession; error?: string }>({
    status: "loading",
  });

  const load = useCallback(async () => {
    const stored = readStoredSession();
    if (!stored) {
      router.replace("/login");
      return;
    }
    try {
      const me = await apiFetch<Me>("/auth/me", { token: stored.accessToken });
      setState({
        status: "ready",
        session: {
          token: stored.accessToken,
          me,
          role: me.roles.includes("EXPERT") ? "EXPERT" : "CANDIDATE",
        },
      });
    } catch (err) {
      setState({ status: "error", error: err instanceof Error ? err.message : "Oturum alınamadı" });
    }
  }, [router]);

  useEffect(() => {
    void Promise.resolve().then(load);
  }, [load]);

  return { ...state, reload: load };
}

export function AppShell({
  session,
  active,
  title,
  children,
}: {
  session: AppSession;
  active: string;
  title: string;
  children: ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();

  function logout() {
    clearSession();
    router.push("/");
  }

  return (
    <main className="app-shell">
      <aside className="side-rail">
        <Link className="brand-block link-reset" href="/dashboard">
          <span className="brand-mark">IV</span>
          <div>
            <p className="eyebrow">Internview</p>
            <h1>{session.role === "EXPERT" ? "Mülakatçı" : "Aday"}</h1>
          </div>
        </Link>

        <nav className="nav-stack" aria-label="Panel menüsü">
          {navItems.map((item) => (
            <Link
              className={`nav-item route-tab ${active === item.href || pathname === item.href ? "is-active" : ""}`}
              href={item.href}
              key={item.href}
            >
              {item.label}
            </Link>
          ))}
          <button className="nav-item nav-button route-tab" onClick={logout}>
            Çıkış
          </button>
        </nav>

        <section className="neo-card compact-card accent-orange">
          <p className="small-label">{session.role === "EXPERT" ? "Mülakatçı hesabı" : "Aday hesabı"}</p>
          <h2>{fullName(session.me) || session.me.email}</h2>
          <p>{session.me.email}</p>
        </section>
      </aside>

      <section className="workspace page-workspace">
        <header className="page-title-bar">
          <div>
            <p className="eyebrow">{session.role === "EXPERT" ? "Mülakatçı Paneli" : "Aday Paneli"}</p>
            <h1>{title}</h1>
          </div>
        </header>
        {children}
      </section>
    </main>
  );
}

export function AppPageState({ message }: { message: string }) {
  return (
    <main className="auth-shell">
      <section className="pk-card state-card">
        <p className="eyebrow">Internview</p>
        <h1>{message}</h1>
      </section>
    </main>
  );
}
