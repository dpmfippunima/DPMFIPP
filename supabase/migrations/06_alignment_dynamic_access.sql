-- ============================================================
-- DPM FIPP alignment migration v1.1
-- Additive only: preserves 01–05 records and replaces unsafe
-- static role / public-read assumptions with dynamic assignments.
-- Apply after verifying the deployed 01–05 baseline.
-- ============================================================

create type public.assignment_role as enum ('super_admin', 'secretary', 'commission', 'viewer');
create type public.assignment_status as enum ('invited', 'active', 'inactive', 'suspended');
create type public.data_classification as enum ('public', 'restricted', 'internal');
create type public.resource_grant_status as enum ('active', 'revoked', 'expired');

alter type public.content_status add value if not exists 'approved';
alter type public.content_status add value if not exists 'fallback_active';
alter type public.content_type add value if not exists 'legislasi';
alter type public.content_type add value if not exists 'program_kerja';
alter type public.content_type add value if not exists 'pengumuman';
alter type public.content_type add value if not exists 'artikel';
alter type public.content_type add value if not exists 'galeri';
alter type public.content_type add value if not exists 'laporan';

create table public.commissions (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.periods(id) on delete restrict,
  name text not null,
  code text not null,
  responsibility text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (period_id, code),
  check (length(trim(name)) > 0),
  check (length(trim(code)) > 0)
);

create table public.user_period_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  period_id uuid not null references public.periods(id) on delete restrict,
  role public.assignment_role not null,
  commission_id uuid references public.commissions(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  status public.assignment_status not null default 'invited',
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((role = 'commission') = (commission_id is not null)),
  check (role <> 'viewer' or organization_id is not null)
);

-- Exactly one active primary assignment for a person in a period.
create unique index user_period_assignments_one_active_idx
  on public.user_period_assignments(user_id, period_id)
  where status = 'active';
create index user_period_assignments_active_scope_idx
  on public.user_period_assignments(user_id, role, period_id, commission_id)
  where status = 'active';

create table public.commission_module_responsibilities (
  commission_id uuid not null references public.commissions(id) on delete cascade,
  module_code text not null,
  created_at timestamptz not null default now(),
  primary key (commission_id, module_code),
  check (module_code in ('d_das', 'd_sight', 'd_trace', 'd_dar', 'legislasi', 'program_kerja', 'ormawa', 'publikasi', 'survei', 'media'))
);

alter table public.contents
  add column if not exists classification public.data_classification not null default 'internal',
  add column if not exists commission_id uuid references public.commissions(id) on delete restrict,
  add column if not exists approval_due_at timestamptz,
  add column if not exists escalation_due_at timestamptz,
  add column if not exists version_number integer not null default 1;

update public.contents
set classification = case when status = 'published' then 'public'::public.data_classification else 'internal'::public.data_classification end
where classification is null or classification = 'internal';

create table public.content_versions (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  version_number integer not null,
  title text not null,
  slug text not null,
  excerpt text,
  body text,
  classification public.data_classification not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(content_id, version_number)
);

create table public.content_media (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  version_id uuid references public.content_versions(id) on delete cascade,
  bucket_id text not null default 'dpm-public',
  storage_path text not null,
  media_type public.file_type not null,
  is_cover boolean not null default false,
  display_order integer not null default 0,
  caption text,
  alt_text text,
  classification public.data_classification not null default 'internal',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(bucket_id, storage_path),
  check (display_order >= 0)
);
create unique index content_media_one_cover_idx on public.content_media(content_id) where is_cover;
create index content_media_content_order_idx on public.content_media(content_id, display_order);

create table public.internal_notes (
  id uuid primary key default gen_random_uuid(),
  resource_type text not null,
  resource_id uuid not null,
  commission_id uuid not null references public.commissions(id) on delete restrict,
  author_id uuid not null references public.profiles(id) on delete restrict,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(trim(body)) > 0)
);

