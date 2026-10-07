-- Freshline complete Supabase schema
-- Copy/paste into Supabase SQL Editor.
-- This schema is designed for a staged MVP with customer, salon owner, and admin roles.
--
-- OTP delivery note:
-- - Email/SMS code delivery is handled by Supabase Edge Functions in `supabase/functions`:
--   - `send-auth-otp` (dispatch)
--   - `verify-auth-otp` (verify)
-- - After running this SQL, deploy the Edge Functions to your Supabase project.
--   See `supabase/DEPLOY.md`.

create extension if not exists pgcrypto;

create schema if not exists private;

-- -----------------------------------------------------------------------------
-- OTP bootstrap (run early so auth code delivery never depends on later seed SQL)
-- -----------------------------------------------------------------------------
create table if not exists private.auth_email_otps (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid,
  email text not null,
  purpose text not null check (
    purpose in (
      'email_verification',
      'two_factor_setup',
      'two_factor_sign_in',
      'password_reset'
    )
  ),
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_auth_email_otps_email_purpose
  on private.auth_email_otps(email, purpose, created_at desc);
create index if not exists idx_auth_email_otps_profile_id
  on private.auth_email_otps(profile_id);

create table if not exists private.auth_phone_otps (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid,
  phone text not null,
  purpose text not null check (
    purpose in (
      'email_verification',
      'two_factor_setup',
      'two_factor_sign_in',
      'password_reset'
    )
  ),
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_auth_phone_otps_phone_purpose
  on private.auth_phone_otps(phone, purpose, created_at desc);
create index if not exists idx_auth_phone_otps_profile_id
  on private.auth_phone_otps(profile_id);

create or replace function public.hash_auth_email_otp(code_value text)
returns text
language sql
immutable
as $$
  select md5(coalesce(code_value, ''))
$$;

create or replace function public.hash_auth_phone_otp(code_value text)
returns text
language sql
immutable
as $$
  select md5(coalesce(code_value, ''))
$$;

create or replace function public.create_auth_email_otp(
  p_email text,
  p_purpose text,
  p_code text,
  p_profile_id uuid default null,
  p_expires_in_minutes integer default 10
)
returns timestamptz
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_purpose text := lower(btrim(coalesce(p_purpose, '')));
  v_code text := btrim(coalesce(p_code, ''));
  v_expires_at timestamptz;
  v_recent_count integer;
begin
  if v_email = '' then
    raise exception 'Email is required.';
  end if;

  if v_purpose not in (
    'email_verification',
    'two_factor_setup',
    'two_factor_sign_in',
    'password_reset'
  ) then
    raise exception 'OTP purpose is invalid.';
  end if;

  if v_code !~ '^[0-9]{6}$' then
    raise exception 'OTP code must be 6 digits.';
  end if;

  select count(*)
  into v_recent_count
  from private.auth_email_otps
  where email = v_email
    and purpose = v_purpose
    and created_at >= now() - interval '1 hour';

  if coalesce(v_recent_count, 0) >= 2 then
    raise exception 'Too many OTP requests. Please wait 1 hour and try again.';
  end if;

  update private.auth_email_otps
  set consumed_at = now()
  where email = v_email
    and purpose = v_purpose
    and (p_profile_id is null or profile_id = p_profile_id)
    and consumed_at is null
    and expires_at >= now();

  delete from private.auth_email_otps
  where (expires_at < now() - interval '24 hours')
     or (consumed_at is not null and consumed_at < now() - interval '24 hours');

  v_expires_at := now() + make_interval(mins => greatest(coalesce(p_expires_in_minutes, 10), 1));

  insert into private.auth_email_otps (
    profile_id,
    email,
    purpose,
    code_hash,
    expires_at
  )
  values (
    p_profile_id,
    v_email,
    v_purpose,
    public.hash_auth_email_otp(v_code),
    v_expires_at
  );

  return v_expires_at;
end;
$$;

create or replace function public.create_auth_email_otp(
  p_email text,
  p_purpose text,
  p_code text
)
returns timestamptz
language sql
security definer
set search_path = public, private
as $$
  select public.create_auth_email_otp(
    p_email => p_email,
    p_purpose => p_purpose,
    p_code => p_code,
    p_profile_id => null,
    p_expires_in_minutes => 10
  )
$$;

create or replace function public.create_auth_email_otp(
  p_email text,
  p_purpose text,
  p_code text,
  p_expires_in_minutes integer
)
returns timestamptz
language sql
security definer
set search_path = public, private
as $$
  select public.create_auth_email_otp(
    p_email => p_email,
    p_purpose => p_purpose,
    p_code => p_code,
    p_profile_id => null,
    p_expires_in_minutes => p_expires_in_minutes
	  )
$$;

create or replace function public.create_auth_phone_otp(
  p_phone text,
  p_purpose text,
  p_code text,
  p_profile_id uuid default null,
  p_expires_in_minutes integer default 10
)
returns timestamptz
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_phone text := btrim(coalesce(p_phone, ''));
  v_purpose text := lower(btrim(coalesce(p_purpose, '')));
  v_code text := btrim(coalesce(p_code, ''));
  v_expires_at timestamptz;
  v_recent_count integer;
begin
  if v_phone = '' then
    raise exception 'Phone is required.';
  end if;

  if v_purpose not in (
    'email_verification',
    'two_factor_setup',
    'two_factor_sign_in',
    'password_reset'
  ) then
    raise exception 'OTP purpose is invalid.';
  end if;

  if v_code !~ '^[0-9]{6}$' then
    raise exception 'OTP code must be 6 digits.';
  end if;

  select count(*)
  into v_recent_count
  from private.auth_phone_otps
  where phone = v_phone
    and purpose = v_purpose
    and created_at >= now() - interval '1 hour';

  if coalesce(v_recent_count, 0) >= 2 then
    raise exception 'Too many OTP requests. Please wait 1 hour and try again.';
  end if;

  update private.auth_phone_otps
  set consumed_at = now()
  where phone = v_phone
    and purpose = v_purpose
    and (p_profile_id is null or profile_id = p_profile_id)
    and consumed_at is null
    and expires_at >= now();

  delete from private.auth_phone_otps
  where (expires_at < now() - interval '24 hours')
     or (consumed_at is not null and consumed_at < now() - interval '24 hours');

  v_expires_at := now() + make_interval(mins => greatest(coalesce(p_expires_in_minutes, 10), 1));

  insert into private.auth_phone_otps (
    profile_id,
    phone,
    purpose,
    code_hash,
    expires_at
  )
  values (
    p_profile_id,
    v_phone,
    v_purpose,
    public.hash_auth_phone_otp(v_code),
    v_expires_at
  );

  return v_expires_at;
end;
$$;

create or replace function public.create_auth_phone_otp(
  p_phone text,
  p_purpose text,
  p_code text
)
returns timestamptz
language sql
security definer
set search_path = public, private
as $$
  select public.create_auth_phone_otp(
    p_phone => p_phone,
    p_purpose => p_purpose,
    p_code => p_code,
    p_profile_id => null,
    p_expires_in_minutes => 10
  )
$$;

create or replace function public.create_auth_phone_otp(
  p_phone text,
  p_purpose text,
  p_code text,
  p_expires_in_minutes integer
)
returns timestamptz
language sql
security definer
set search_path = public, private
as $$
  select public.create_auth_phone_otp(
    p_phone => p_phone,
    p_purpose => p_purpose,
    p_code => p_code,
    p_profile_id => null,
    p_expires_in_minutes => p_expires_in_minutes
  )
$$;

create or replace function public.verify_auth_email_otp(
  p_email text,
  p_purpose text,
  p_code text,
  p_profile_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_purpose text := lower(btrim(coalesce(p_purpose, '')));
  v_code text := btrim(coalesce(p_code, ''));
  v_verified_id uuid;
begin
  if v_email = ''
     or v_purpose not in (
       'email_verification',
       'two_factor_setup',
       'two_factor_sign_in',
       'password_reset'
     )
     or v_code !~ '^[0-9]{6}$' then
    return false;
  end if;

  with candidate as (
    select otp.id
    from private.auth_email_otps otp
    where otp.email = v_email
      and otp.purpose = v_purpose
      and otp.code_hash = public.hash_auth_email_otp(v_code)
      and otp.consumed_at is null
      and otp.expires_at >= now()
      and (p_profile_id is null or otp.profile_id = p_profile_id)
    order by otp.created_at desc
    limit 1
  )
  update private.auth_email_otps otp
  set consumed_at = now()
  from candidate
  where otp.id = candidate.id
  returning otp.id into v_verified_id;

  delete from private.auth_email_otps
  where (expires_at < now() - interval '24 hours')
     or (consumed_at is not null and consumed_at < now() - interval '24 hours');

  return v_verified_id is not null;
end;
$$;

create or replace function public.verify_auth_email_otp(
  p_email text,
  p_purpose text,
  p_code text
)
returns boolean
language sql
security definer
set search_path = public, private
as $$
  select public.verify_auth_email_otp(
    p_email => p_email,
    p_purpose => p_purpose,
    p_code => p_code,
    p_profile_id => null
  )
$$;

create or replace function public.verify_auth_phone_otp(
  p_phone text,
  p_purpose text,
  p_code text,
  p_profile_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_phone text := btrim(coalesce(p_phone, ''));
  v_purpose text := lower(btrim(coalesce(p_purpose, '')));
  v_code text := btrim(coalesce(p_code, ''));
  v_verified_id uuid;
begin
  if v_phone = ''
     or v_purpose not in (
       'email_verification',
       'two_factor_setup',
       'two_factor_sign_in',
       'password_reset'
     )
     or v_code !~ '^[0-9]{6}$' then
    return false;
  end if;

  with candidate as (
    select otp.id
    from private.auth_phone_otps otp
    where otp.phone = v_phone
      and otp.purpose = v_purpose
      and otp.code_hash = public.hash_auth_phone_otp(v_code)
      and otp.consumed_at is null
      and otp.expires_at >= now()
      and (p_profile_id is null or otp.profile_id = p_profile_id)
    order by otp.created_at desc
    limit 1
  )
  update private.auth_phone_otps otp
  set consumed_at = now()
  from candidate
  where otp.id = candidate.id
  returning otp.id into v_verified_id;

  delete from private.auth_phone_otps
  where (expires_at < now() - interval '24 hours')
     or (consumed_at is not null and consumed_at < now() - interval '24 hours');

  return v_verified_id is not null;
end;
$$;

create or replace function public.verify_auth_phone_otp(
  p_phone text,
  p_purpose text,
  p_code text
)
returns boolean
language sql
security definer
set search_path = public, private
as $$
  select public.verify_auth_phone_otp(
    p_phone => p_phone,
    p_purpose => p_purpose,
    p_code => p_code,
    p_profile_id => null
  )
$$;

do $$
begin
  revoke all on function public.verify_auth_email_otp(text, text, text) from public;
  revoke all on function public.verify_auth_email_otp(text, text, text, uuid) from public;
  revoke all on function public.create_auth_email_otp(text, text, text) from public;
  revoke all on function public.create_auth_email_otp(text, text, text, integer) from public;
  revoke all on function public.create_auth_email_otp(text, text, text, uuid, integer) from public;
  revoke all on function public.verify_auth_phone_otp(text, text, text) from public;
  revoke all on function public.verify_auth_phone_otp(text, text, text, uuid) from public;
  revoke all on function public.create_auth_phone_otp(text, text, text) from public;
  revoke all on function public.create_auth_phone_otp(text, text, text, integer) from public;
  revoke all on function public.create_auth_phone_otp(text, text, text, uuid, integer) from public;

  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant execute on function public.verify_auth_email_otp(text, text, text) to anon;
    grant execute on function public.verify_auth_email_otp(text, text, text, uuid) to anon;
    grant execute on function public.verify_auth_phone_otp(text, text, text) to anon;
    grant execute on function public.verify_auth_phone_otp(text, text, text, uuid) to anon;
    grant execute on function public.create_auth_email_otp(text, text, text) to anon;
    grant execute on function public.create_auth_email_otp(text, text, text, integer) to anon;
    grant execute on function public.create_auth_email_otp(text, text, text, uuid, integer) to anon;
    grant execute on function public.create_auth_phone_otp(text, text, text) to anon;
    grant execute on function public.create_auth_phone_otp(text, text, text, integer) to anon;
    grant execute on function public.create_auth_phone_otp(text, text, text, uuid, integer) to anon;
  end if;

  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.verify_auth_email_otp(text, text, text) to authenticated;
    grant execute on function public.verify_auth_email_otp(text, text, text, uuid) to authenticated;
    grant execute on function public.verify_auth_phone_otp(text, text, text) to authenticated;
    grant execute on function public.verify_auth_phone_otp(text, text, text, uuid) to authenticated;
    grant execute on function public.create_auth_email_otp(text, text, text) to authenticated;
    grant execute on function public.create_auth_email_otp(text, text, text, integer) to authenticated;
    grant execute on function public.create_auth_email_otp(text, text, text, uuid, integer) to authenticated;
    grant execute on function public.create_auth_phone_otp(text, text, text) to authenticated;
    grant execute on function public.create_auth_phone_otp(text, text, text, integer) to authenticated;
    grant execute on function public.create_auth_phone_otp(text, text, text, uuid, integer) to authenticated;
  end if;

  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant usage on schema private to service_role;
    grant execute on function public.create_auth_email_otp(text, text, text) to service_role;
    grant execute on function public.create_auth_email_otp(text, text, text, integer) to service_role;
    grant execute on function public.create_auth_email_otp(text, text, text, uuid, integer) to service_role;
    grant execute on function public.verify_auth_email_otp(text, text, text) to service_role;
    grant execute on function public.verify_auth_email_otp(text, text, text, uuid) to service_role;
    grant execute on function public.create_auth_phone_otp(text, text, text) to service_role;
    grant execute on function public.create_auth_phone_otp(text, text, text, integer) to service_role;
    grant execute on function public.create_auth_phone_otp(text, text, text, uuid, integer) to service_role;
    grant execute on function public.verify_auth_phone_otp(text, text, text) to service_role;
    grant execute on function public.verify_auth_phone_otp(text, text, text, uuid) to service_role;
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('customer', 'salon_owner', 'admin');
  end if;

  if not exists (select 1 from pg_type where typname = 'request_status') then
    create type public.request_status as enum ('pending', 'approved', 'rejected', 'needs_info');
  end if;

  if not exists (select 1 from pg_type where typname = 'visit_mode') then
    create type public.visit_mode as enum ('in_shop', 'home_service');
  end if;

  if not exists (select 1 from pg_type where typname = 'booking_status') then
    create type public.booking_status as enum ('pending', 'confirmed', 'completed', 'cancelled');
  end if;

  if not exists (select 1 from pg_type where typname = 'payment_status') then
    create type public.payment_status as enum ('pending', 'paid', 'failed', 'refunded');
  end if;

  if not exists (select 1 from pg_type where typname = 'subscription_cycle') then
    create type public.subscription_cycle as enum ('monthly', 'yearly');
  end if;

  if not exists (select 1 from pg_type where typname = 'notification_audience') then
    create type public.notification_audience as enum ('all_users', 'all_salons', 'admins', 'single_user', 'single_salon');
  end if;
end
$$;

do $$
begin
  if exists (select 1 from pg_type where typname = 'app_role')
     and not exists (
       select 1
       from pg_enum enum_value
       join pg_type enum_type on enum_type.oid = enum_value.enumtypid
       where enum_type.typname = 'app_role'
         and enum_value.enumlabel = 'employee'
     ) then
    alter type public.app_role add value 'employee';
  end if;
exception
  when duplicate_object then null;
end
$$;

-- Compatibility bridge for older Freshline schemas.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'id'
  ) then
    alter table public.profiles rename column user_id to id;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'saved_cards'
      and column_name = 'customer_user_id'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'saved_cards'
      and column_name = 'customer_id'
  ) then
    alter table public.saved_cards rename column customer_user_id to customer_id;
  end if;
end
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_valid_bahrain_phone(phone_value text)
returns boolean
language sql
immutable
as $$
  select case
    when phone_value is null or btrim(phone_value) = '' then true
    else regexp_replace(phone_value, '\s+', '', 'g') ~ '^\+973[0-9]{8}$'
  end
$$;

create or replace function public.normalize_bahrain_phone(phone_value text)
returns text
language sql
immutable
as $$
  with cleaned as (
    select btrim(coalesce(phone_value, '')) as trimmed
  ),
  digits as (
    select
      trimmed,
      regexp_replace(trimmed, '\D', '', 'g') as raw_digits
    from cleaned
  ),
  normalized as (
    select
      trimmed,
      case
        when trimmed = '' then null
        when raw_digits ~ '^00973[0-9]{8}$' then substring(raw_digits from 6)
        when raw_digits ~ '^973[0-9]{8}$' then substring(raw_digits from 4)
        when raw_digits ~ '^[0-9]{8}$' then raw_digits
        else null
      end as local_digits
    from digits
  )
  select case
    when local_digits is null then null
    else '+973 ' || substring(local_digits from 1 for 4) || ' ' || substring(local_digits from 5 for 4)
  end
  from normalized
$$;

create or replace function public.hash_profile_password(password_value text)
returns text
language sql
immutable
as $$
  select case
    when password_value is null then null
    when btrim(password_value) = '' then password_value
    when btrim(password_value) = 'replace-this-with-a-real-hash'
      then btrim(password_value)
    when lower(btrim(password_value)) ~ '^[0-9a-f]{64}$'
      then lower(btrim(password_value))
    else encode(digest(password_value, 'sha256'), 'hex')
  end
$$;

create or replace function public.is_admin_owner_email(email_value text)
returns boolean
language sql
immutable
as $$
  select lower(btrim(coalesce(email_value, ''))) = 'admin.com'
$$;

create or replace function public.enforce_admin_owner_profile()
returns trigger
language plpgsql
as $$
declare
  v_new_is_owner boolean := public.is_admin_owner_email(new.email);
  v_old_is_owner boolean := false;
begin
  if tg_op <> 'INSERT' then
    v_old_is_owner := public.is_admin_owner_email(old.email);
  end if;

  if v_new_is_owner then
    new.email := 'admin.com';
  end if;

  if v_old_is_owner and not v_new_is_owner then
    raise exception 'The admin owner email must stay fixed as admin.com.';
  end if;

  if v_new_is_owner and new.role <> 'admin'::public.app_role then
    raise exception 'The admin owner account must keep the admin role.';
  end if;

  if v_new_is_owner and coalesce(new.is_active, false) = false then
    raise exception 'The admin owner account must stay active.';
  end if;

  if v_new_is_owner then
    new.is_super_admin := true;
  elsif coalesce(new.is_super_admin, false) then
    raise exception 'Only admin.com can be marked as the admin owner.';
  end if;

  return new;
end;
$$;

create or replace function public.prevent_admin_owner_profile_delete()
returns trigger
language plpgsql
as $$
begin
  if public.is_admin_owner_email(old.email) then
    raise exception 'The admin owner account cannot be deleted.';
  end if;

  return old;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid,
  role public.app_role not null default 'customer',
  full_name text not null,
  username text,
  email text not null unique,
  email_verified_at timestamptz,
  password_hash text,
  phone text,
  city text,
  address text,
  avatar_url text,
  is_active boolean not null default true,
  is_super_admin boolean not null default false,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists id uuid default gen_random_uuid();
alter table public.profiles add column if not exists auth_user_id uuid;
alter table public.profiles add column if not exists role public.app_role default 'customer';
alter table public.profiles add column if not exists full_name text default '';
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists email_verified_at timestamptz;
alter table public.profiles add column if not exists password_hash text;
alter table public.profiles alter column password_hash drop not null;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists city text;
alter table public.profiles add column if not exists address text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists is_active boolean not null default true;
alter table public.profiles add column if not exists is_super_admin boolean not null default false;
alter table public.profiles add column if not exists last_login_at timestamptz;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();
alter table public.profiles drop column if exists preferred_language;
alter table public.profiles drop column if exists two_factor_email_enabled;
alter table public.profiles alter column avatar_url drop default;

create or replace function public.set_profile_password_hash()
returns trigger
language plpgsql
as $$
begin
  new.password_hash = public.hash_profile_password(new.password_hash);
  return new;
end;
$$;

drop trigger if exists set_profile_password_hash on public.profiles;
create trigger set_profile_password_hash
before insert or update of password_hash on public.profiles
for each row
execute function public.set_profile_password_hash();

update public.profiles
set phone = public.normalize_bahrain_phone(phone)
where phone is distinct from public.normalize_bahrain_phone(phone);

update public.profiles
set avatar_url = null
where avatar_url is null
   or btrim(avatar_url) = ''
   or avatar_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/profileimage.jpeg';

update public.profiles
set password_hash = public.hash_profile_password(password_hash)
where password_hash is distinct from public.hash_profile_password(password_hash);

update public.profiles profile
set
  auth_user_id = auth_user.id,
  email_verified_at = coalesce(auth_user.email_confirmed_at, profile.email_verified_at)
from auth.users auth_user
where lower(profile.email) = lower(auth_user.email)
  and (
    profile.auth_user_id is null
    or profile.auth_user_id = auth_user.id
  );

update public.profiles
set
  email = case
    when public.is_admin_owner_email(email) then 'admin.com'
    else email
  end,
  is_super_admin = public.is_admin_owner_email(email),
  role = case
    when public.is_admin_owner_email(email) then 'admin'::public.app_role
    else role
  end,
  is_active = case
    when public.is_admin_owner_email(email) then true
    else is_active
  end
where public.is_admin_owner_email(email)
   or coalesce(is_super_admin, false);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'p'
  ) then
    alter table public.profiles add primary key (id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_auth_user_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_auth_user_id_fkey
      foreign key (auth_user_id)
      references auth.users(id)
      on delete set null;
  end if;
end
$$;

-- NOTE: use a non-partial unique index so ON CONFLICT inference works reliably.
-- Multiple NULL auth_user_id values are still allowed by Postgres.
drop index if exists public.idx_profiles_auth_user_id;
create unique index if not exists idx_profiles_auth_user_id
  on public.profiles(auth_user_id);

create or replace function public.sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_email text := lower(btrim(coalesce(new.email, '')));
  v_metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_full_name text := btrim(
    coalesce(
      v_metadata ->> 'full_name',
      v_metadata ->> 'name',
      v_metadata ->> 'username',
      split_part(v_email, '@', 1),
      'Freshline User'
    )
  );
  v_username text := nullif(btrim(coalesce(v_metadata ->> 'username', '')), '');
  v_phone text := public.normalize_bahrain_phone(v_metadata ->> 'phone');
  v_city text := nullif(btrim(coalesce(v_metadata ->> 'city', '')), '');
  v_address text := nullif(btrim(coalesce(v_metadata ->> 'address', '')), '');
  v_avatar_url text := nullif(btrim(coalesce(v_metadata ->> 'avatar_url', '')), '');
  v_role_text text := lower(btrim(coalesce(v_metadata ->> 'role', 'customer')));
  v_role public.app_role := case
    when v_role_text in ('customer', 'salon_owner', 'admin', 'employee') then v_role_text::public.app_role
    else 'customer'::public.app_role
  end;
  v_profile_id uuid;
begin
  if v_email = '' then
    return new;
  end if;

  -- IMPORTANT: Never block Supabase Auth user creation.
  -- If profile sync fails for any reason (missing tables, enums, extensions,
  -- or schema drift), allow auth.users insert/update to succeed.
  begin

  -- Upsert by email (email is unique) and always bind auth_user_id to auth.users.id.
  insert into public.profiles (
    auth_user_id,
    role,
    full_name,
    username,
    email,
    email_verified_at,
    phone,
    city,
    address,
    avatar_url,
    is_active,
    is_super_admin
  )
  values (
    new.id,
    v_role,
    case
      when v_full_name = '' then 'Freshline User'
      else v_full_name
    end,
    v_username,
    v_email,
    new.email_confirmed_at,
    v_phone,
    coalesce(v_city, 'Manama'),
    v_address,
    v_avatar_url,
    true,
    false
  )
  on conflict (email) do update
  set
    auth_user_id = excluded.auth_user_id,
    email_verified_at = coalesce(excluded.email_verified_at, public.profiles.email_verified_at),
    full_name = case
      when btrim(coalesce(public.profiles.full_name, '')) = '' then excluded.full_name
      else public.profiles.full_name
    end,
    username = coalesce(public.profiles.username, excluded.username),
    phone = coalesce(public.profiles.phone, excluded.phone),
    city = coalesce(public.profiles.city, excluded.city),
    address = coalesce(public.profiles.address, excluded.address),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url);

  exception
    when others then
      return new;
  end;

  return new;
end;
$$;

create table if not exists public.platform_media_defaults (
  media_type text primary key check (media_type in ('profile', 'salon', 'product')),
  default_url text not null,
  updated_at timestamptz not null default now()
);

alter table public.platform_media_defaults add column if not exists media_type text;
alter table public.platform_media_defaults add column if not exists default_url text;
alter table public.platform_media_defaults add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if to_regclass('private.auth_email_otps') is null then
    return;
  end if;

  alter table private.auth_email_otps
    drop constraint if exists auth_email_otps_purpose_check;

  alter table private.auth_email_otps
    add constraint auth_email_otps_purpose_check
    check (
      purpose in (
        'email_verification',
        'two_factor_setup',
        'two_factor_sign_in',
        'password_reset'
      )
    );

  if to_regclass('public.profiles') is not null
     and not exists (
       select 1
       from pg_constraint
       where conrelid = 'private.auth_email_otps'::regclass
         and conname = 'auth_email_otps_profile_id_fkey'
     ) then
    alter table private.auth_email_otps
      add constraint auth_email_otps_profile_id_fkey
      foreign key (profile_id)
      references public.profiles(id)
      on delete cascade;
  end if;
exception
  when undefined_table then null;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_admin_owner_email_check'
  ) then
    alter table public.profiles
      add constraint profiles_admin_owner_email_check
      check (
        not is_super_admin
        or email = 'admin.com'
      ) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_admin_owner_state_check'
  ) then
    alter table public.profiles
      add constraint profiles_admin_owner_state_check
      check (
        email <> 'admin.com'
        or (
          role = 'admin'::public.app_role
          and is_super_admin
          and is_active
        )
      ) not valid;
  end if;
