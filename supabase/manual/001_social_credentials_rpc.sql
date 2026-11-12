-- Run once in Supabase SQL Editor for the existing project.
-- Creates owner-checked RPCs so server-side code can write/read encrypted token bytes
-- held in private.social_credentials. All public execute rights are revoked.

create unique index if not exists social_credentials_workspace_platform_uidx
  on private.social_credentials (workspace_id, platform);

create or replace function public.save_social_credential(
  p_owner_id uuid,
  p_workspace_id uuid,
  p_platform text,
  p_platform_user_id text,
  p_handle text,
  p_access_token_hex text,
  p_token_expires_at timestamptz,
  p_scopes text[] default '{}'
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.workspaces w where w.id = p_workspace_id and w.owner_id = p_owner_id) then
    raise exception 'Workspace ownership check failed';
  end if;
  if p_platform not in ('instagram','threads') then raise exception 'Unsupported platform'; end if;
  delete from private.social_credentials where workspace_id = p_workspace_id and platform = p_platform::public.social_platform;
  insert into private.social_credentials (
    workspace_id, platform, platform_user_id, handle, access_token_ciphertext,
    token_expires_at, scopes, connected_at
  ) values (
    p_workspace_id, p_platform::public.social_platform, p_platform_user_id, p_handle,
    decode(p_access_token_hex, 'hex'), p_token_expires_at, coalesce(p_scopes, '{}'), now()
  );
end;
$$;

create or replace function public.read_social_credential(
  p_owner_id uuid, p_workspace_id uuid, p_platform text
) returns table (
  platform_user_id text, handle text, access_token_hex text,
  token_expires_at timestamptz, scopes text[]
)
language sql
security definer
set search_path = ''
as $$
  select c.platform_user_id, c.handle, encode(c.access_token_ciphertext, 'hex'), c.token_expires_at, c.scopes
  from private.social_credentials c
  join public.workspaces w on w.id = c.workspace_id
  where w.id = p_workspace_id and w.owner_id = p_owner_id
    and c.platform = p_platform::public.social_platform
  limit 1;
$$;

create or replace function public.delete_social_credential(
  p_owner_id uuid, p_workspace_id uuid, p_platform text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.social_credentials c
  using public.workspaces w
  where c.workspace_id = w.id and w.id = p_workspace_id and w.owner_id = p_owner_id
    and c.platform = p_platform::public.social_platform;
end;
$$;

revoke all on function public.save_social_credential(uuid,uuid,text,text,text,text,timestamptz,text[]) from public, anon, authenticated;
revoke all on function public.read_social_credential(uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.delete_social_credential(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.save_social_credential(uuid,uuid,text,text,text,text,timestamptz,text[]) to service_role;
grant execute on function public.read_social_credential(uuid,uuid,text) to service_role;
grant execute on function public.delete_social_credential(uuid,uuid,text) to service_role;

-- Idempotent platform object lookup keys for sync operations.
create unique index if not exists social_accounts_workspace_platform_uidx
  on public.social_accounts (workspace_id, platform);
create unique index if not exists posts_workspace_platform_post_uidx
  on public.posts (social_account_id, platform_post_id);
create unique index if not exists comments_workspace_platform_comment_uidx
  on public.comments (social_account_id, platform_comment_id);