create table public.resource_grants (
  id uuid primary key default gen_random_uuid(),
  resource_type text not null,
  resource_id uuid not null,
  permission text not null check (permission in ('read', 'comment')),
  grantee_user_id uuid references public.profiles(id) on delete cascade,
  grantee_commission_id uuid references public.commissions(id) on delete cascade,
  granted_by uuid not null references public.profiles(id) on delete restrict,
  status public.resource_grant_status not null default 'active',
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check ((grantee_user_id is not null) <> (grantee_commission_id is not null))
);
create index resource_grants_lookup_idx on public.resource_grants(resource_type, resource_id, status, expires_at);

alter table public.documents add column if not exists commission_id uuid references public.commissions(id) on delete restrict;
alter table public.transparency_reports add column if not exists commission_id uuid references public.commissions(id) on delete restrict;

-- Dynamic helpers. Legacy profile role remains only as a migration fallback;
-- all new policies below use user_period_assignments.
create or replace function public.has_active_assignment(p_role public.assignment_role, p_period_id uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_period_assignments a
    join public.periods p on p.id = a.period_id
    where a.user_id = auth.uid()
      and a.role = p_role
      and a.status = 'active'
      and (p_period_id is null or a.period_id = p_period_id)
      and (p_period_id is not null or p.is_active)
      and (a.starts_at is null or a.starts_at <= now())
      and (a.ends_at is null or a.ends_at > now())
  );
$$;

