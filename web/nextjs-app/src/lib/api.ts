export type Role = "CANDIDATE" | "EXPERT" | "ADMIN";

export type ApiEnvelope<T> = {
  success?: boolean;
  data?: T;
  error?: string;
  message?: string;
};

export type PageResponse<T> = {
  items: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  hasNext: boolean;
  hasPrevious: boolean;
};

export type AuthSession = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  userId: string;
};

export type Me = {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  roles: Role[];
};

export type UserProfile = {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  avatarUrl?: string | null;
  role: Role;
};

export type Industry = {
  id: string;
  name: string;
  slug: string;
};

export type Skill = {
  id: string;
  name: string;
  slug: string;
};

export type ExpertSummary = {
  id: string;
  userId: string;
  firstName: string;
  lastName: string;
  avatarUrl?: string | null;
  headline?: string | null;
  company?: string | null;
  industry?: Industry | null;
  skills?: Skill[];
  yearsOfExperience?: number | null;
  hourlyRate?: string | number | null;
  currency?: string | null;
  averageRating?: string | number | null;
  totalSessions?: number | null;
  isVerified?: boolean | null;
  isAvailable?: boolean | null;
};

export type ExpertDetail = ExpertSummary & {
  email?: string;
  bio?: string | null;
};

export type Slot = {
  id: string;
  expertId: string;
  startTime: string;
  endTime: string;
  booked: boolean;
};

export type ShopSummary = {
  id: string;
  expertUserId: string;
  expertFirstName: string;
  expertLastName: string;
  expertAvatarUrl?: string | null;
  industry?: Industry | null;
  skills?: Skill[];
  description?: string | null;
  yearsOfExperience: number;
  hourlyRate?: number | null;
  currency?: string | null;
  isPublished: boolean;
  averageRating?: number | null;
  isAvailable?: boolean | null;
};

export type ExpertStats = {
  expertUserId: string;
  averageRating?: number | null;
  totalRated: number;
  completedCount: number;
  cancelledCount: number;
};

export type ExpertReview = {
  bookingId: string;
  rating?: number | null;
  comment?: string | null;
  scheduledEnd?: string | null;
};

export type Booking = {
  id: string;
  candidateId: string;
  expertId: string;
  slotId: string;
  status: "PENDING" | "CONFIRMED" | "COMPLETED" | "CANCELLED";
  scheduledStart: string;
  scheduledEnd: string;
  expertRating?: number | null;
  expertComment?: string | null;
  candidateRating?: number | null;
  candidateComment?: string | null;
};

export type SessionSummary = {
  sessionId: string;
  bookingId: string;
  candidateId: string;
  expertId: string;
  status: string;
  signalingWebSocketUrl: string;
  iceServers?: RTCIceServer[];
};

export type AnalysisReport = {
  sessionId: string;
  transcript: string;
  analysis: Record<string, unknown>;
  createdAt: string;
};

export type DashboardData = {
  me: Me;
  profile?: UserProfile;
  experts?: PageResponse<ExpertSummary>;
  shops?: PageResponse<ShopSummary>;
  industries?: Industry[];
  skills?: Skill[];
  bookings?: PageResponse<Booking>;
  availability?: Slot[];
  ownExpertProfile?: ExpertDetail;
  ownShop?: ShopSummary | null;
};

const TOKEN_KEY = "internview.access_token";
const REFRESH_KEY = "internview.refresh_token";
const USER_ID_KEY = "internview.user_id";
const EXPIRES_KEY = "internview.expires_in";

export function readStoredSession(): AuthSession | null {
  if (typeof window === "undefined") return null;
  const accessToken = window.localStorage.getItem(TOKEN_KEY);
  const refreshToken = window.localStorage.getItem(REFRESH_KEY);
  const userId = window.localStorage.getItem(USER_ID_KEY);
  const expiresIn = Number(window.localStorage.getItem(EXPIRES_KEY) ?? 0);
  if (!accessToken || !refreshToken || !userId) return null;
  return { accessToken, refreshToken, userId, expiresIn };
}

