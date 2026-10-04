-- Chat objects are accessed only through the authenticated FastAPI boundary.
-- The backend uses the service role after verifying Firebase conversation
-- membership, so no direct client storage policies are intentionally added.
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-media', 'chat-media', false, 26214400)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit;
