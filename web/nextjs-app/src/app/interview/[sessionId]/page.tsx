"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Device } from "mediasoup-client";
import { AnimatedActionButton, AnimatedTabBar, PenkrowdCard, SectionCard, StatusChip } from "@/components/penkrowd";
import { Booking, apiFetch, clearSession, readStoredSession } from "@/lib/api";

type TransportInfo = {
  id: string;
  iceParameters: Record<string, unknown>;
  iceCandidates: unknown[];
  dtlsParameters: Record<string, unknown>;
};

type ProducerSummary = {
  id: string;
  kind: "audio" | "video" | string;
};

type ConsumeInfo = {
  id: string;
  producerId: string;
  kind: "audio" | "video" | string;
  rtpParameters: Record<string, unknown>;
};

type RemoteTrack = {
  id: string;
  kind: string;
  stream: MediaStream;
};

type SignalPayload = {
  type?: string;
  message?: string;
  userId?: string;
  fromUserId?: string;
  peers?: Array<{ userId?: string; role?: string }>;
};

type TransportEventCallback = (...args: never[]) => void;

type MediaTransport = {
  id: string;
  close?: () => void;
  on: (event: string, callback: TransportEventCallback) => void;
  produce?: (options: { track: MediaStreamTrack }) => Promise<{ id: string; close?: () => void }>;
  consume?: (options: {
    id: string;
    producerId: string;
    kind: string;
    rtpParameters: Record<string, unknown>;
  }) => Promise<{ id: string; track: MediaStreamTrack; close?: () => void }>;
};