end
$$;

create table if not exists public.membership_plans (
  id text primary key,
  name text not null,
  name_ar text,
  price_bhd numeric(10,2) not null,
  loyalty_bonus_percent integer not null default 0,
  description text,
  description_ar text,
  created_at timestamptz not null default now()
);

create table if not exists public.customer_subscriptions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  plan_id text not null references public.membership_plans(id) on delete restrict,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  auto_renew boolean not null default true,
  payment_status public.payment_status not null default 'paid',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.membership_plans add column if not exists name_ar text;
alter table public.membership_plans add column if not exists description_ar text;

update public.membership_plans
set
  name_ar = case lower(id)
    when 'bronze' then 'برونزي'
    when 'silver' then 'فضي'
    when 'gold' then 'ذهبي'
    else name_ar
  end,
  description_ar = case lower(id)
    when 'bronze' then 'اشتراك أساسي مع نقاط ولاء إضافية'
    when 'silver' then 'الاشتراك الأكثر طلباً مع مزايا أقوى'
    when 'gold' then 'أعلى اشتراك مع أكبر نسبة مكافآت'
    else description_ar
  end
where name_ar is null
   or description_ar is null;

alter table public.customer_subscriptions add column if not exists auto_renew boolean not null default true;

update public.customer_subscriptions
set ends_at = coalesce(starts_at, created_at, now()) + interval '1 month'
where ends_at is null;

