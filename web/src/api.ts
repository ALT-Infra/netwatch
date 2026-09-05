export type Camera = {
  id: string;
  name: string;
  host: string;
  has_substream: boolean;
  has_credentials: boolean;
  created_at: string;
  checked_at: string | null;
  last_probe: null | {
    stream: "main" | "sub";
    status: "reachable" | "unreachable";
    message: string;
    codec: string | null;
    width: number | null;
    height: number | null;
  };
};

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

export async function request<T>(
  token: string,
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const response = await fetch(`/api${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new ApiError(
      typeof body.detail === "string" ? body.detail : "Request failed.",
      response.status,
    );
  }
  return response.status === 204 ? (undefined as T) : response.json();
}
