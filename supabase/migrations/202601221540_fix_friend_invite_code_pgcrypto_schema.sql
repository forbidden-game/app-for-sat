-- Ensure pgcrypto functions are resolvable inside invite code RPC
create or replace function public.get_my_friend_invite_code()
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code text;
  v_existing text;
  i int;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select code into v_existing
  from public.friend_invite_codes
  where owner_id = auth.uid();

  if v_existing is not null then
    return v_existing;
  end if;

  for i in 1..10 loop
    v_code := substr(encode(gen_random_bytes(8), 'hex'), 1, 12);
    begin
      insert into public.friend_invite_codes (owner_id, code)
      values (auth.uid(), v_code)
      on conflict (owner_id) do nothing;
      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  select code into v_existing
  from public.friend_invite_codes
  where owner_id = auth.uid();

  if v_existing is null then
    raise exception 'invite_code_generation_failed';
  end if;

  return v_existing;
end;
$$;