update public.customer_subscriptions
set auto_renew = true
where auto_renew is null;

create table if not exists public.loyalty_wallets (
  customer_id uuid primary key references public.profiles(id) on delete cascade,
  points_balance integer not null default 0,
  lifetime_points integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.loyalty_wallets add column if not exists customer_id uuid;
alter table public.loyalty_wallets add column if not exists points_balance integer not null default 0;
alter table public.loyalty_wallets add column if not exists lifetime_points integer not null default 0;
alter table public.loyalty_wallets add column if not exists updated_at timestamptz not null default now();

create table if not exists public.loyalty_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  source_type text not null,
  source_id uuid,
  points_delta integer not null,
  description text,
  created_at timestamptz not null default now()
);

alter table public.loyalty_transactions add column if not exists id uuid default gen_random_uuid();
alter table public.loyalty_transactions add column if not exists customer_id uuid;
alter table public.loyalty_transactions add column if not exists source_type text;
alter table public.loyalty_transactions add column if not exists source_id uuid;
alter table public.loyalty_transactions add column if not exists points_delta integer;
alter table public.loyalty_transactions add column if not exists description text;
alter table public.loyalty_transactions add column if not exists created_at timestamptz not null default now();

create table if not exists public.promo_coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  description text,
  description_ar text,
  discount_percent integer not null check (discount_percent > 0 and discount_percent <= 100),
  salon_id uuid,
  applicable_plan_id text references public.membership_plans(id) on delete set null,
  min_order_amount_bhd numeric(10,2),
  max_discount_amount numeric(10,2),
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.promo_coupons add column if not exists id uuid default gen_random_uuid();
alter table public.promo_coupons add column if not exists code text;
alter table public.promo_coupons add column if not exists description text;
alter table public.promo_coupons add column if not exists description_ar text;
alter table public.promo_coupons add column if not exists discount_percent integer;
alter table public.promo_coupons add column if not exists salon_id uuid;
alter table public.promo_coupons add column if not exists applicable_plan_id text;
alter table public.promo_coupons add column if not exists min_order_amount_bhd numeric(10,2);
alter table public.promo_coupons add column if not exists max_discount_amount numeric(10,2);
alter table public.promo_coupons add column if not exists is_active boolean not null default true;
alter table public.promo_coupons add column if not exists starts_at timestamptz;
alter table public.promo_coupons add column if not exists ends_at timestamptz;
alter table public.promo_coupons add column if not exists created_at timestamptz not null default now();
alter table public.promo_coupons add column if not exists updated_at timestamptz not null default now();

update public.promo_coupons
set description_ar = case upper(code)
  when 'FRESH20' then 'خصم ترحيبي 20٪ للطلب الأول فقط.'
  else description_ar
end
where description_ar is null;

-- Admin coupon SQL helpers for Supabase SQL Editor.
-- Examples:
-- select * from public.admin_upsert_coupon('EID25', 25, 'Eid offer', null, 10, null, true, now(), now() + interval '7 days');
-- select public.admin_delete_coupon('EID25');
-- select code, discount_percent, is_active, starts_at, ends_at
-- from public.promo_coupons
-- order by updated_at desc nulls last, created_at desc;
create or replace function public.admin_upsert_coupon(
  p_code text,
  p_discount_percent integer,
  p_description text default null,
  p_applicable_plan_id text default null,
  p_min_order_amount_bhd numeric default null,
  p_max_discount_amount numeric default null,
  p_is_active boolean default true,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null
)
returns public.promo_coupons
language plpgsql
as $$
declare
  v_coupon public.promo_coupons;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_plan_id text := nullif(lower(btrim(coalesce(p_applicable_plan_id, ''))), '');
begin
  if v_code = '' then
    raise exception 'Coupon code is required.';
  end if;

  if p_discount_percent is null
     or p_discount_percent < 1
     or p_discount_percent > 100 then
    raise exception 'Discount percent must be between 1 and 100.';
  end if;

  if p_starts_at is not null
     and p_ends_at is not null
     and p_ends_at < p_starts_at then
    raise exception 'Coupon end date must be after the start date.';
  end if;

  insert into public.promo_coupons (
    code,
    description,
    discount_percent,
    applicable_plan_id,
    min_order_amount_bhd,
    max_discount_amount,
    is_active,
    starts_at,
    ends_at
  )
  values (
    v_code,
    nullif(btrim(coalesce(p_description, '')), ''),
    p_discount_percent,
    v_plan_id,
    case
      when coalesce(p_min_order_amount_bhd, 0) <= 0 then null
      else round(p_min_order_amount_bhd, 2)
    end,
    case
      when coalesce(p_max_discount_amount, 0) <= 0 then null
      else round(p_max_discount_amount, 2)
    end,
    coalesce(p_is_active, true),
    p_starts_at,
    p_ends_at
  )
  on conflict (code) do update
  set
    description = excluded.description,
    discount_percent = excluded.discount_percent,
    applicable_plan_id = excluded.applicable_plan_id,
    min_order_amount_bhd = excluded.min_order_amount_bhd,
    max_discount_amount = excluded.max_discount_amount,
    is_active = excluded.is_active,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    updated_at = now()
  returning * into v_coupon;

  return v_coupon;
end;
$$;

create or replace function public.admin_delete_coupon(p_code text)
returns boolean
language plpgsql
as $$
declare
  v_deleted_count integer;
begin
  delete from public.promo_coupons
  where upper(code) = upper(btrim(coalesce(p_code, '')));

  get diagnostics v_deleted_count = row_count;
  return v_deleted_count > 0;
end;
$$;

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  label text not null default 'Home',
  full_name text,
  phone text,
  city text,
  address_line text not null,
  additional_notes text,
  latitude numeric(10,6),
  longitude numeric(10,6),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.customer_addresses add column if not exists id uuid default gen_random_uuid();
alter table public.customer_addresses add column if not exists customer_id uuid;
alter table public.customer_addresses add column if not exists label text not null default 'Home';
alter table public.customer_addresses add column if not exists full_name text;
alter table public.customer_addresses add column if not exists phone text;
alter table public.customer_addresses add column if not exists city text;
alter table public.customer_addresses add column if not exists address_line text;
alter table public.customer_addresses add column if not exists additional_notes text;
alter table public.customer_addresses add column if not exists latitude numeric(10,6);
alter table public.customer_addresses add column if not exists longitude numeric(10,6);
alter table public.customer_addresses add column if not exists is_default boolean not null default false;
alter table public.customer_addresses add column if not exists created_at timestamptz not null default now();
alter table public.customer_addresses add column if not exists updated_at timestamptz not null default now();

update public.customer_addresses
set phone = public.normalize_bahrain_phone(phone)
where phone is distinct from public.normalize_bahrain_phone(phone);

