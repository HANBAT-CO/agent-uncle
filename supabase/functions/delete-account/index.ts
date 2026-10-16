import { createClient } from "npm:@supabase/supabase-js@2.99.1";
import { deletionHandler } from "./handler.ts";

const client = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

Deno.serve(deletionHandler({
  async authenticate(token) {
    const { data, error } = await client.auth.getUser(token);
    return { data: data.user, error };
  },
  async begin(id) {
    const { error } = await client.rpc("saip_begin_account_deletion", { account_id: id });
    if (error) throw error;
  },
  async files(id) {
    const { data, error } = await client.rpc("saip_deletion_files", { account_id: id });
    if (error) throw error;
    return (data as { name: string }[]).map((row) => row.name);
  },
  async removeFiles(paths) {
    const { error } = await client.storage.from("saip-attachments").remove(paths);
    if (error) throw error;
  },
  async deleteUser(id) {
    const { error } = await client.auth.admin.deleteUser(id);
    if (error && error.code !== "user_not_found") throw error;
  },
}));