export function storeSession(session: AuthSession) {
  window.localStorage.setItem(TOKEN_KEY, session.accessToken);
  window.localStorage.setItem(REFRESH_KEY, session.refreshToken);
  window.localStorage.setItem(USER_ID_KEY, session.userId);
  window.localStorage.setItem(EXPIRES_KEY, String(session.expiresIn));
}

export function clearSession() {
  window.localStorage.removeItem(TOKEN_KEY);
  window.localStorage.removeItem(REFRESH_KEY);
  window.localStorage.removeItem(USER_ID_KEY);
  window.localStorage.removeItem(EXPIRES_KEY);
}

export async function apiFetch<T>(
  path: string,
  options: RequestInit & { token?: string } = {},
): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set("Accept", "application/json");
  if (!(options.body instanceof FormData) && options.body !== undefined) {
    headers.set("Content-Type", "application/json");
  }
  if (options.token) {
    headers.set("Authorization", `Bearer ${options.token}`);
  }

  const response = await fetch(`/api/backend${path}`, {
    ...options,
    headers,
    cache: "no-store",
  });

  const contentType = response.headers.get("content-type") ?? "";
  const body = contentType.includes("application/json") ? await response.json() : await response.text();

  if (!response.ok) {
    throw new Error(readError(body, response.status));
  }

  if (body && typeof body === "object" && "data" in body) {
    return (body as ApiEnvelope<T>).data as T;
  }
  return body as T;
}

export async function uploadAvatar(file: File, token: string) {
  const form = new FormData();
  form.append("file", file);
  const response = await apiFetch<{ url: string; key?: string }>("/media/uploads/avatar", {
    method: "POST",
    token,
    body: form,
  });
  return response.url;
}

export async function login(email: string, password: string): Promise<AuthSession> {
  const data = await apiFetch<{
    user_id: string;
    access_token: string;
    refresh_token: string;
    expires_in: number;
  }>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresIn: data.expires_in,
    userId: data.user_id,
  };
}

export async function register(payload: {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  role: Role;
}): Promise<AuthSession> {
  const data = await apiFetch<{
    user_id: string;
    access_token: string;
    refresh_token: string;
    expires_in: number;
  }>("/auth/register", {
    method: "POST",
    body: JSON.stringify({
      email: payload.email,
      password: payload.password,
      first_name: payload.firstName,
      last_name: payload.lastName,
      role: payload.role,
    }),
  });
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresIn: data.expires_in,
    userId: data.user_id,
  };
}

export async function loadDashboard(token: string): Promise<DashboardData> {
  const me = await apiFetch<Me>("/auth/me", { token });
  const primaryRole = me.roles.includes("EXPERT") ? "EXPERT" : "CANDIDATE";

  const profilePromise = apiFetch<UserProfile>("/users/profile", { token }).catch(() => undefined);
  const industriesPromise = apiFetch<Industry[]>("/industries").catch(() => []);
  const skillsPromise = apiFetch<Skill[]>("/skills").catch(() => []);

  if (primaryRole === "EXPERT") {
    const [profile, ownExpertProfile, ownShop, bookings, availability, industries, skills] = await Promise.all([
      profilePromise,
      apiFetch<ExpertDetail>("/experts/me", { token }).catch(() => undefined),
      apiFetch<ShopSummary | null>("/shops/me", { token }).catch(() => null),
      apiFetch<PageResponse<Booking>>("/bookings/me/expert?size=20", { token }),
      apiFetch<Slot[]>("/experts/me/availability", { token }),
      industriesPromise,
      skillsPromise,
    ]);
    return { me, profile, ownExpertProfile, ownShop, bookings, availability, industries, skills };
  }

  const [profile, experts, shops, bookings, industries, skills] = await Promise.all([
    profilePromise,
    apiFetch<PageResponse<ExpertSummary>>("/experts?is_available=true&size=12"),
    apiFetch<PageResponse<ShopSummary>>("/shops?published_only=true&is_available=true&size=12").catch(() => undefined),
    apiFetch<PageResponse<Booking>>("/bookings/me/candidate?size=20", { token }),
    industriesPromise,
    skillsPromise,
  ]);
  return { me, profile, experts, shops, bookings, industries, skills };
}