create table if not exists public.saved_cards (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  cardholder_name text,
  brand text,
  last4 text not null,
  expiry_month smallint,
  expiry_year smallint,
  token_reference text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.saved_cards add column if not exists customer_id uuid;
alter table public.saved_cards add column if not exists cardholder_name text;
alter table public.saved_cards add column if not exists brand text;
alter table public.saved_cards add column if not exists last4 text;
alter table public.saved_cards add column if not exists expiry_month smallint;
alter table public.saved_cards add column if not exists expiry_year smallint;
alter table public.saved_cards add column if not exists token_reference text;
alter table public.saved_cards add column if not exists is_default boolean not null default false;
alter table public.saved_cards add column if not exists created_at timestamptz not null default now();
alter table public.saved_cards add column if not exists updated_at timestamptz not null default now();

create table if not exists public.salon_applications (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  salon_name text not null,
  business_email text,
  username text,
  phone text,
  city text not null,
  address text not null,
  website_url text,
  location_url text not null,
  salon_image_url text,
  commercial_registration_pdf_url text not null,
  government_license_pdf_url text not null,
  status public.request_status not null default 'pending',
  admin_note text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.salon_applications add column if not exists owner_id uuid;
alter table public.salon_applications add column if not exists salon_name text default '';
alter table public.salon_applications add column if not exists business_email text;
alter table public.salon_applications add column if not exists username text;
alter table public.salon_applications add column if not exists phone text;
alter table public.salon_applications add column if not exists city text default 'Manama';
alter table public.salon_applications add column if not exists address text default '';
alter table public.salon_applications add column if not exists website_url text;
alter table public.salon_applications add column if not exists location_url text default '';
alter table public.salon_applications add column if not exists salon_image_url text;
alter table public.salon_applications add column if not exists commercial_registration_pdf_url text default '';
alter table public.salon_applications add column if not exists government_license_pdf_url text default '';
alter table public.salon_applications add column if not exists status public.request_status default 'pending';
alter table public.salon_applications add column if not exists admin_note text;
alter table public.salon_applications add column if not exists reviewed_by uuid;
alter table public.salon_applications add column if not exists reviewed_at timestamptz;
alter table public.salon_applications add column if not exists created_at timestamptz not null default now();
alter table public.salon_applications add column if not exists updated_at timestamptz not null default now();

update public.salon_applications
set phone = public.normalize_bahrain_phone(phone)
where phone is distinct from public.normalize_bahrain_phone(phone);

create table if not exists public.salons (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  application_id uuid references public.salon_applications(id) on delete set null,
  slug text unique,
  name text not null,
  name_ar text,
  description text,
  description_ar text,
  city text not null,
  city_ar text,
  address text,
  address_ar text,
  phone text,
  website_url text,
  location_url text,
  image_url text,
  latitude numeric(10,6),
  longitude numeric(10,6),
  price_tier text default '$$',
  supports_home_service boolean not null default false,
  rating numeric(2,1) not null default 0,
  reviews_count integer not null default 0,
  is_active boolean not null default true,
  subscription_cycle public.subscription_cycle,
  subscription_amount_bhd numeric(10,2),
  subscription_paid_until date,
  subscription_auto_renew boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.salons add column if not exists owner_id uuid;
alter table public.salons add column if not exists application_id uuid;
alter table public.salons add column if not exists slug text;
alter table public.salons add column if not exists name text default '';
alter table public.salons add column if not exists name_ar text;
alter table public.salons add column if not exists description text;
alter table public.salons add column if not exists description_ar text;
alter table public.salons add column if not exists city text default 'Manama';
alter table public.salons add column if not exists city_ar text;
alter table public.salons add column if not exists address text;
alter table public.salons add column if not exists address_ar text;
alter table public.salons add column if not exists phone text;
alter table public.salons add column if not exists website_url text;
alter table public.salons add column if not exists location_url text;
alter table public.salons add column if not exists image_url text;
alter table public.salons add column if not exists latitude numeric(10,6);
alter table public.salons add column if not exists longitude numeric(10,6);
alter table public.salons add column if not exists price_tier text default '$$';
alter table public.salons add column if not exists supports_home_service boolean not null default false;
alter table public.salons add column if not exists rating numeric(2,1) not null default 0;
alter table public.salons add column if not exists reviews_count integer not null default 0;
alter table public.salons add column if not exists is_active boolean not null default true;
alter table public.salons add column if not exists subscription_cycle public.subscription_cycle;
alter table public.salons add column if not exists subscription_amount_bhd numeric(10,2);
alter table public.salons add column if not exists subscription_paid_until date;
alter table public.salons add column if not exists subscription_auto_renew boolean not null default false;
alter table public.salons add column if not exists created_at timestamptz not null default now();
alter table public.salons add column if not exists updated_at timestamptz not null default now();

update public.salons
set phone = public.normalize_bahrain_phone(phone)
where phone is distinct from public.normalize_bahrain_phone(phone);

update public.salons
set subscription_cycle = 'monthly'
where subscription_cycle is null
  and is_active = true;

update public.salons
set subscription_amount_bhd = case
  when subscription_cycle = 'yearly' then 280
  else 30
end
where subscription_amount_bhd is null
   or subscription_amount_bhd = 300;

update public.salons
set subscription_paid_until = case
  when subscription_cycle = 'yearly' then (current_date + interval '1 year')::date
  else (current_date + interval '1 month')::date
end
where subscription_paid_until is null
  and is_active = true;

update public.salons
set subscription_auto_renew = false
where subscription_auto_renew is null;

update public.salons
set
  name_ar = case slug
    when 'freshline-signature-lounge' then 'فريش لاين سيغنتشر لاونج'
    when 'trim-and-tone-studio' then 'استوديو تريم آند تون'
    when 'royal-blade-house' then 'رويال بليد هاوس'
    else name_ar
  end,
  description_ar = case slug
    when 'freshline-signature-lounge' then 'صالة عناية راقية تقدم قصات مميزة وخدمة لحية ومواعيد منزلية.'
    when 'trim-and-tone-studio' then 'استوديو حلاقة حديث يركز على التدريجات والتصفيف والمواعيد السريعة.'
    when 'royal-blade-house' then 'بيت حلاقة فاخر يقدم باقات علاجية وتوصيات للعناية اللاحقة.'
    else description_ar
  end,
  city_ar = case city
    when 'Manama' then 'المنامة'
    else city_ar
  end,
  address_ar = case address
    when 'Road 2819, Seef District, Manama' then 'طريق 2819، منطقة السيف، المنامة'
    when 'Road 3801, Adliya, Manama' then 'طريق 3801، العدلية، المنامة'
    when 'Al Shabab Ave, Juffair, Manama' then 'شارع الشباب، الجفير، المنامة'
    else address_ar
  end
where name_ar is null
   or description_ar is null
   or city_ar is null
   or address_ar is null;

create table if not exists public.salon_packages (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  name text not null,
  name_ar text,
  description text,
  description_ar text,
  price_bhd numeric(10,2) not null default 0,
  duration_minutes integer not null default 30,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.salon_services (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  name text not null,
  name_ar text,
  description text,
  description_ar text,
  price_bhd numeric(10,2) not null default 0,
  duration_minutes integer not null default 30,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.salon_packages add column if not exists id uuid default gen_random_uuid();
alter table public.salon_packages add column if not exists salon_id uuid;
alter table public.salon_packages add column if not exists name text default '';
alter table public.salon_packages add column if not exists name_ar text;
alter table public.salon_packages add column if not exists description text;
alter table public.salon_packages add column if not exists description_ar text;
alter table public.salon_packages add column if not exists price_bhd numeric(10,2) not null default 0;
alter table public.salon_packages add column if not exists duration_minutes integer not null default 30;
alter table public.salon_packages add column if not exists is_active boolean not null default true;
alter table public.salon_packages add column if not exists created_at timestamptz not null default now();
alter table public.salon_packages add column if not exists updated_at timestamptz not null default now();

alter table public.salon_services add column if not exists id uuid default gen_random_uuid();
alter table public.salon_services add column if not exists salon_id uuid;
alter table public.salon_services add column if not exists name text default '';
alter table public.salon_services add column if not exists name_ar text;
alter table public.salon_services add column if not exists description text;
alter table public.salon_services add column if not exists description_ar text;
alter table public.salon_services add column if not exists price_bhd numeric(10,2) not null default 0;
alter table public.salon_services add column if not exists duration_minutes integer not null default 30;
alter table public.salon_services add column if not exists is_active boolean not null default true;
alter table public.salon_services add column if not exists created_at timestamptz not null default now();
alter table public.salon_services add column if not exists updated_at timestamptz not null default now();

update public.salon_packages
set
  name_ar = case name
    when 'Basic Cut' then 'قص أساسي'
    when 'Premium Styling' then 'تصفيف فاخر'
    when 'VIP Package' then 'باقة كبار الشخصيات'
    else name_ar
  end,
  description_ar = case description
    when 'Professional haircut with wash' then 'قص شعر احترافي مع غسيل'
    when 'Cut, wash, style & finish' then 'قص وغسيل وتصفيف ولمسة نهائية'
    when 'Full service: cut, color, style, beard' then 'خدمة كاملة: قص ولون وتصفيف ولحية'
    else description_ar
  end
where name_ar is null
   or description_ar is null;

update public.salon_services
set
  name_ar = case name
    when 'Haircut' then 'قص شعر'
    when 'Beard Trim' then 'تشذيب اللحية'
    when 'Hair Color' then 'صبغة شعر'
    when 'Hot Towel Shave' then 'حلاقة بمنشفة ساخنة'
    when 'Deep Conditioning' then 'ترطيب عميق'
    when 'Home Visit' then 'زيارة منزلية'
    when 'Kids Cut' then 'قص أطفال'
    when 'Full Service' then 'خدمة كاملة'
    when 'Spa Treatment' then 'علاج سبا'
    else name_ar
  end,
  description_ar = coalesce(description_ar, description)
where name_ar is null
   or description_ar is null;

create table if not exists public.salon_employees (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  full_name text not null,
  role_title text,
  phone text,
  email text,
  image_url text,
  rating numeric(2,1) not null default 0,
  reviews_count integer not null default 0,
  monthly_salary_bhd numeric(10,2) not null default 0,
  supports_in_shop boolean not null default true,
  supports_home_service boolean not null default false,
  can_login boolean not null default false,
  work_start_time time,
  work_end_time time,
  break_start_time time,
  break_end_time time,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.salon_employees add column if not exists profile_id uuid references public.profiles(id) on delete set null;
alter table public.salon_employees add column if not exists full_name text default '';
alter table public.salon_employees add column if not exists role_title text;
alter table public.salon_employees add column if not exists phone text;
alter table public.salon_employees add column if not exists email text;
alter table public.salon_employees add column if not exists image_url text;
alter table public.salon_employees add column if not exists rating numeric(2,1) not null default 0;
alter table public.salon_employees add column if not exists reviews_count integer not null default 0;
alter table public.salon_employees add column if not exists monthly_salary_bhd numeric(10,2) not null default 0;
alter table public.salon_employees add column if not exists salary_paid_for_month date;
alter table public.salon_employees add column if not exists salary_last_paid_at timestamptz;
alter table public.salon_employees add column if not exists supports_in_shop boolean not null default true;
alter table public.salon_employees add column if not exists supports_home_service boolean not null default false;
alter table public.salon_employees add column if not exists can_login boolean not null default false;
alter table public.salon_employees add column if not exists work_start_time time;
alter table public.salon_employees add column if not exists work_end_time time;
alter table public.salon_employees add column if not exists break_start_time time;
alter table public.salon_employees add column if not exists break_end_time time;
alter table public.salon_employees add column if not exists is_active boolean not null default true;
alter table public.salon_employees add column if not exists created_at timestamptz not null default now();
alter table public.salon_employees add column if not exists updated_at timestamptz not null default now();

update public.salon_employees
set phone = public.normalize_bahrain_phone(phone)
where phone is distinct from public.normalize_bahrain_phone(phone);

update public.salon_employees
set full_name = 'Freshline Employee'
where full_name is null
   or btrim(full_name) = '';

update public.salon_employees
set rating = 0
where rating is null;

update public.salon_employees
set reviews_count = 0
where reviews_count is null;

update public.salons
set rating = 0,
    reviews_count = 0
where rating is null
   or reviews_count is null;

do $$
begin
  if to_regclass('public.products') is not null then
    update public.products
    set rating = 0,
        reviews_count = 0
    where rating is null
       or reviews_count is null;
  end if;
end
$$;

create table if not exists public.employee_schedules (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.salon_employees(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  supports_home_service boolean not null default false,
  supports_in_shop boolean not null default true,
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.employee_salary_payments (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  employee_id uuid not null references public.salon_employees(id) on delete cascade,
  confirmed_by uuid references public.profiles(id) on delete set null,
  amount_bhd numeric(10,2) not null default 0,
  salary_month date not null,
  confirmed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.employee_salary_payments add column if not exists id uuid default gen_random_uuid();
alter table public.employee_salary_payments add column if not exists salon_id uuid;
alter table public.employee_salary_payments add column if not exists employee_id uuid;
alter table public.employee_salary_payments add column if not exists confirmed_by uuid;
alter table public.employee_salary_payments add column if not exists amount_bhd numeric(10,2) not null default 0;
alter table public.employee_salary_payments add column if not exists salary_month date;
alter table public.employee_salary_payments add column if not exists confirmed_at timestamptz not null default now();
alter table public.employee_salary_payments add column if not exists created_at timestamptz not null default now();

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid references public.salons(id) on delete set null,
  slug text unique,
  name text not null,
  name_ar text,
  category text,
  category_ar text,
  description text,
  description_ar text,
  price numeric(10,2) not null default 0,
  rating numeric(2,1) not null default 0,
  reviews_count integer not null default 0,
  stock integer not null default 0,
  image_url text,
  is_active boolean not null default true,
  bestseller_rank integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products add column if not exists salon_id uuid;
alter table public.products add column if not exists slug text;
alter table public.products add column if not exists name_ar text;
alter table public.products add column if not exists category text;
alter table public.products add column if not exists category_ar text;
alter table public.products add column if not exists description text;
alter table public.products add column if not exists description_ar text;
alter table public.products add column if not exists price numeric(10,2) not null default 0;
alter table public.products add column if not exists rating numeric(2,1) not null default 0;
alter table public.products add column if not exists reviews_count integer not null default 0;
alter table public.products add column if not exists stock integer not null default 0;
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists is_active boolean not null default true;
alter table public.products add column if not exists bestseller_rank integer;
alter table public.products add column if not exists created_at timestamptz not null default now();
alter table public.products add column if not exists updated_at timestamptz not null default now();
alter table public.salons alter column image_url drop default;
alter table public.products alter column image_url drop default;

update public.salons
set image_url = null
where image_url is null
   or btrim(image_url) = ''
   or image_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/dd.png'
   or image_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/FrslineS.png'
   or image_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/defaultimage.jpeg';

update public.products
set image_url = null
where image_url is null
   or btrim(image_url) = ''
   or image_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/dd.png'
   or image_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/FrslineP.png'
   or image_url = 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/defaultimage.jpeg';

update public.products
set
  name_ar = case slug
    when 'premium-hair-kit' then 'مجموعة الشعر الفاخرة'
    when 'styling-cream' then 'كريم التصفيف'
    when 'argan-hair-serum' then 'سيروم الأرغان للشعر'
    when 'beard-care-balm' then 'بلسم العناية باللحية'
    else name_ar
  end,
  category_ar = case category
    when 'Hair Care' then 'العناية بالشعر'
    when 'Styling' then 'التصفيف'
    when 'Treatment' then 'العلاج'
    when 'Beard Care' then 'العناية باللحية'
    else category_ar
  end,
  description_ar = case slug
    when 'premium-hair-kit' then 'مجموعة يومية متكاملة للعناية بالشعر تشمل الغسل والعلاج واللمسة النهائية.'
    when 'styling-cream' then 'كريم تصفيف خفيف بثبات نظيف وملمس طبيعي.'
    when 'argan-hair-serum' then 'سيروم مغذٍ ينعّم الهيشان ويدعم تعافي الشعر الجاف.'
    when 'beard-care-balm' then 'بلسم ملطف للحية مصمم للعناية اليومية وإضافة اللمعان.'
    else description_ar
  end
where name_ar is null
   or category_ar is null
   or description_ar is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_bahrain_phone_check'
  ) then
    alter table public.profiles
      add constraint profiles_bahrain_phone_check
      check (public.is_valid_bahrain_phone(phone)) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.customer_addresses'::regclass
      and conname = 'customer_addresses_bahrain_phone_check'
  ) then
    alter table public.customer_addresses
      add constraint customer_addresses_bahrain_phone_check
      check (public.is_valid_bahrain_phone(phone)) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salon_applications'::regclass
      and conname = 'salon_applications_bahrain_phone_check'
  ) then
    alter table public.salon_applications
      add constraint salon_applications_bahrain_phone_check
      check (public.is_valid_bahrain_phone(phone)) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salons'::regclass
      and conname = 'salons_bahrain_phone_check'
  ) then
    alter table public.salons
      add constraint salons_bahrain_phone_check
      check (public.is_valid_bahrain_phone(phone)) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salon_employees'::regclass
      and conname = 'salon_employees_bahrain_phone_check'
  ) then
    alter table public.salon_employees
      add constraint salon_employees_bahrain_phone_check
      check (public.is_valid_bahrain_phone(phone)) not valid;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_email_key'
  ) then
    alter table public.profiles add constraint profiles_email_key unique (email);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salons'::regclass
      and conname = 'salons_slug_key'
  ) then
    alter table public.salons add constraint salons_slug_key unique (slug);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.products'::regclass
      and conname = 'products_slug_key'
  ) then
    alter table public.products add constraint products_slug_key unique (slug);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.promo_coupons'::regclass
      and conname = 'promo_coupons_code_key'
  ) then
    alter table public.promo_coupons add constraint promo_coupons_code_key unique (code);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.promo_coupons'::regclass
      and conname = 'promo_coupons_applicable_plan_id_fkey'
  ) then
    alter table public.promo_coupons
      add constraint promo_coupons_applicable_plan_id_fkey
      foreign key (applicable_plan_id)
      references public.membership_plans(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.promo_coupons'::regclass
      and conname = 'promo_coupons_salon_id_fkey'
  ) then
    alter table public.promo_coupons
      add constraint promo_coupons_salon_id_fkey
      foreign key (salon_id)
      references public.salons(id)
      on delete cascade;
  end if;

  if to_regclass('public.device_push_tokens') is not null
     and not exists (
       select 1
       from pg_constraint
       where conrelid = to_regclass('public.device_push_tokens')
         and conname = 'device_push_tokens_fcm_token_key'
     ) then
    alter table public.device_push_tokens
      add constraint device_push_tokens_fcm_token_key unique (fcm_token);
  end if;

  if to_regclass('public.device_push_tokens') is not null
     and not exists (
       select 1
       from pg_constraint
       where conrelid = to_regclass('public.device_push_tokens')
         and conname = 'device_push_tokens_profile_id_fkey'
     ) then
    alter table public.device_push_tokens
      add constraint device_push_tokens_profile_id_fkey
      foreign key (profile_id)
      references public.profiles(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salon_packages'::regclass
      and conname = 'salon_packages_salon_id_fkey'
  ) then
    alter table public.salon_packages
      add constraint salon_packages_salon_id_fkey
      foreign key (salon_id)
      references public.salons(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salon_services'::regclass
      and conname = 'salon_services_salon_id_fkey'
  ) then
    alter table public.salon_services
      add constraint salon_services_salon_id_fkey
      foreign key (salon_id)
      references public.salons(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.employee_salary_payments'::regclass
      and conname = 'employee_salary_payments_salon_id_fkey'
  ) then
    alter table public.employee_salary_payments
      add constraint employee_salary_payments_salon_id_fkey
      foreign key (salon_id)
      references public.salons(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.employee_salary_payments'::regclass
      and conname = 'employee_salary_payments_employee_id_fkey'
  ) then
    alter table public.employee_salary_payments
      add constraint employee_salary_payments_employee_id_fkey
      foreign key (employee_id)
      references public.salon_employees(id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.employee_salary_payments'::regclass
      and conname = 'employee_salary_payments_confirmed_by_fkey'
  ) then
    alter table public.employee_salary_payments
      add constraint employee_salary_payments_confirmed_by_fkey
      foreign key (confirmed_by)
      references public.profiles(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.employee_salary_payments'::regclass
      and conname = 'employee_salary_payments_employee_id_salary_month_key'
  ) then
    alter table public.employee_salary_payments
      add constraint employee_salary_payments_employee_id_salary_month_key
      unique (employee_id, salary_month);
  end if;