export default function InterviewRoomPage() {
  const router = useRouter();
  const params = useParams<{ sessionId: string }>();
  const searchParams = useSearchParams();
  const sessionId = params.sessionId;
  const bookingId = searchParams.get("bookingId") ?? "";
  const role = searchParams.get("role") ?? "";

  const [token] = useState(() => readStoredSession()?.accessToken ?? "");
  const [status, setStatus] = useState("Hazırlanıyor");
  const [message, setMessage] = useState("");
  const [remoteTracks, setRemoteTracks] = useState<RemoteTrack[]>([]);
  const [micEnabled, setMicEnabled] = useState(true);
  const [cameraEnabled, setCameraEnabled] = useState(true);
  const [joined, setJoined] = useState(false);
  const [finishRequested, setFinishRequested] = useState(false);
  const [incomingFinishFrom, setIncomingFinishFrom] = useState("");

  const localVideoRef = useRef<HTMLVideoElement | null>(null);
  const localStreamRef = useRef<MediaStream | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const deviceRef = useRef<Device | null>(null);
  const sendTransportRef = useRef<MediaTransport | null>(null);
  const recvTransportRef = useRef<MediaTransport | null>(null);
  const producedIdsRef = useRef<Set<string>>(new Set());
  const consumedIdsRef = useRef<Set<string>>(new Set());
  const consumingIdsRef = useRef<Set<string>>(new Set());
  const remoteUserIdRef = useRef("");
  const syncTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const syncProducers = useCallback(async () => {
    const device = deviceRef.current;
    const recvTransport = recvTransportRef.current;
    if (!device || !recvTransport?.consume || !token) return;

    const response = await apiFetch<{ producers: ProducerSummary[] }>(`/interviews/sessions/${sessionId}/media/producers`, { token });
    for (const producer of response.producers ?? []) {
      if (
        producedIdsRef.current.has(producer.id) ||
        consumedIdsRef.current.has(producer.id) ||
        consumingIdsRef.current.has(producer.id)
      ) {
        continue;
      }
      consumingIdsRef.current.add(producer.id);
      try {
        const consumeInfo = await apiFetch<ConsumeInfo>(`/interviews/sessions/${sessionId}/media/transport/${recvTransport.id}/consume`, {
          method: "POST",
          token,
          body: JSON.stringify({
            producerId: producer.id,
            rtpCapabilities: device.rtpCapabilities,
          }),
        });
        const consumer = await recvTransport.consume({
          id: consumeInfo.id,
          producerId: consumeInfo.producerId,
          kind: consumeInfo.kind,
          rtpParameters: consumeInfo.rtpParameters,
        });
        consumedIdsRef.current.add(producer.id);
        await apiFetch(`/interviews/sessions/${sessionId}/media/consumer/${consumer.id}/resume`, { method: "POST", token });
        setRemoteTracks((current) => [...current, { id: consumer.id, kind: consumeInfo.kind, stream: new MediaStream([consumer.track]) }]);
      } finally {
        consumingIdsRef.current.delete(producer.id);
      }
    }
  }, [sessionId, token]);

  const openSignalingSocket = useCallback((activeSessionId: string, activeToken: string) => {
    const wsBase = `${window.location.protocol === "https:" ? "wss" : "ws"}://${window.location.hostname}:8080/ws/signaling/${activeSessionId}`;
    const socket = new WebSocket(`${wsBase}?token=${encodeURIComponent(activeToken)}`);
    wsRef.current = socket;
    socket.onopen = () => setStatus("Signaling bağlı");
    socket.onmessage = async (event) => {
      try {
        const payload = JSON.parse(event.data as string) as SignalPayload;
        if (payload.type === "ROOM_JOINED") {
          const remotePeer = payload.peers?.find((peer) => peer.userId);
          if (remotePeer?.userId) remoteUserIdRef.current = remotePeer.userId;
          await syncProducers();
          setStatus(remotePeer?.userId ? "Mülakattasın" : "Karşı taraf bekleniyor");
        }
        if (payload.type === "PEER_JOINED") {
          if (payload.userId) remoteUserIdRef.current = payload.userId;
          await syncProducers();
          setStatus("Mülakattasın");
        }
        if (payload.type === "PEER_LEFT") setStatus("Karşı taraf ayrıldı");
        if (payload.type === "FINISH_REQUEST" && role !== "EXPERT") {
          setIncomingFinishFrom(payload.fromUserId ?? remoteUserIdRef.current);
        }
        if (payload.type === "FINISH_ACCEPT" && role === "EXPERT") {
          const targetUserId = remoteUserIdRef.current;
          if (!targetUserId) {
            setMessage("Karşı taraf bulunamadı, mülakat bitirilemedi.");
            return;
          }
          wsRef.current?.send(JSON.stringify({ type: "FINISH_DONE", targetUserId }));
          router.push(bookingId ? `/interview-result/${bookingId}` : "/dashboard");
        }
        if (payload.type === "FINISH_REJECT" && role === "EXPERT") {
          setFinishRequested(false);
          setMessage("Aday bitirme isteğini reddetti.");
        }
        if (payload.type === "FINISH_DONE" && role !== "EXPERT") {
          router.push(bookingId ? `/interview-result/${bookingId}` : "/dashboard");
        }
        if (payload.type === "ERROR") setMessage(payload.message ?? "Signaling hatası");
      } catch {
        setMessage("Signaling mesajı çözümlenemedi");
      }
    };
    socket.onerror = () => setMessage("Signaling bağlantısı hata verdi");
  }, [bookingId, role, router, syncProducers]);

  useEffect(() => {
    const session = readStoredSession();
    if (!session) {
      router.replace("/login");
      return;
    }
  }, [router]);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    async function joinRoom() {
      try {
        if (bookingId) {
          const booking = await apiFetch<Booking>(`/bookings/${bookingId}`, { token });
          const now = Date.now();
          const start = new Date(booking.scheduledStart).getTime();
          const end = new Date(booking.scheduledEnd).getTime();
          if (booking.status !== "CONFIRMED") {
            setStatus("Oturum kapalı");
            setMessage("Mülakat sadece onaylı randevuda açılır.");
            return;
          }
          if (now < start || now > end) {
            setStatus("Zamanı değil");
            setMessage("Mülakat zamanı dışında odaya girilemez.");
            return;
          }
        }

        setStatus("Kamera hazırlanıyor");
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });
        if (cancelled) return;
        localStreamRef.current = stream;
        if (localVideoRef.current) localVideoRef.current.srcObject = stream;

        setStatus("SFU bağlanıyor");
        const capabilities = await apiFetch<{ rtpCapabilities: Record<string, unknown> }>(
          `/interviews/sessions/${sessionId}/media/capabilities`,
          { token },
        );
        const device = new Device();
        await device.load({ routerRtpCapabilities: capabilities.rtpCapabilities });
        deviceRef.current = device;

        const sendTransportInfo = await createTransport(sessionId, token);
        const sendTransport = device.createSendTransport(sendTransportInfo as Parameters<Device["createSendTransport"]>[0]) as unknown as MediaTransport;
        wireSendTransport(sendTransport, sessionId, token);
        sendTransportRef.current = sendTransport;

        for (const track of stream.getTracks()) {
          if (!sendTransport.produce) continue;
          const producer = await sendTransport.produce({ track });
          producedIdsRef.current.add(producer.id);
        }

        const recvTransportInfo = await createTransport(sessionId, token);
        const recvTransport = device.createRecvTransport(recvTransportInfo as Parameters<Device["createRecvTransport"]>[0]) as unknown as MediaTransport;
        wireRecvTransport(recvTransport, sessionId, token);
        recvTransportRef.current = recvTransport;

        openSignalingSocket(sessionId, token);
        setJoined(true);
        setStatus("Mülakattasın");
        await syncProducers();
        syncTimerRef.current = setInterval(() => {
          syncProducers().catch((err) => {
            setMessage(err instanceof Error ? err.message : "Akış yenilenemedi");
          });
        }, 1500);
      } catch (err) {
        setStatus("Bağlantı hatası");
        setMessage(err instanceof Error ? err.message : "Mülakat odasına girilemedi");
      }
    }

    joinRoom();

    return () => {
      cancelled = true;
      wsRef.current?.send(JSON.stringify({ type: "LEAVE_ROOM" }));
      wsRef.current?.close();
      if (syncTimerRef.current) {
        clearInterval(syncTimerRef.current);
        syncTimerRef.current = null;
      }
      sendTransportRef.current?.close?.();
      recvTransportRef.current?.close?.();
      localStreamRef.current?.getTracks().forEach((track) => track.stop());
    };
  }, [bookingId, openSignalingSocket, sessionId, syncProducers, token]);

  function toggleMic() {
    const next = !micEnabled;
    localStreamRef.current?.getAudioTracks().forEach((track) => {
      track.enabled = next;
    });
    setMicEnabled(next);
  }

  function toggleCamera() {
    const next = !cameraEnabled;
    localStreamRef.current?.getVideoTracks().forEach((track) => {
      track.enabled = next;
    });
    setCameraEnabled(next);
  }

  async function finishInterview() {
    setMessage("");
    const targetUserId = remoteUserIdRef.current;
    if (role !== "EXPERT") {
      setMessage("Mülakatı bitirme isteğini mülakatçı başlatır.");
      return;
    }
    if (!targetUserId) {
      setMessage("Karşı taraf bağlanmadan bitirme isteği gönderilemez.");
      return;
    }
    try {
      wsRef.current?.send(JSON.stringify({ type: "FINISH_REQUEST", targetUserId }));
      setFinishRequested(true);
      setStatus("Bitirme onayı bekleniyor");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Bitirme isteği gönderilemedi");
    }
  }

  function answerFinish(accepted: boolean) {
    const targetUserId = incomingFinishFrom || remoteUserIdRef.current;
    if (!targetUserId) {
      setMessage("Bitirme isteğinin göndereni bulunamadı.");
      return;
    }
    try {
      wsRef.current?.send(JSON.stringify({ type: accepted ? "FINISH_ACCEPT" : "FINISH_REJECT", targetUserId }));
      setIncomingFinishFrom("");
      if (accepted) {
        setStatus("Mülakat kapatılıyor");
      } else {
        setMessage("Bitirme isteği reddedildi.");
      }
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Yanıt gönderilemedi");
    }
  }

  function logout() {
    clearSession();
    router.push("/");
  }

  return (
    <main className="interview-shell">
      <header className="top-bar interview-top">
        <Link className="brand-block link-reset" href="/dashboard">
          <span className="brand-mark">IV</span>
          <div>
            <p className="eyebrow">Internview</p>
            <h1>Web mülakat</h1>
          </div>
        </Link>
        <AnimatedTabBar tabs={[joined ? "Bağlı" : "Hazır", role || "Katılımcı", status]} />
        <button className="icon-button" onClick={logout} aria-label="Çıkış">×</button>
      </header>

      {message ? <p className="form-error interview-message">{message}</p> : null}
      {incomingFinishFrom ? (
        <PenkrowdCard accent="yellow" className="finish-request-card">
          <div>
            <p className="eyebrow">Bitirme isteği</p>
            <h2>Mülakatçı oturumu bitirmek istiyor</h2>
            <p className="muted-copy">Onaylarsan kayıt duracak, oda kapanacak ve analiz kuyruğu çalışmaya devam edecek.</p>
          </div>
          <div className="control-row">
            <AnimatedActionButton color="white" onClick={() => answerFinish(false)}>Reddet</AnimatedActionButton>
            <AnimatedActionButton color="cyan" onClick={() => answerFinish(true)}>Onayla</AnimatedActionButton>
          </div>
        </PenkrowdCard>
      ) : null}

      <section className="video-grid">
        <PenkrowdCard accent="cyan" className="video-card">
          <div className="video-label"><StatusChip tone="cyan">Sen</StatusChip></div>
          <video ref={localVideoRef} autoPlay muted playsInline />
        </PenkrowdCard>
        <PenkrowdCard accent="yellow" className="video-card">
          <div className="video-label"><StatusChip tone="yellow">Karşı taraf</StatusChip></div>
          {remoteTracks.find((track) => track.kind === "video") ? (
            remoteTracks
              .filter((track) => track.kind === "video")
              .map((track) => <RemoteVideo stream={track.stream} key={track.id} />)
          ) : (
            <div className="empty-video">Bekleniyor</div>
          )}
          {remoteTracks
            .filter((track) => track.kind === "audio")
            .map((track) => <RemoteAudio stream={track.stream} key={track.id} />)}
        </PenkrowdCard>
      </section>

      <SectionCard className="control-panel" title="Kontroller" subtitle={`/sessions/${sessionId}/media`}>
        <div className="control-row">
          <AnimatedActionButton color={micEnabled ? "cyan" : "red"} onClick={toggleMic}>{micEnabled ? "Mikrofon açık" : "Mikrofon kapalı"}</AnimatedActionButton>
          <AnimatedActionButton color={cameraEnabled ? "yellow" : "red"} onClick={toggleCamera}>{cameraEnabled ? "Kamera açık" : "Kamera kapalı"}</AnimatedActionButton>
          <AnimatedActionButton color="orange" onClick={syncProducers}>Akışı yenile</AnimatedActionButton>
          <AnimatedActionButton color={finishRequested ? "white" : "red"} disabled={finishRequested} onClick={finishInterview}>
            {finishRequested ? "Onay bekleniyor" : "Mülakatı bitir"}
          </AnimatedActionButton>
        </div>
      </SectionCard>
    </main>
  );
}

