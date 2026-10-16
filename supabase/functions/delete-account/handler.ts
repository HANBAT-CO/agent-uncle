type Result<T> = { data: T; error: { code?: string; message: string } | null };

export interface DeletionBackend {
  authenticate(token: string): Promise<Result<{ id: string } | null>>;
  begin(id: string): Promise<void>;
  files(id: string): Promise<string[]>;
  removeFiles(paths: string[]): Promise<void>;
  deleteUser(id: string): Promise<void>;
}

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

export function deletionHandler(backend: DeletionBackend) {
  const reply = (status: number, body: object) => Response.json(body, { status, headers });
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response(null, { headers });
    if (request.method !== "POST") return reply(405, { error: "POST 요청만 가능해요." });
    const token = request.headers.get("Authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
    if (!token) return reply(401, { error: "로그인이 필요해요." });
    try {
      const body = await request.json();
      if (body?.confirm !== true) return reply(400, { error: "탈퇴 확인이 필요해요." });
    } catch {
      return reply(400, { error: "탈퇴 확인이 필요해요." });
    }
    try {
      // 클라이언트가 지정한 사용자 ID는 받지 않는다. Auth 서버가 확인한 본인만 삭제한다.
      const { data: user, error } = await backend.authenticate(token);
      // 직전 삭제 응답이 유실된 재시도: Auth 서버가 서명 검증 후 반환한 코드만 인정한다.
      if (error?.code === "user_not_found") return reply(200, { deleted: true });
      if (error || !user) return reply(401, { error: "다시 로그인해 주세요." });
      await backend.begin(user.id);
      // 시간 제한에 도달해도 삭제 중 상태를 유지한다. 재시도는 남은 파일부터 진행한다.
      for (let batch = 0; batch < 30; batch++) {
        const paths = await backend.files(user.id);
        if (paths.length === 0) {
          await backend.deleteUser(user.id);
          return reply(200, { deleted: true });
        }
        if (paths.some((path) => !path.startsWith(`${user.id}/`))) {
          throw new Error("탈퇴 파일 범위를 확인하지 못했습니다.");
        }
        await backend.removeFiles(paths);
      }
      return reply(503, { error: "파일을 정리하고 있어요. 탈퇴를 다시 시도해 주세요." });
    } catch {
      // 토큰, 프로필, Storage 경로 등은 응답이나 로그에 남기지 않는다.
      return reply(503, { error: "탈퇴를 완료하지 못했어요. 다시 시도해 주세요." });
    }
  };
}