end
$$;

create or replace function public.refresh_salon_review_summary(p_salon_id uuid)
returns void
language plpgsql
as $$
declare
  v_reviews_count integer := 0;
  v_rating numeric(2,1) := 0;
begin
  if p_salon_id is null then
    return;
  end if;

  select
    count(*)::integer,
    coalesce(round(avg(salon_rating)::numeric, 1), 0)
  into v_reviews_count, v_rating
  from public.salon_reviews
  where salon_id = p_salon_id;

  update public.salons
  set
    rating = v_rating,
    reviews_count = v_reviews_count,
    updated_at = now()
  where id = p_salon_id;
end;
$$;

create or replace function public.refresh_employee_review_summary(p_employee_id uuid)
returns void
language plpgsql
as $$
declare
  v_reviews_count integer := 0;
  v_rating numeric(2,1) := 0;
begin
  if p_employee_id is null then
    return;
  end if;

  select
    count(*)::integer,
    coalesce(round(avg(employee_rating)::numeric, 1), 0)
  into v_reviews_count, v_rating
  from public.salon_reviews
  where employee_id = p_employee_id;

  update public.salon_employees
  set
    rating = v_rating,
    reviews_count = v_reviews_count,
    updated_at = now()
  where id = p_employee_id;
end;
$$;

create or replace function public.refresh_product_review_summary(p_product_id uuid)
returns void
language plpgsql
as $$
declare
  v_reviews_count integer := 0;
  v_rating numeric(2,1) := 0;
begin
  if p_product_id is null then
    return;
  end if;

  select
    count(*)::integer,
    coalesce(round(avg(rating)::numeric, 1), 0)
  into v_reviews_count, v_rating
  from public.product_reviews
  where product_id = p_product_id;

  update public.products
  set
    rating = v_rating,
    reviews_count = v_reviews_count,
    updated_at = now()
  where id = p_product_id;
end;
$$;

create or replace function public.handle_salon_review_summary_refresh()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_salon_review_summary(old.salon_id);
    perform public.refresh_employee_review_summary(old.employee_id);
    return old;
  end if;

  if tg_op = 'UPDATE' then
    if old.salon_id is distinct from new.salon_id then
      perform public.refresh_salon_review_summary(old.salon_id);
    end if;
    if old.employee_id is distinct from new.employee_id then
      perform public.refresh_employee_review_summary(old.employee_id);
    end if;
  end if;

  perform public.refresh_salon_review_summary(new.salon_id);
  perform public.refresh_employee_review_summary(new.employee_id);
  return new;
end;
$$;

create or replace function public.handle_product_review_summary_refresh()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_product_review_summary(old.product_id);
    return old;
  end if;

  if tg_op = 'UPDATE'
     and old.product_id is distinct from new.product_id then
    perform public.refresh_product_review_summary(old.product_id);
  end if;

  perform public.refresh_product_review_summary(new.product_id);
  return new;
end;
$$;

create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  unit_price numeric(10,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  address_id uuid references public.customer_addresses(id) on delete set null,
  payment_status public.payment_status not null default 'pending',
  subtotal_amount numeric(10,2) not null default 0,
  delivery_amount numeric(10,2) not null default 0,
  discount_amount numeric(10,2) not null default 0,
  coupon_code text references public.promo_coupons(code) on delete set null,
  coupon_discount_amount numeric(10,2) not null default 0,
  loyalty_points_redeemed integer not null default 0,
  loyalty_discount_amount numeric(10,2) not null default 0,
  tax_amount numeric(10,2) not null default 0,
  total_amount numeric(10,2) not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.product_orders add column if not exists id uuid default gen_random_uuid();
alter table public.product_orders add column if not exists order_number text;
alter table public.product_orders add column if not exists customer_id uuid;
alter table public.product_orders add column if not exists address_id uuid;
alter table public.product_orders add column if not exists payment_status public.payment_status default 'pending';
alter table public.product_orders add column if not exists subtotal_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists delivery_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists discount_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists coupon_code text;
alter table public.product_orders add column if not exists coupon_discount_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists loyalty_points_redeemed integer not null default 0;
alter table public.product_orders add column if not exists loyalty_discount_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists tax_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists total_amount numeric(10,2) not null default 0;
alter table public.product_orders add column if not exists notes text;
alter table public.product_orders add column if not exists created_at timestamptz not null default now();
alter table public.product_orders add column if not exists updated_at timestamptz not null default now();

create table if not exists public.product_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.product_orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  product_name_ar text,
  quantity integer not null default 1 check (quantity > 0),
  unit_price numeric(10,2) not null default 0,
  line_total numeric(10,2) not null default 0,
  created_at timestamptz not null default now()
);