async function createTransport(sessionId: string, token: string) {
  return apiFetch<TransportInfo>(`/interviews/sessions/${sessionId}/media/transport`, {
    method: "POST",
    token,
    body: JSON.stringify({ announcedIp: window.location.hostname }),
  });
}

function wireSendTransport(transport: MediaTransport, sessionId: string, token: string) {
  transport.on("connect", async ({ dtlsParameters }: { dtlsParameters: Record<string, unknown> }, callback: () => void, errback: (err: Error) => void) => {
    try {
      await apiFetch(`/interviews/sessions/${sessionId}/media/transport/${transport.id}/connect`, {
        method: "POST",
        token,
        body: JSON.stringify({ dtlsParameters }),
      });
      callback();
    } catch (err) {
      errback(err instanceof Error ? err : new Error("Transport bağlanamadı"));
    }
  });

  transport.on("produce", async ({ kind, rtpParameters }: { kind: string; rtpParameters: Record<string, unknown> }, callback: (value: { id: string }) => void, errback: (err: Error) => void) => {
    try {
      const response = await apiFetch<{ id: string }>(`/interviews/sessions/${sessionId}/media/transport/${transport.id}/produce`, {
        method: "POST",
        token,
        body: JSON.stringify({ kind, rtpParameters }),
      });
      callback({ id: response.id });
    } catch (err) {
      errback(err instanceof Error ? err : new Error("Producer oluşturulamadı"));
    }
  });
}

function wireRecvTransport(transport: MediaTransport, sessionId: string, token: string) {
  transport.on("connect", async ({ dtlsParameters }: { dtlsParameters: Record<string, unknown> }, callback: () => void, errback: (err: Error) => void) => {
    try {
      await apiFetch(`/interviews/sessions/${sessionId}/media/transport/${transport.id}/connect`, {
        method: "POST",
        token,
        body: JSON.stringify({ dtlsParameters }),
      });
      callback();
    } catch (err) {
      errback(err instanceof Error ? err : new Error("Receive transport bağlanamadı"));
    }
  });
}

function RemoteVideo({ stream }: { stream: MediaStream }) {
  const ref = useRef<HTMLVideoElement | null>(null);
  useEffect(() => {
    if (ref.current) ref.current.srcObject = stream;
  }, [stream]);
  return <video ref={ref} autoPlay playsInline />;
}

function RemoteAudio({ stream }: { stream: MediaStream }) {
  const ref = useRef<HTMLAudioElement | null>(null);
  useEffect(() => {
    if (ref.current) ref.current.srcObject = stream;
  }, [stream]);
  return <audio ref={ref} autoPlay />;
}