export async function loadLandingData() {
  const [experts, industries] = await Promise.all([
    apiFetch<PageResponse<ExpertSummary>>("/experts?is_available=true&size=6"),
    apiFetch<Industry[]>("/industries"),
  ]);
  return { experts, industries };
}

export async function searchExperts(params: {
  search?: string;
  industry?: string;
  skill?: string;
  minRating?: string;
  isAvailable?: boolean;
  size?: number;
}) {
  const query = new URLSearchParams();
  query.set("size", String(params.size ?? 20));
  if (params.search) query.set("search", params.search);
  if (params.industry) query.set("industry", params.industry);
  if (params.skill) query.append("skill", params.skill);
  if (params.minRating) query.set("min_rating", params.minRating);
  if (params.isAvailable !== undefined) query.set("is_available", String(params.isAvailable));
  return apiFetch<PageResponse<ExpertSummary>>(`/experts?${query.toString()}`);
}

export async function listShops(params: {
  token?: string;
  industry?: string;
  skill?: string;
  minRating?: string;
  minPrice?: string;
  maxPrice?: string;
  isAvailable?: boolean;
  publishedOnly?: boolean;
  size?: number;
}) {
  const query = new URLSearchParams();
  query.set("size", String(params.size ?? 20));
  query.set("published_only", String(params.publishedOnly ?? true));
  if (params.industry) query.set("industry", params.industry);
  if (params.skill) query.append("skill", params.skill);
  if (params.minRating) query.set("min_rating", params.minRating);
  if (params.minPrice) query.set("min_price", params.minPrice);
  if (params.maxPrice) query.set("max_price", params.maxPrice);
  if (params.isAvailable !== undefined) query.set("is_available", String(params.isAvailable));
  return apiFetch<PageResponse<ShopSummary>>(`/shops?${query.toString()}`, { token: params.token });
}

export async function getShop(id: string, token: string) {
  return apiFetch<ShopSummary>(`/shops/${id}`, { token });
}

export async function getExpertStats(expertUserId: string, token: string) {
  return apiFetch<ExpertStats>(`/experts/${expertUserId}/stats`, { token });
}

export async function getExpertReviews(expertUserId: string, token: string) {
  return apiFetch<PageResponse<ExpertReview>>(`/experts/${expertUserId}/reviews?size=10`, { token });
}

export function shopExpertName(shop: ShopSummary) {
  return [shop.expertFirstName, shop.expertLastName].filter(Boolean).join(" ");
}

export function fullName(value: {
  firstName?: string | null;
  lastName?: string | null;
  first_name?: string | null;
  last_name?: string | null;
}) {
  return [value.firstName ?? value.first_name, value.lastName ?? value.last_name].filter(Boolean).join(" ");
}

export function normalizeMediaUrl(raw?: string | null) {
  if (!raw) return "";
  const value = raw.trim();
  if (!value) return "";
  if (typeof window === "undefined") return value;
  const origin = window.location.origin;
  if (value.startsWith(`${origin}/`)) return value;
  const mediaFilesIndex = value.indexOf("/media/files/");
  if (mediaFilesIndex >= 0) return `${origin}/api/backend${value.slice(mediaFilesIndex)}`;
  const avatarsIndex = value.indexOf("/avatars/");
  if (avatarsIndex >= 0) {
    const key = value.slice(avatarsIndex + 1);
    return `${origin}/api/backend/media/files/${encodeURIComponent(key)}`;
  }
  if (value.includes("media-service:3000")) {
    return value.replace(/^https?:\/\/media-service:3000/, `${origin}/api/backend`);
  }
  return value;
}

export function formatDateTime(value?: string | null) {
  if (!value) return "";
  return new Intl.DateTimeFormat("tr-TR", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function readError(body: unknown, status: number) {
  if (body && typeof body === "object") {
    const record = body as Record<string, unknown>;
    const nestedError = record.error;
    if (nestedError && typeof nestedError === "object") {
      const nested = nestedError as Record<string, unknown>;
      return String(nested.message ?? nested.code ?? `İstek başarısız oldu (${status})`);
    }
    return String(record.message ?? record.error ?? `İstek başarısız oldu (${status})`);
  }
  return typeof body === "string" && body ? body : `İstek başarısız oldu (${status})`;
}
