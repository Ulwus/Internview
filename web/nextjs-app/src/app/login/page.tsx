"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { login, storeSession } from "@/lib/api";
import { AnimatedActionButton, PenkrowdCard } from "@/components/penkrowd";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    try {
      const session = await login(email, password);
      storeSession(session);
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Giriş yapılamadı");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="auth-shell">
      <PenkrowdCard accent="cyan" className="auth-card">
        <Link className="brand-block link-reset" href="/">
          <span className="brand-mark">IV</span>
          <div>
            <p className="eyebrow">Internview</p>
            <h1>Giriş yap</h1>
          </div>
        </Link>

        <form className="form-stack" onSubmit={handleSubmit}>
          <label>
            Email
            <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required />
          </label>
          <label>
            Şifre
            <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required />
          </label>
          {error ? <p className="form-error">{error}</p> : null}
          <AnimatedActionButton color="cyan" disabled={submitting} fullWidth>
            {submitting ? "Giriş yapılıyor" : "Giriş yap"}
          </AnimatedActionButton>
        </form>

        <p className="muted-copy">
          Hesabın yoksa <Link href="/register">kayıt ol</Link>.
        </p>
      </PenkrowdCard>
    </main>
  );
}