alter table public.product_order_items add column if not exists id uuid default gen_random_uuid();
alter table public.product_order_items add column if not exists order_id uuid;
alter table public.product_order_items add column if not exists product_id uuid;
alter table public.product_order_items add column if not exists product_name text;
alter table public.product_order_items add column if not exists product_name_ar text;
alter table public.product_order_items add column if not exists quantity integer not null default 1;
alter table public.product_order_items add column if not exists unit_price numeric(10,2) not null default 0;
alter table public.product_order_items add column if not exists line_total numeric(10,2) not null default 0;
alter table public.product_order_items add column if not exists created_at timestamptz not null default now();

create or replace function public.reserve_product_order_stock(p_items jsonb)
returns table(product_id uuid, remaining_stock integer)
language plpgsql
as $$
declare
  item jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_product record;
begin
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one product item is required.';
  end if;

  for item in select value from jsonb_array_elements(p_items) loop
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_quantity := greatest(coalesce((item->>'quantity')::integer, 0), 0);

    if v_product_id is null then
      raise exception 'Product id is required.';
    end if;

    if v_quantity <= 0 then
      raise exception 'Product quantity must be greater than zero.';
    end if;

    select id, name, stock, is_active
    into v_product
    from public.products
    where id = v_product_id
    for update;

    if not found then
      raise exception 'One of the selected products could not be found.';
    end if;

    if coalesce(v_product.is_active, false) = false then
      raise exception '% is not available right now.', v_product.name;
    end if;

    if coalesce(v_product.stock, 0) < v_quantity then
      raise exception '% only has % item(s) left.', v_product.name, coalesce(v_product.stock, 0);
    end if;
  end loop;

  for item in select value from jsonb_array_elements(p_items) loop
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_quantity := greatest(coalesce((item->>'quantity')::integer, 0), 0);

    update public.products
    set stock = stock - v_quantity,
        updated_at = now()
    where id = v_product_id
    returning id, stock into product_id, remaining_stock;

    return next;
  end loop;
end;
$$;

create or replace function public.restore_product_order_stock(p_items jsonb)
returns void
language plpgsql
as $$
declare
  item jsonb;
  v_product_id uuid;
  v_quantity integer;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return;
  end if;

  for item in select value from jsonb_array_elements(p_items) loop
    v_product_id := nullif(item->>'product_id', '')::uuid;
    v_quantity := greatest(coalesce((item->>'quantity')::integer, 0), 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    update public.products
    set stock = stock + v_quantity,
        updated_at = now()
    where id = v_product_id;
  end loop;
end;
$$;

-- If an earlier iteration accidentally created `salon_bookings` as a view,
-- PostgREST will reject inserts with "Unsupported operation: insert".
-- Convert it back to a real table (safe no-op when it is already a table).
do $$
declare
  relation_kind "char";
begin
  select c.relkind
  into relation_kind
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'salon_bookings';

  if relation_kind in ('v', 'm') then
    execute 'drop view if exists public.salon_bookings cascade';
    execute 'drop materialized view if exists public.salon_bookings cascade';
  end if;
end
$$;

create table if not exists public.salon_bookings (
  id uuid primary key default gen_random_uuid(),
  booking_number text unique,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  salon_id uuid not null references public.salons(id) on delete restrict,
  package_id uuid references public.salon_packages(id) on delete set null,
  service_id uuid references public.salon_services(id) on delete set null,
  employee_id uuid references public.salon_employees(id) on delete set null,
  visit_mode public.visit_mode not null,
  address_id uuid references public.customer_addresses(id) on delete set null,
  manual_address text,
  appointment_at timestamptz not null,
  booking_status public.booking_status not null default 'pending',
  payment_status public.payment_status not null default 'pending',
  subtotal_amount numeric(10,2) not null default 0,
  discount_amount numeric(10,2) not null default 0,
  total_amount numeric(10,2) not null default 0,
  loyalty_points_earned integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.salon_bookings add column if not exists id uuid default gen_random_uuid();
alter table public.salon_bookings add column if not exists booking_number text;
alter table public.salon_bookings add column if not exists customer_id uuid;
alter table public.salon_bookings add column if not exists salon_id uuid;
alter table public.salon_bookings add column if not exists package_id uuid;
alter table public.salon_bookings add column if not exists service_id uuid;
alter table public.salon_bookings add column if not exists employee_id uuid;
alter table public.salon_bookings add column if not exists visit_mode public.visit_mode;
alter table public.salon_bookings add column if not exists address_id uuid;
alter table public.salon_bookings add column if not exists manual_address text;
alter table public.salon_bookings add column if not exists appointment_at timestamptz;
alter table public.salon_bookings add column if not exists booking_status public.booking_status default 'pending';
alter table public.salon_bookings add column if not exists payment_status public.payment_status default 'pending';
alter table public.salon_bookings add column if not exists subtotal_amount numeric(10,2) not null default 0;
alter table public.salon_bookings add column if not exists discount_amount numeric(10,2) not null default 0;
alter table public.salon_bookings add column if not exists total_amount numeric(10,2) not null default 0;
alter table public.salon_bookings add column if not exists loyalty_points_earned integer not null default 0;
alter table public.salon_bookings add column if not exists notes text;
alter table public.salon_bookings add column if not exists created_at timestamptz not null default now();
alter table public.salon_bookings add column if not exists updated_at timestamptz not null default now();

create table if not exists public.salon_reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.salon_bookings(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  salon_id uuid not null references public.salons(id) on delete cascade,
  employee_id uuid references public.salon_employees(id) on delete set null,
  salon_rating smallint not null check (salon_rating between 1 and 5),
  employee_rating smallint not null check (employee_rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.product_orders(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salon_reviews'::regclass
      and conname = 'salon_reviews_booking_id_key'
  ) then
    alter table public.salon_reviews
      add constraint salon_reviews_booking_id_key unique (booking_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.product_reviews'::regclass
      and conname = 'product_reviews_order_id_product_id_key'
  ) then
    alter table public.product_reviews
      add constraint product_reviews_order_id_product_id_key
      unique (order_id, product_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.product_orders'::regclass
      and conname = 'product_orders_order_number_key'
  ) then
    alter table public.product_orders
      add constraint product_orders_order_number_key unique (order_number);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.salon_bookings'::regclass
      and conname = 'salon_bookings_booking_number_key'
  ) then
    alter table public.salon_bookings
      add constraint salon_bookings_booking_number_key unique (booking_number);
  end if;
end
$$;

create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  salon_id uuid references public.salons(id) on delete set null,
  source_table text not null,
  source_id uuid not null,
  gateway_name text,
  amount numeric(10,2) not null default 0,
  currency_code text not null default 'BHD',
  payment_status public.payment_status not null default 'pending',
  external_reference text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  title_ar text,
  body text not null,
  body_ar text,
  audience public.notification_audience not null,
  target_profile_id uuid references public.profiles(id) on delete cascade,
  target_salon_id uuid references public.salons(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  is_read boolean not null default false,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications add column if not exists title_ar text;
alter table public.notifications add column if not exists body_ar text;

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null unique,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_push_tokens add column if not exists id uuid default gen_random_uuid();
alter table public.device_push_tokens add column if not exists profile_id uuid;
alter table public.device_push_tokens add column if not exists fcm_token text;
alter table public.device_push_tokens add column if not exists last_seen_at timestamptz not null default now();
alter table public.device_push_tokens add column if not exists created_at timestamptz not null default now();
alter table public.device_push_tokens add column if not exists updated_at timestamptz not null default now();

create or replace function public.notify_product_order_created()
returns trigger
language plpgsql
as $$
begin
  insert into public.notifications (
    title,
    title_ar,
    body,
    body_ar,
    audience,
    target_profile_id,
    sent_at
  )
  values (
    'Product Order Received',
    'تم استلام طلب المنتج',
    'Your product order ' || coalesce(new.order_number, left(new.id::text, 8)) || ' was received successfully.',
    'تم استلام طلب المنتج الخاص بك ' || coalesce(new.order_number, left(new.id::text, 8)) || ' بنجاح.',
    'single_user',
    new.customer_id,
    now()
  );

  return new;
end;
$$;

create or replace function public.notify_product_order_updated()
returns trigger
language plpgsql
as $$
declare
  notification_title text;
  notification_body text;
begin
  if new.payment_status is not distinct from old.payment_status then
    return new;
  end if;

  notification_title := case new.payment_status
    when 'paid' then 'Product Order Paid'
    when 'failed' then 'Product Order Failed'
    when 'refunded' then 'Product Order Refunded'
    else 'Product Order Updated'
  end;

  notification_body := case new.payment_status
    when 'paid' then 'Your product order ' || coalesce(new.order_number, left(new.id::text, 8)) || ' was paid successfully and is being prepared.'
    when 'failed' then 'Payment for product order ' || coalesce(new.order_number, left(new.id::text, 8)) || ' was not completed. Please try again.'
    when 'refunded' then 'Your payment for product order ' || coalesce(new.order_number, left(new.id::text, 8)) || ' was refunded.'
    else 'Your product order ' || coalesce(new.order_number, left(new.id::text, 8)) || ' was updated.'
  end;

  insert into public.notifications (
    title,
    title_ar,
    body,
    body_ar,
    audience,
    target_profile_id,
    sent_at
  )
  values (
    notification_title,
    case new.payment_status
      when 'paid' then 'تم دفع طلب المنتج'
      when 'failed' then 'فشل دفع طلب المنتج'
      when 'refunded' then 'تم رد مبلغ طلب المنتج'
      else 'تم تحديث طلب المنتج'
    end,
    notification_body,
    case new.payment_status
      when 'paid' then 'تم دفع طلب المنتج ' || coalesce(new.order_number, left(new.id::text, 8)) || ' بنجاح ويجري تجهيزه الآن.'
      when 'failed' then 'لم تكتمل عملية الدفع لطلب المنتج ' || coalesce(new.order_number, left(new.id::text, 8)) || '. يرجى المحاولة مرة أخرى.'
      when 'refunded' then 'تم رد المبلغ المدفوع لطلب المنتج ' || coalesce(new.order_number, left(new.id::text, 8)) || '.'
      else 'تم تحديث طلب المنتج ' || coalesce(new.order_number, left(new.id::text, 8)) || '.'
    end,
    'single_user',
    new.customer_id,
    now()
  );

  return new;
end;
$$;

create or replace function public.notify_salon_booking_created()
returns trigger
language plpgsql
as $$
declare
  appointment_label text;
begin
  appointment_label := to_char(new.appointment_at, 'DD Mon YYYY HH12:MI AM');

  insert into public.notifications (
    title,
    title_ar,
    body,
    body_ar,
    audience,
    target_profile_id,
    sent_at
  )
  values (
    'Appointment Scheduled',
    'تم جدولة الموعد',
    'Your salon appointment is booked for ' || appointment_label || '.',
    'تم حجز موعد الصالون الخاص بك بتاريخ ' || appointment_label || '.',
    'single_user',
    new.customer_id,
    now()
  );

  insert into public.notifications (
    title,
    title_ar,
    body,
    body_ar,
    audience,
    target_salon_id,
    sent_at
  )
  values (
    'New Booking Received',
    'تم استلام حجز جديد',
    'A new customer booking was added for ' || appointment_label || '.',
    'تمت إضافة حجز عميل جديد بتاريخ ' || appointment_label || '.',
    'single_salon',
    new.salon_id,
    now()
  );

  return new;
end;
$$;

create or replace function public.notify_salon_booking_updated()
returns trigger
language plpgsql
as $$
declare
  notification_title text;
  notification_body text;
begin
  if new.booking_status is not distinct from old.booking_status
     and new.appointment_at is not distinct from old.appointment_at then
    return new;
  end if;

  if new.booking_status is distinct from old.booking_status then
    notification_title := case new.booking_status
      when 'confirmed' then 'Appointment Confirmed'
      when 'completed' then 'Appointment Completed'
      when 'cancelled' then 'Appointment Cancelled'
      else 'Appointment Updated'
    end;

    notification_body := case new.booking_status
      when 'confirmed' then 'Your appointment was confirmed for ' || to_char(new.appointment_at, 'DD Mon YYYY HH12:MI AM') || '.'
      when 'completed' then 'Your appointment was marked as completed. Thank you for visiting Freshline.'
      when 'cancelled' then 'Your appointment was cancelled. Please book another time if needed.'
      else 'Your appointment status was updated.'
    end;
  else
    notification_title := 'Appointment Updated';
    notification_body := 'Your appointment time changed to ' || to_char(new.appointment_at, 'DD Mon YYYY HH12:MI AM') || '.';
  end if;

  insert into public.notifications (
    title,
    title_ar,
    body,
    body_ar,
    audience,
    target_profile_id,
    sent_at
  )
  values (
    notification_title,
    case
      when new.booking_status is distinct from old.booking_status then
        case new.booking_status
          when 'confirmed' then 'تم تأكيد الموعد'
          when 'completed' then 'تم إكمال الموعد'
          when 'cancelled' then 'تم إلغاء الموعد'
          else 'تم تحديث الموعد'
        end
      else 'تم تحديث الموعد'
    end,
    notification_body,
    case
      when new.booking_status is distinct from old.booking_status then
        case new.booking_status
          when 'confirmed' then 'تم تأكيد موعدك بتاريخ ' || to_char(new.appointment_at, 'DD Mon YYYY HH12:MI AM') || '.'
          when 'completed' then 'تم تسجيل موعدك كمكتمل. شكراً لزيارتك فريش لاين.'
          when 'cancelled' then 'تم إلغاء موعدك. يمكنك حجز موعد آخر إذا رغبت.'
          else 'تم تحديث حالة موعدك.'
        end
      else 'تم تغيير وقت موعدك إلى ' || to_char(new.appointment_at, 'DD Mon YYYY HH12:MI AM') || '.'
    end,
    'single_user',
    new.customer_id,
    now()
  );

  return new;
end;
$$;

drop table if exists public.support_faqs cascade;

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete cascade,
  action_type text not null,
  target_table text,
  target_id uuid,
  action_summary text not null,
  created_at timestamptz not null default now()
);

drop table if exists public.ai_conversations cascade;

create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_salon_applications_status on public.salon_applications(status);
create index if not exists idx_salons_owner_id on public.salons(owner_id);
create index if not exists idx_salon_packages_salon_id on public.salon_packages(salon_id);
create index if not exists idx_salon_services_salon_id on public.salon_services(salon_id);
create index if not exists idx_salon_employees_salon_id on public.salon_employees(salon_id);
create index if not exists idx_salon_employees_profile_id on public.salon_employees(profile_id);
create index if not exists idx_employee_salary_payments_salon_id on public.employee_salary_payments(salon_id);
create index if not exists idx_employee_salary_payments_employee_id on public.employee_salary_payments(employee_id);
create index if not exists idx_products_salon_id on public.products(salon_id);
create index if not exists idx_products_is_active on public.products(is_active);
create index if not exists idx_carts_customer_id on public.carts(customer_id);
create index if not exists idx_customer_addresses_customer_id on public.customer_addresses(customer_id);
create index if not exists idx_product_orders_customer_id on public.product_orders(customer_id);
create index if not exists idx_salon_bookings_customer_id on public.salon_bookings(customer_id);
create index if not exists idx_salon_bookings_salon_id on public.salon_bookings(salon_id);
create index if not exists idx_salon_reviews_salon_id on public.salon_reviews(salon_id);
create index if not exists idx_salon_reviews_employee_id on public.salon_reviews(employee_id);
create index if not exists idx_product_reviews_product_id on public.product_reviews(product_id);
create index if not exists idx_notifications_audience on public.notifications(audience);
create index if not exists idx_device_push_tokens_profile_id on public.device_push_tokens(profile_id);
create index if not exists idx_admin_audit_logs_admin_id on public.admin_audit_logs(admin_id);

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists trg_profiles_admin_owner_guard on public.profiles;
create trigger trg_profiles_admin_owner_guard before insert or update on public.profiles
for each row execute function public.enforce_admin_owner_profile();

drop trigger if exists trg_profiles_admin_owner_delete_guard on public.profiles;
create trigger trg_profiles_admin_owner_delete_guard before delete on public.profiles
for each row execute function public.prevent_admin_owner_profile_delete();

drop trigger if exists trg_auth_users_profile_sync on auth.users;
create trigger trg_auth_users_profile_sync
after insert or update of email, raw_user_meta_data, email_confirmed_at on auth.users
for each row execute function public.sync_auth_user_profile();

drop trigger if exists trg_customer_subscriptions_updated_at on public.customer_subscriptions;
create trigger trg_customer_subscriptions_updated_at before update on public.customer_subscriptions
for each row execute function public.touch_updated_at();

drop trigger if exists trg_customer_addresses_updated_at on public.customer_addresses;
create trigger trg_customer_addresses_updated_at before update on public.customer_addresses
for each row execute function public.touch_updated_at();

drop trigger if exists trg_saved_cards_updated_at on public.saved_cards;
create trigger trg_saved_cards_updated_at before update on public.saved_cards
for each row execute function public.touch_updated_at();

drop trigger if exists trg_salon_applications_updated_at on public.salon_applications;
create trigger trg_salon_applications_updated_at before update on public.salon_applications
for each row execute function public.touch_updated_at();

drop trigger if exists trg_salons_updated_at on public.salons;
create trigger trg_salons_updated_at before update on public.salons
for each row execute function public.touch_updated_at();

drop trigger if exists trg_salon_packages_updated_at on public.salon_packages;
create trigger trg_salon_packages_updated_at before update on public.salon_packages
for each row execute function public.touch_updated_at();

drop trigger if exists trg_salon_services_updated_at on public.salon_services;
create trigger trg_salon_services_updated_at before update on public.salon_services
for each row execute function public.touch_updated_at();

drop trigger if exists trg_salon_employees_updated_at on public.salon_employees;
create trigger trg_salon_employees_updated_at before update on public.salon_employees
for each row execute function public.touch_updated_at();

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at before update on public.products
for each row execute function public.touch_updated_at();

drop trigger if exists trg_device_push_tokens_updated_at on public.device_push_tokens;
create trigger trg_device_push_tokens_updated_at before update on public.device_push_tokens
for each row execute function public.touch_updated_at();

drop trigger if exists trg_promo_coupons_updated_at on public.promo_coupons;
create trigger trg_promo_coupons_updated_at before update on public.promo_coupons
for each row execute function public.touch_updated_at();

drop trigger if exists trg_carts_updated_at on public.carts;
create trigger trg_carts_updated_at before update on public.carts
for each row execute function public.touch_updated_at();

drop trigger if exists trg_cart_items_updated_at on public.cart_items;
create trigger trg_cart_items_updated_at before update on public.cart_items
for each row execute function public.touch_updated_at();

drop trigger if exists trg_product_orders_updated_at on public.product_orders;
create trigger trg_product_orders_updated_at before update on public.product_orders
for each row execute function public.touch_updated_at();

drop trigger if exists trg_salon_bookings_updated_at on public.salon_bookings;
create trigger trg_salon_bookings_updated_at before update on public.salon_bookings
for each row execute function public.touch_updated_at();

drop trigger if exists trg_product_orders_notify_insert on public.product_orders;
create trigger trg_product_orders_notify_insert after insert on public.product_orders
for each row execute function public.notify_product_order_created();

drop trigger if exists trg_product_orders_notify_update on public.product_orders;
create trigger trg_product_orders_notify_update after update on public.product_orders
for each row execute function public.notify_product_order_updated();

drop trigger if exists trg_salon_bookings_notify_insert on public.salon_bookings;
create trigger trg_salon_bookings_notify_insert after insert on public.salon_bookings
for each row execute function public.notify_salon_booking_created();

drop trigger if exists trg_salon_bookings_notify_update on public.salon_bookings;
create trigger trg_salon_bookings_notify_update after update on public.salon_bookings
for each row execute function public.notify_salon_booking_updated();

drop trigger if exists trg_salon_reviews_refresh_summary on public.salon_reviews;
create trigger trg_salon_reviews_refresh_summary
after insert or update or delete on public.salon_reviews
for each row execute function public.handle_salon_review_summary_refresh();

drop trigger if exists trg_product_reviews_refresh_summary on public.product_reviews;
create trigger trg_product_reviews_refresh_summary
after insert or update or delete on public.product_reviews
for each row execute function public.handle_product_review_summary_refresh();

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'salon-media',
    'salon-media',
    true,
    5242880,
    null
  ),
  (
    'salon-documents',
    'salon-documents',
    true,
    10485760,
    array['application/pdf']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Freshline storage read'
  ) then
    create policy "Freshline storage read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id in ('salon-media', 'salon-documents'));
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Freshline storage insert'
  ) then
    create policy "Freshline storage insert"
    on storage.objects
    for insert
    to anon, authenticated
    with check (bucket_id in ('salon-media', 'salon-documents'));
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Freshline storage update'
  ) then
    create policy "Freshline storage update"
    on storage.objects
    for update
    to anon, authenticated
    using (bucket_id in ('salon-media', 'salon-documents'))
    with check (bucket_id in ('salon-media', 'salon-documents'));
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Freshline storage delete'
  ) then
    create policy "Freshline storage delete"
    on storage.objects
    for delete
    to anon, authenticated
    using (bucket_id in ('salon-media', 'salon-documents'));
  end if;
