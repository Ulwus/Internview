"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Role, register, storeSession } from "@/lib/api";
import { AnimatedActionButton, PenkrowdCard } from "@/components/penkrowd";

export default function RegisterPage() {
  const router = useRouter();
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<Role>("CANDIDATE");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    try {
      const session = await register({ firstName, lastName, email, password, role });
      storeSession(session);
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Kayıt oluşturulamadı");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="auth-shell">
      <PenkrowdCard accent="yellow" className="auth-card">
        <Link className="brand-block link-reset" href="/">
          <span className="brand-mark">IV</span>
          <div>
            <p className="eyebrow">Internview</p>
            <h1>Kayıt ol</h1>
          </div>
        </Link>

        <form className="form-stack" onSubmit={handleSubmit}>
          <div className="form-grid">
            <label>
              Ad
              <input value={firstName} onChange={(event) => setFirstName(event.target.value)} required />
            </label>
            <label>
              Soyad
              <input value={lastName} onChange={(event) => setLastName(event.target.value)} required />
            </label>
          </div>
          <label>
            Email
            <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required />
          </label>
          <label>
            Şifre
            <input
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              type="password"
              minLength={8}
              required
            />
          </label>
          <div className="role-picker" role="radiogroup" aria-label="Rol seçimi">
            <button
              className={role === "CANDIDATE" ? "is-selected" : ""}
              type="button"
              onClick={() => setRole("CANDIDATE")}
            >
              Aday
            </button>
            <button
              className={role === "EXPERT" ? "is-selected" : ""}
              type="button"
              onClick={() => setRole("EXPERT")}
            >
              Mülakatçı
            </button>
          </div>
          {error ? <p className="form-error">{error}</p> : null}
          <AnimatedActionButton color="yellow" disabled={submitting} fullWidth>
            {submitting ? "Kayıt oluşturuluyor" : "Kayıt ol"}
          </AnimatedActionButton>
        </form>

        <p className="muted-copy">
          Hesabın varsa <Link href="/login">giriş yap</Link>.
        </p>
      </PenkrowdCard>
    </main>
  );
}
