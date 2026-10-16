import { deletionHandler, type DeletionBackend } from "./handler.ts";

function assert(value: unknown, message = "검증 실패"): asserts value {
  if (!value) throw new Error(message);
}
function fixture() {
  const calls: string[] = [];
  let files = ["owner/photo", "owner/nested/orphan"];
  const backend: DeletionBackend = {
    authenticate: () => Promise.resolve({ data: { id: "owner" }, error: null }),
    begin: (id) => { calls.push(`begin:${id}`); return Promise.resolve(); },
    files: () => Promise.resolve(files),
    removeFiles: (paths) => {
      calls.push(`files:${paths.join(",")}`);
      files = [];
      return Promise.resolve();
    },
    deleteUser: (id) => { calls.push(`delete:${id}`); return Promise.resolve(); },
  };
  const request = (body: object = { confirm: true, userId: "victim" }) =>
    new Request("https://test/delete-account", {
      method: "POST", headers: { Authorization: "Bearer test-token" }, body: JSON.stringify(body),
    });
  return { backend, calls, request };
}

Deno.test("본인 인증 ID만 사용하고 모든 파일 삭제 후 계정을 삭제한다", async () => {
  const f = fixture();
  const result = await deletionHandler(f.backend)(f.request());
  assert(result.status === 200);
  assert((await result.json()).deleted === true);
  assert(f.calls.join("|") === "begin:owner|files:owner/photo,owner/nested/orphan|delete:owner");
});

Deno.test("파일 삭제 실패 시 계정을 유지하고 남은 파일부터 재시도한다", async () => {
  const f = fixture();
  const remove = f.backend.removeFiles;
  f.backend.removeFiles = () => Promise.reject(new Error("storage unavailable"));
  const handler = deletionHandler(f.backend);
  assert((await handler(f.request())).status === 503);
  assert(!f.calls.some((c) => c.startsWith("delete:")));
  f.backend.removeFiles = remove;
  assert((await handler(f.request())).status === 200);
});

Deno.test("인증 실패·미확인·GET 요청으로 계정을 삭제할 수 없다", async () => {
  const f = fixture();
  const handler = deletionHandler(f.backend);
  assert((await handler(new Request("https://test"))).status === 405);
  assert((await handler(new Request("https://test", { method: "POST" }))).status === 401);
  assert((await handler(f.request({ confirm: false }))).status === 400);
  f.backend.authenticate = () => Promise.resolve({ data: null, error: { code: "bad_jwt", message: "bad" } });
  assert((await handler(f.request())).status === 401);
  assert(f.calls.length === 0);
});

Deno.test("Auth 삭제 실패 후 재시도는 파일 정리를 반복하지 않는다", async () => {
  const f = fixture();
  const removeUser = f.backend.deleteUser;
  f.backend.deleteUser = () => Promise.reject(new Error("database unavailable"));
  const handler = deletionHandler(f.backend);
  assert((await handler(f.request())).status === 503);
  f.backend.deleteUser = removeUser;
  assert((await handler(f.request())).status === 200);
  assert(f.calls.filter((c) => c.startsWith("files:")).length === 1);
});

Deno.test("이미 삭제된 사용자 응답 유실 재시도는 완료로 응답한다", async () => {
  const f = fixture();
  f.backend.authenticate = () => Promise.resolve({ data: null, error: { code: "user_not_found", message: "missing" } });
  const response = await deletionHandler(f.backend)(f.request());
  assert(response.status === 200);
  assert(f.calls.length === 0);
});

Deno.test("다른 계정 경로는 삭제하지 않는다", async () => {
  const f = fixture();
  f.backend.files = () => Promise.resolve(["other/secret"]);
  assert((await deletionHandler(f.backend)(f.request())).status === 503);
  assert(f.calls.join() === "begin:owner");
});