end
$$;

do $$
begin
  revoke all on function public.verify_auth_email_otp(text, text, text) from public;
  revoke all on function public.verify_auth_email_otp(text, text, text, uuid) from public;
  revoke all on function public.create_auth_email_otp(text, text, text) from public;
  revoke all on function public.create_auth_email_otp(text, text, text, integer) from public;
  revoke all on function public.create_auth_email_otp(text, text, text, uuid, integer) from public;

  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant usage on schema public to anon;
    grant select, insert, update, delete on all tables in schema public to anon;
    grant usage, select on all sequences in schema public to anon;
    grant execute on function public.reserve_product_order_stock(jsonb) to anon;
    grant execute on function public.restore_product_order_stock(jsonb) to anon;
    grant execute on function public.verify_auth_email_otp(text, text, text) to anon;
    grant execute on function public.verify_auth_email_otp(text, text, text, uuid) to anon;
    grant execute on function public.create_auth_email_otp(text, text, text) to anon;
    grant execute on function public.create_auth_email_otp(text, text, text, integer) to anon;
    grant execute on function public.create_auth_email_otp(text, text, text, uuid, integer) to anon;
    alter default privileges in schema public grant select, insert, update, delete on tables to anon;
    alter default privileges in schema public grant usage, select on sequences to anon;
  end if;

  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant usage on schema public to authenticated;
    grant select, insert, update, delete on all tables in schema public to authenticated;
    grant usage, select on all sequences in schema public to authenticated;
    grant execute on function public.reserve_product_order_stock(jsonb) to authenticated;
    grant execute on function public.restore_product_order_stock(jsonb) to authenticated;
    grant execute on function public.verify_auth_email_otp(text, text, text) to authenticated;
    grant execute on function public.verify_auth_email_otp(text, text, text, uuid) to authenticated;
    grant execute on function public.create_auth_email_otp(text, text, text) to authenticated;
    grant execute on function public.create_auth_email_otp(text, text, text, integer) to authenticated;
    grant execute on function public.create_auth_email_otp(text, text, text, uuid, integer) to authenticated;
    alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
    alter default privileges in schema public grant usage, select on sequences to authenticated;
  end if;

  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant usage on schema private to service_role;
    grant select, insert, update, delete on all tables in schema private to service_role;
    grant execute on function public.create_auth_email_otp(text, text, text) to service_role;
    grant execute on function public.create_auth_email_otp(text, text, text, integer) to service_role;
    grant execute on function public.create_auth_email_otp(text, text, text, uuid, integer) to service_role;
    grant execute on function public.verify_auth_email_otp(text, text, text) to service_role;
    grant execute on function public.verify_auth_email_otp(text, text, text, uuid) to service_role;
  end if;
end
$$;

do $$
declare
  record_row record;
begin
  for record_row in
    select schemaname, tablename
    from pg_tables
    where schemaname = 'public'
  loop
    if not exists (
      select 1
      from pg_policies
      where schemaname = record_row.schemaname
        and tablename = record_row.tablename
        and policyname = 'Freshline full access'
    ) then
      execute format(
        'create policy %I on %I.%I for all to anon, authenticated using (true) with check (true)',
        'Freshline full access',
        record_row.schemaname,
        record_row.tablename
      );
    end if;
  end loop;