create or replace function public.owns_commission_scope(p_commission_id uuid, p_period_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_active_assignment('super_admin', p_period_id)
    or public.has_active_assignment('secretary', p_period_id)
    or exists (
      select 1 from public.user_period_assignments a
      where a.user_id = auth.uid() and a.period_id = p_period_id
        and a.commission_id = p_commission_id and a.role = 'commission' and a.status = 'active'
    );
$$;

create or replace function public.has_resource_grant(p_resource_type text, p_resource_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.resource_grants g
    left join public.user_period_assignments a on a.user_id = auth.uid() and a.status = 'active'
    where g.resource_type = p_resource_type and g.resource_id = p_resource_id
      and g.status = 'active' and (g.expires_at is null or g.expires_at > now())
      and (g.grantee_user_id = auth.uid() or g.grantee_commission_id = a.commission_id)
  );
$$;

create or replace function public.can_manage_module(p_module_code text, p_period_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_active_assignment('super_admin', p_period_id)
    or public.has_active_assignment('secretary', p_period_id)
    or exists (
      select 1 from public.user_period_assignments a
      join public.commission_module_responsibilities r on r.commission_id = a.commission_id
      where a.user_id = auth.uid() and a.period_id = p_period_id and a.status = 'active'
        and a.role = 'commission' and r.module_code = p_module_code
    );
$$;

-- New role checks intentionally do not use fixed Commission 1/2 branches.
create or replace function public.is_super_admin() returns boolean language sql stable security definer set search_path = public as $$ select public.has_active_assignment('super_admin'); $$;
create or replace function public.is_secretary() returns boolean language sql stable security definer set search_path = public as $$ select public.has_active_assignment('secretary'); $$;
create or replace function public.is_viewer() returns boolean language sql stable security definer set search_path = public as $$ select public.has_active_assignment('viewer'); $$;
create or replace function public.is_commission_member() returns boolean language sql stable security definer set search_path = public as $$ select public.has_active_assignment('commission'); $$;

alter table public.commissions enable row level security;
alter table public.user_period_assignments enable row level security;
alter table public.content_versions enable row level security;
alter table public.content_media enable row level security;
alter table public.internal_notes enable row level security;
alter table public.resource_grants enable row level security;
alter table public.commission_module_responsibilities enable row level security;

create policy commissions_public_active_read on public.commissions for select to anon, authenticated using (is_active and archived_at is null);
create policy commissions_admin_manage on public.commissions for all to authenticated using (public.is_super_admin() or public.is_secretary()) with check (public.is_super_admin() or public.is_secretary());
create policy assignments_self_read on public.user_period_assignments for select to authenticated using (user_id = auth.uid() or public.is_super_admin());
create policy assignments_super_admin_manage on public.user_period_assignments for all to authenticated using (public.is_super_admin()) with check (public.is_super_admin());
create policy responsibilities_staff_read on public.commission_module_responsibilities for select to authenticated using (public.is_super_admin() or public.is_secretary() or public.is_commission_member());
create policy responsibilities_super_admin_manage on public.commission_module_responsibilities for all to authenticated using (public.is_super_admin()) with check (public.is_super_admin());

-- Replace over-broad public and static content policies.
drop policy if exists contents_public_published_read on public.contents;
drop policy if exists contents_commission_1_read on public.contents;
drop policy if exists contents_commission_1_insert on public.contents;
drop policy if exists contents_commission_1_update on public.contents;
drop policy if exists contents_secretary_read on public.contents;
drop policy if exists contents_secretary_update on public.contents;
drop policy if exists contents_super_admin_all on public.contents;
create policy contents_public_projection_read on public.contents for select to anon, authenticated using (status = 'published' and classification = 'public' and deleted_at is null);
create policy contents_scoped_staff_read on public.contents for select to authenticated using (public.is_super_admin() or public.is_secretary() or public.owns_commission_scope(commission_id, period_id) or public.has_resource_grant('content', id));
create policy contents_scoped_commission_insert on public.contents for insert to authenticated with check (public.is_commission_member() and author_id = auth.uid() and classification = 'internal' and status = 'draft' and public.owns_commission_scope(commission_id, period_id));
create policy contents_scoped_commission_update on public.contents for update to authenticated using (author_id = auth.uid() and public.owns_commission_scope(commission_id, period_id) and status in ('draft', 'revision')) with check (author_id = auth.uid() and public.owns_commission_scope(commission_id, period_id));
create policy contents_admin_manage on public.contents for all to authenticated using (public.is_super_admin() or public.is_secretary()) with check (public.is_super_admin() or public.is_secretary());

create policy content_versions_staff_read on public.content_versions for select to authenticated using (exists(select 1 from public.contents c where c.id = content_id and (public.is_super_admin() or public.is_secretary() or public.owns_commission_scope(c.commission_id,c.period_id) or public.has_resource_grant('content',c.id))));
create policy content_media_public_read on public.content_media for select to anon, authenticated using (classification = 'public' and exists(select 1 from public.contents c where c.id = content_id and c.status = 'published' and c.classification = 'public' and c.deleted_at is null));
create policy content_media_staff_manage on public.content_media for all to authenticated using (exists(select 1 from public.contents c where c.id = content_id and (public.is_super_admin() or public.is_secretary() or public.owns_commission_scope(c.commission_id,c.period_id)))) with check (exists(select 1 from public.contents c where c.id = content_id and (public.is_super_admin() or public.is_secretary() or public.owns_commission_scope(c.commission_id,c.period_id))));
create policy internal_notes_scoped_read on public.internal_notes for select to authenticated using (public.is_super_admin() or public.owns_commission_scope(commission_id, (select period_id from public.commissions where id = commission_id)) or public.has_resource_grant(resource_type, resource_id));
create policy internal_notes_owner_insert on public.internal_notes for insert to authenticated with check (author_id = auth.uid() and public.owns_commission_scope(commission_id, (select period_id from public.commissions where id = commission_id)));
create policy grants_super_admin_manage on public.resource_grants for all to authenticated using (public.is_super_admin()) with check (public.is_super_admin());

-- Public direct D-DAS insertion is removed. Submission must use a server route
-- after CAPTCHA + OTP verification; a browser must never set otp_verified.
drop policy if exists aspirations_public_insert on public.aspirations;
drop policy if exists aspirations_commission_2_read on public.aspirations;
drop policy if exists aspirations_commission_2_update on public.aspirations;
drop policy if exists aspirations_secretary_read on public.aspirations;
drop policy if exists aspirations_secretary_update on public.aspirations;
create policy aspirations_das_staff_read on public.aspirations for select to authenticated using (public.can_manage_module('d_das', period_id));
create policy aspirations_das_staff_update on public.aspirations for update to authenticated using (public.can_manage_module('d_das', period_id)) with check (public.can_manage_module('d_das', period_id));

drop policy if exists documents_internal_dpm_read on public.documents;
drop policy if exists documents_restricted_access_read on public.documents;
drop policy if exists documents_secretary_all on public.documents;
drop policy if exists documents_super_admin_all on public.documents;
create policy documents_dar_staff_read on public.documents for select to authenticated using (public.can_manage_module('d_dar', period_id) and (visibility <> 'internal' or commission_id is null or public.owns_commission_scope(commission_id, period_id)));
create policy documents_restricted_grant_read on public.documents for select to authenticated using (visibility = 'restricted' and exists (select 1 from public.access_requests ar where ar.document_id = id and ar.requester_id = auth.uid() and ar.status = 'approved' and (ar.expires_at is null or ar.expires_at > now())));
create policy documents_dar_staff_manage on public.documents for all to authenticated using (public.can_manage_module('d_dar', period_id)) with check (public.can_manage_module('d_dar', period_id));

drop policy if exists transparency_secretary_all on public.transparency_reports;
drop policy if exists transparency_commission_2_manage on public.transparency_reports;
drop policy if exists transparency_super_admin_all on public.transparency_reports;
create policy transparency_trace_staff_manage on public.transparency_reports for all to authenticated using (public.can_manage_module('d_trace', period_id)) with check (public.can_manage_module('d_trace', period_id));

-- Restrict profiles and audit data to their owners/administrators.
drop policy if exists profiles_authenticated_read on public.profiles;
drop policy if exists audit_logs_super_admin_insert on public.audit_logs;

-- Storage: public media can be read publicly, private evidence/documents only
-- through server-authorized signed URLs. All write operations are staff scoped.
drop policy if exists dpm_public_select on storage.objects;
drop policy if exists dpm_public_insert_admin on storage.objects;
drop policy if exists dpm_public_update_admin on storage.objects;
drop policy if exists dpm_public_delete_admin on storage.objects;
drop policy if exists dpm_documents_select_internal on storage.objects;
drop policy if exists dpm_documents_insert_admin on storage.objects;
drop policy if exists dpm_documents_update_admin on storage.objects;
drop policy if exists dpm_documents_delete_admin on storage.objects;
drop policy if exists dpm_aspiration_evidence_select on storage.objects;
drop policy if exists dpm_aspiration_evidence_insert on storage.objects;
drop policy if exists dpm_aspiration_evidence_update on storage.objects;
drop policy if exists dpm_aspiration_evidence_delete on storage.objects;
create policy storage_public_media_read on storage.objects for select to anon, authenticated using (bucket_id = 'dpm-public');
create policy storage_public_media_manage on storage.objects for all to authenticated using (bucket_id = 'dpm-public' and (public.is_super_admin() or public.is_secretary() or public.is_commission_member())) with check (bucket_id = 'dpm-public' and (public.is_super_admin() or public.is_secretary() or public.is_commission_member()));

revoke all on function public.has_active_assignment(public.assignment_role, uuid) from public;
revoke all on function public.owns_commission_scope(uuid, uuid) from public;
revoke all on function public.has_resource_grant(text, uuid) from public;
revoke all on function public.can_manage_module(text, uuid) from public;
grant execute on function public.has_active_assignment(public.assignment_role, uuid), public.owns_commission_scope(uuid, uuid), public.has_resource_grant(text, uuid), public.can_manage_module(text, uuid) to authenticated;
