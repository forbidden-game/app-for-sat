insert into storage.buckets (id, name, public)
values ('question-assets', 'question-assets', true)
on conflict (id) do nothing;

create policy "Admin upload question assets"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'question-assets' 
    and (select public.is_admin())
  );

create policy "Admin update question assets"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'question-assets' 
    and (select public.is_admin())
  );

create policy "Admin delete question assets"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'question-assets' 
    and (select public.is_admin())
  );

create policy "Public read question assets"
  on storage.objects for select
  to public
  using (bucket_id = 'question-assets');