end
$$;

alter table public.profiles enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.saved_cards enable row level security;
alter table public.customer_subscriptions enable row level security;
alter table public.loyalty_wallets enable row level security;
alter table public.loyalty_transactions enable row level security;
alter table public.membership_plans enable row level security;
alter table public.salon_applications enable row level security;
alter table public.salons enable row level security;
alter table public.salon_packages enable row level security;
alter table public.salon_services enable row level security;
alter table public.salon_employees enable row level security;
alter table public.employee_schedules enable row level security;
alter table public.employee_salary_payments enable row level security;
alter table public.products enable row level security;
alter table public.promo_coupons enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.product_orders enable row level security;
alter table public.product_order_items enable row level security;
alter table public.salon_bookings enable row level security;
alter table public.salon_reviews enable row level security;
alter table public.product_reviews enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.notifications enable row level security;
alter table public.device_push_tokens enable row level security;
alter table public.admin_audit_logs enable row level security;

do $$
declare
  record_row record;
begin
  for record_row in
    select schemaname, tablename
    from pg_tables
    where schemaname = 'public'
  loop
    execute format(
      'alter table %I.%I enable row level security',
      record_row.schemaname,
      record_row.tablename
    );
  end loop;
end
$$;

insert into public.membership_plans (id, name, price_bhd, loyalty_bonus_percent, description)
values
  ('bronze', 'Bronze', 4.99, 5, 'Entry membership with bonus loyalty points'),
  ('silver', 'Silver', 9.99, 10, 'Popular membership with stronger rewards'),
  ('gold', 'Gold', 14.99, 20, 'Top membership with the highest loyalty bonus')
on conflict (id) do update
set
  name = excluded.name,
  price_bhd = excluded.price_bhd,
  loyalty_bonus_percent = excluded.loyalty_bonus_percent,
  description = excluded.description;

update public.membership_plans
set
  name_ar = case id
    when 'bronze' then 'برونزي'
    when 'silver' then 'فضي'
    when 'gold' then 'ذهبي'
    else name_ar
  end,
  description_ar = case id
    when 'bronze' then 'عضوية أساسية مع نقاط ولاء إضافية'
    when 'silver' then 'عضوية شائعة بمكافآت أقوى'
    when 'gold' then 'أفضل عضوية بأعلى نسبة مكافآت'
    else description_ar
  end
where id in ('bronze', 'silver', 'gold');

update public.promo_coupons
set
  code = 'FRESH20',
  description = '20% welcome discount for the first order only.',
  description_ar = 'خصم ترحيبي 20٪ على الطلب الأول فقط.',
  discount_percent = 20,
  applicable_plan_id = null,
  min_order_amount_bhd = null,
  max_discount_amount = null,
  is_active = true,
  starts_at = null,
  ends_at = null,
  updated_at = now()
where upper(code) = 'FRESH10'
  and not exists (
    select 1 from public.promo_coupons where upper(code) = 'FRESH20'
  );

insert into public.promo_coupons (
  code,
  description,
  description_ar,
  discount_percent,
  applicable_plan_id,
  min_order_amount_bhd,
  max_discount_amount,
  is_active
)
values
  ('FRESH20', '20% welcome discount for the first order only.', 'خصم ترحيبي 20٪ على الطلب الأول فقط.', 20, null, null, null, true)
on conflict (code) do update
set
  description = excluded.description,
  description_ar = excluded.description_ar,
  discount_percent = excluded.discount_percent,
  applicable_plan_id = excluded.applicable_plan_id,
  min_order_amount_bhd = excluded.min_order_amount_bhd,
  max_discount_amount = excluded.max_discount_amount,
  is_active = excluded.is_active;

insert into public.platform_media_defaults (media_type, default_url)
values
  ('profile', 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/profileimage.jpeg'),
  ('salon', 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/FrslineS.png'),
  ('product', 'https://ljowjubzpwlhjrgsvhth.supabase.co/storage/v1/object/public/All/FrslineP.png')
on conflict (media_type) do update
set
  default_url = excluded.default_url,
  updated_at = now();

insert into public.profiles (
  id,
  role,
  full_name,
  username,
  email,
  password_hash,
  phone,
  city,
  avatar_url,
  is_active,
  is_super_admin
)
values (
  gen_random_uuid(),
  'admin',
  'Freshline Admin Owner',
  'freshline_admin',
  'admin.com',
  'replace-this-with-a-real-hash',
  '+973 0000 0000',
  'Manama',
  null,
  true,
  true
)
on conflict (email) do update
set
  role = excluded.role,
  full_name = excluded.full_name,
  username = excluded.username,
  phone = excluded.phone,
  city = excluded.city,
  avatar_url = excluded.avatar_url,
  is_active = excluded.is_active,
  is_super_admin = excluded.is_super_admin;

insert into public.salons (
  slug,
  name,
  name_ar,
  description,
  description_ar,
  city,
  city_ar,
  address,
  address_ar,
  phone,
  location_url,
  image_url,
  price_tier,
  supports_home_service,
  rating,
  reviews_count,
  is_active
)
values
  (
    'freshline-signature-lounge',
    'Freshline Signature Lounge',
    'فريش لاين سيغنتشر لاونج',
    'Luxury grooming lounge with premium cuts, beard care, and home-service appointments.',
    'صالة عناية راقية تقدم قصات مميزة وخدمة لحية ومواعيد منزلية.',
    'Manama',
    'المنامة',
    'Road 2819, Seef District, Manama',
    'طريق 2819، منطقة السيف، المنامة',
    '+973 3900 1111',
    'https://www.openstreetmap.org/?mlat=26.2317&mlon=50.5362#map=16/26.2317/50.5362',
    null,
    '$$$',
    true,
    0,
    0,
    true
  ),
  (
    'trim-and-tone-studio',
    'Trim & Tone Studio',
    'استوديو تريم آند تون',
    'Modern barber studio focused on fades, styling, and quick appointment slots.',
    'استوديو حلاقة حديث يركز على التدريجات والتصفيف والمواعيد السريعة.',
    'Manama',
    'المنامة',
    'Road 3801, Adliya, Manama',
    'طريق 3801، العدلية، المنامة',
    '+973 3900 2222',
    'https://www.openstreetmap.org/?mlat=26.2194&mlon=50.5907#map=16/26.2194/50.5907',
    null,
    '$$',
    true,
    0,
    0,
    true
  ),
  (
    'royal-blade-house',
    'Royal Blade House',
    'رويال بليد هاوس',
    'High-end barber house with treatment bundles and aftercare recommendations.',
    'بيت حلاقة فاخر يقدم باقات علاجية وتوصيات للعناية اللاحقة.',
    'Manama',
    'المنامة',
    'Al Shabab Ave, Juffair, Manama',
    'شارع الشباب، الجفير، المنامة',
    '+973 3900 3333',
    'https://www.openstreetmap.org/?mlat=26.2147&mlon=50.6108#map=16/26.2147/50.6108',
    null,
    '$$$',
    false,
    0,
    0,
    true
  )
on conflict (slug) do update
set
  name = excluded.name,
  name_ar = excluded.name_ar,
  description = excluded.description,
  description_ar = excluded.description_ar,
  city = excluded.city,
  city_ar = excluded.city_ar,
  address = excluded.address,
  address_ar = excluded.address_ar,
  phone = excluded.phone,
  location_url = excluded.location_url,
  image_url = excluded.image_url,
  price_tier = excluded.price_tier,
  supports_home_service = excluded.supports_home_service,
  rating = excluded.rating,
  reviews_count = excluded.reviews_count,
  is_active = excluded.is_active;

with seeded_products as (
  select
    s.id as salon_id,
    item.slug,
    item.name,
    item.name_ar,
    item.category,
    item.category_ar,
    item.description,
    item.description_ar,
    item.price,
    item.rating,
    item.stock,
    item.rank
  from (
    values
      (
        'freshline-signature-lounge',
        'premium-hair-kit',
        'Premium Hair Kit',
        'مجموعة الشعر الفاخرة',
        'Hair Care',
        'العناية بالشعر',
        'A complete daily hair-care kit for wash, treatment, and finish.',
        'مجموعة يومية متكاملة للعناية بالشعر تشمل الغسل والعلاج واللمسة النهائية.',
        9.90::numeric,
        0::numeric,
        40,
        1
      ),
      (
        'trim-and-tone-studio',
        'styling-cream',
        'Styling Cream',
        'كريم التصفيف',
        'Styling',
        'التصفيف',
        'Lightweight styling cream with clean hold and natural texture.',
        'كريم تصفيف خفيف بثبات نظيف وملمس طبيعي.',
        7.50::numeric,
        0::numeric,
        60,
        2
      ),
      (
        'royal-blade-house',
        'argan-hair-serum',
        'Argan Hair Serum',
        'سيروم الأرغان للشعر',
        'Treatment',
        'العلاج',
        'Nourishing serum that smooths frizz and supports dry hair recovery.',
        'سيروم مغذٍ ينعّم الهيشان ويدعم تعافي الشعر الجاف.',
        8.90::numeric,
        0::numeric,
        55,
        3
      ),
      (
        'freshline-signature-lounge',
        'beard-care-balm',
        'Beard Care Balm',
        'بلسم العناية باللحية',
        'Beard Care',
        'العناية باللحية',
        'Softening beard balm designed for everyday grooming and shine.',
        'بلسم ملطف للحية مصمم للعناية اليومية وإضافة اللمعان.',
        6.00::numeric,
        0::numeric,
        80,
        4
      )
  ) as item (
    salon_slug,
    slug,
    name,
    name_ar,
    category,
    category_ar,
    description,
    description_ar,
    price,
    rating,
    stock,
    rank
  )
  left join public.salons s on s.slug = item.salon_slug
)
insert into public.products (
  salon_id,
  slug,
  name,
  name_ar,
  category,
  category_ar,
  description,
  description_ar,
  price,
  rating,
  stock,
  image_url,
  is_active,
  bestseller_rank
)
select
  salon_id,
  slug,
  name,
  name_ar,
  category,
  category_ar,
  description,
  description_ar,
  price,
  rating,
  stock,
  null,
  true,
  rank
from seeded_products
on conflict (slug) do update
set
  salon_id = excluded.salon_id,
  name = excluded.name,
  name_ar = excluded.name_ar,
  category = excluded.category,
  category_ar = excluded.category_ar,
  description = excluded.description,
  description_ar = excluded.description_ar,
  price = excluded.price,
  rating = excluded.rating,
  stock = excluded.stock,
  image_url = excluded.image_url,
  is_active = excluded.is_active,
  bestseller_rank = excluded.bestseller_rank;

do $$
declare
  record_row record;
begin
  for record_row in select id from public.salons loop
    perform public.refresh_salon_review_summary(record_row.id);
  end loop;

  for record_row in select id from public.salon_employees loop
    perform public.refresh_employee_review_summary(record_row.id);
  end loop;

  for record_row in select id from public.products loop
    perform public.refresh_product_review_summary(record_row.id);
  end loop;
end
$$;

comment on table public.profiles is 'Application profiles for customers, salon owners, and admins.';
comment on table public.salon_applications is 'Salon registration requests uploaded by salon owners.';
comment on table public.salons is 'Approved salons visible to customers in Freshline.';
comment on table public.salon_bookings is 'Service and package bookings for salon appointments or home visits.';
comment on table public.product_orders is 'Standalone product checkout orders separate from salon bookings.';

do $$
declare
  record_row record;
begin
  if not exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    execute 'create publication supabase_realtime';
  end if;

  for record_row in
    select schemaname, tablename
    from pg_tables
    where schemaname = 'public'
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = record_row.schemaname
        and tablename = record_row.tablename
    ) then
      execute format(
        'alter publication supabase_realtime add table %I.%I',
        record_row.schemaname,
        record_row.tablename
      );
    end if;
  end loop;
end
$$;

notify pgrst, 'reload schema';