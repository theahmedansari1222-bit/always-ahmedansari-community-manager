-- Zhentropic: paste into Supabase Dashboard > SQL Editor > Run
create extension if not exists pgcrypto;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'New chat',
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null default '',
  reasoning_content text,
  thinking_duration int,
  attachment_url text,
  attachment_type text check (attachment_type in ('image', 'pdf')),
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_idx on public.messages (conversation_id, created_at);
create index if not exists conversations_user_idx on public.conversations (user_id, created_at desc);

-- Row Level Security: every user sees only their own data
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create policy "own conversations" on public.conversations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own messages" on public.messages
  for all
  using (exists (select 1 from public.conversations c where c.id = conversation_id and c.user_id = auth.uid()))
  with check (exists (select 1 from public.conversations c where c.id = conversation_id and c.user_id = auth.uid()));

-- Private storage bucket; files live under <user_id>/<file>
insert into storage.buckets (id, name, public)
values ('zhentropic-files', 'zhentropic-files', false)
on conflict (id) do nothing;

create policy "own files select" on storage.objects
  for select using (bucket_id = 'zhentropic-files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own files insert" on storage.objects
  for insert with check (bucket_id = 'zhentropic-files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own files delete" on storage.objects
  for delete using (bucket_id = 'zhentropic-files' and (storage.foldername(name))[1] = auth.uid()::text);
