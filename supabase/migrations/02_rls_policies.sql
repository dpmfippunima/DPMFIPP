-- ============================================================
-- DPM FIPP CMS
-- SUPABASE DATABASE
-- Migration: 02_rls_policies.sql
-- Version: 1.0 FINAL
--
-- PURPOSE:
--   Row Level Security (RLS) policies.
--
-- PREREQUISITE:
--   01_schema.sql sudah berhasil dijalankan.
--
-- INCLUDED:
--   - RLS helper functions
--   - Public read policies
--   - Role-based admin policies
--   - D-DAS policies
--   - D-SIGHT / Content policies
--   - D-TRACE policies
--   - D-DAR policies
--   - Access Request policies
--   - Notification policies
--   - Audit Log policies
--
-- NOT INCLUDED:
--   - Storage policies
--   - Seed data
--   - Workflow functions
--   - Escalation functions
--   - Audit triggers
-- ============================================================


-- ============================================================
-- 0. SAFETY
-- ============================================================

-- RLS sudah diaktifkan pada 01_schema.sql.
-- Bagian ini memastikan kembali seluruh tabel berada dalam
-- mode Row Level Security.

alter table public.periods enable row level security;
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.contents enable row level security;
alter table public.approval_logs enable row level security;
alter table public.aspirations enable row level security;
alter table public.aspiration_evidence enable row level security;
alter table public.aspiration_forwards enable row level security;
alter table public.aspiration_responses enable row level security;
alter table public.transparency_reports enable row level security;
alter table public.documents enable row level security;
alter table public.access_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;


-- ============================================================
-- 1. RLS HELPER FUNCTIONS
-- ============================================================
--
-- SECURITY DEFINER digunakan agar pengecekan role tidak terkena
-- recursive RLS pada tabel profiles.
--
-- Fungsi hanya membaca role milik auth.uid().
-- Tidak melakukan perubahan data.
-- ============================================================

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.profiles
  where id = auth.uid()
    and status = 'active'
    and deleted_at is null
  limit 1;
$$;

create or replace function public.is_authenticated_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and status = 'active'
      and deleted_at is null
  );
$$;

create or replace function public.has_role(required_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = required_role;
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'super_admin';
$$;

create or replace function public.is_secretary()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'secretary';
$$;

create or replace function public.is_commission_1()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'commission_1';
$$;

create or replace function public.is_commission_2()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'commission_2';
$$;

create or replace function public.is_viewer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() = 'viewer';
$$;


-- ============================================================
-- 2. PERIODS
-- ============================================================

drop policy if exists periods_public_read on public.periods;
drop policy if exists periods_super_admin_manage on public.periods;
drop policy if exists periods_secretary_read on public.periods;

create policy periods_public_read
on public.periods
for select
to anon, authenticated
using (
  is_active = true
);

create policy periods_secretary_read
on public.periods
for select
to authenticated
using (
  public.is_secretary()
);

create policy periods_super_admin_manage
on public.periods
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 3. ORGANIZATIONS / ORMAWA
-- ============================================================

drop policy if exists organizations_public_read on public.organizations;
drop policy if exists organizations_authenticated_read on public.organizations;
drop policy if exists organizations_super_admin_manage on public.organizations;
drop policy if exists organizations_secretary_manage on public.organizations;

create policy organizations_public_read
on public.organizations
for select
to anon, authenticated
using (
  status = 'active'
  and deleted_at is null
);

create policy organizations_authenticated_read
on public.organizations
for select
to authenticated
using (
  public.is_authenticated_user()
);

create policy organizations_super_admin_manage
on public.organizations
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);

create policy organizations_secretary_manage
on public.organizations
for update
to authenticated
using (
  public.is_secretary()
)
with check (
  public.is_secretary()
);


-- ============================================================
-- 4. PROFILES
-- ============================================================
--
-- Pengguna hanya dapat melihat profil sesuai kebutuhan.
--
-- Super Admin:
--   full management
--
-- Pengguna biasa:
--   dapat membaca profil aktif yang diperlukan sistem
--
-- Pengguna:
--   dapat memperbarui profil miliknya sendiri.
-- ============================================================

drop policy if exists profiles_self_read on public.profiles;
drop policy if exists profiles_self_update on public.profiles;
drop policy if exists profiles_authenticated_read on public.profiles;
drop policy if exists profiles_super_admin_manage on public.profiles;

create policy profiles_self_read
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
);

create policy profiles_self_update
on public.profiles
for update
to authenticated
using (
  id = auth.uid()
)
with check (
  id = auth.uid()
);

create policy profiles_authenticated_read
on public.profiles
for select
to authenticated
using (
  public.is_authenticated_user()
);

create policy profiles_super_admin_manage
on public.profiles
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 5. CONTENTS / D-SIGHT
-- ============================================================
--
-- RULE:
--
-- Draft:
--   hanya Commission 1, Secretary, Super Admin
--
-- Commission 1:
--   Create / Read / Update / Submit
--
-- Secretary:
--   Read / Update / Approve / Publish / Archive
--
-- Super Admin:
--   Full access
--
-- Viewer:
--   hanya published
--
-- Commission 2:
--   tidak mengelola D-SIGHT.
-- ============================================================

drop policy if exists contents_public_published_read on public.contents;
drop policy if exists contents_commission_1_read on public.contents;
drop policy if exists contents_commission_1_insert on public.contents;
drop policy if exists contents_commission_1_update on public.contents;
drop policy if exists contents_secretary_read on public.contents;
drop policy if exists contents_secretary_update on public.contents;
drop policy if exists contents_super_admin_all on public.contents;

create policy contents_public_published_read
on public.contents
for select
to anon, authenticated
using (
  status = 'published'
  and deleted_at is null
);

create policy contents_commission_1_read
on public.contents
for select
to authenticated
using (
  public.is_commission_1()
  and (
    author_id = auth.uid()
    or status = 'published'
  )
);

create policy contents_commission_1_insert
on public.contents
for insert
to authenticated
with check (
  public.is_commission_1()
  and author_id = auth.uid()
  and status = 'draft'
);

create policy contents_commission_1_update
on public.contents
for update
to authenticated
using (
  public.is_commission_1()
  and author_id = auth.uid()
  and status in ('draft', 'revision')
)
with check (
  public.is_commission_1()
  and author_id = auth.uid()
  and status in (
    'draft',
    'revision',
    'pending_secretary'
  )
);

create policy contents_secretary_read
on public.contents
for select
to authenticated
using (
  public.is_secretary()
);

create policy contents_secretary_update
on public.contents
for update
to authenticated
using (
  public.is_secretary()
)
with check (
  public.is_secretary()
);

create policy contents_super_admin_all
on public.contents
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 6. APPROVAL LOGS
-- ============================================================

drop policy if exists approval_logs_authenticated_read on public.approval_logs;
drop policy if exists approval_logs_secretary_insert on public.approval_logs;
drop policy if exists approval_logs_super_admin_all on public.approval_logs;

create policy approval_logs_authenticated_read
on public.approval_logs
for select
to authenticated
using (
  public.is_secretary()
  or public.is_super_admin()
  or public.is_commission_1()
);

create policy approval_logs_secretary_insert
on public.approval_logs
for insert
to authenticated
with check (
  public.is_secretary()
  and actor_id = auth.uid()
);

create policy approval_logs_super_admin_all
on public.approval_logs
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 7. ASPIRATIONS / D-DAS
-- ============================================================
--
-- PUBLIC:
--   dapat mengirim aspirasi tanpa login.
--
-- COMMISSION 2:
--   mengelola aspirasi.
--
-- SECRETARY:
--   read / update.
--
-- SUPER ADMIN:
--   full access.
--
-- VIEWER:
--   hanya melihat aspirasi yang memang diteruskan kepada
--   organisasinya melalui mekanisme forwarding.
--
-- CATATAN:
--   Data identitas pengirim tetap berada pada tabel aspirations
--   dan tidak diberikan SELECT kepada anon.
-- ============================================================

drop policy if exists aspirations_public_insert on public.aspirations;
drop policy if exists aspirations_commission_2_read on public.aspirations;
drop policy if exists aspirations_commission_2_update on public.aspirations;
drop policy if exists aspirations_secretary_read on public.aspirations;
drop policy if exists aspirations_secretary_update on public.aspirations;
drop policy if exists aspirations_super_admin_all on public.aspirations;

create policy aspirations_public_insert
on public.aspirations
for insert
to anon, authenticated
with check (
  otp_verified = false
  and status = 'submitted'
);

create policy aspirations_commission_2_read
on public.aspirations
for select
to authenticated
using (
  public.is_commission_2()
);

create policy aspirations_commission_2_update
on public.aspirations
for update
to authenticated
using (
  public.is_commission_2()
)
with check (
  public.is_commission_2()
);

create policy aspirations_secretary_read
on public.aspirations
for select
to authenticated
using (
  public.is_secretary()
);

create policy aspirations_secretary_update
on public.aspirations
for update
to authenticated
using (
  public.is_secretary()
)
with check (
  public.is_secretary()
);

create policy aspirations_super_admin_all
on public.aspirations
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 8. ASPIRATION EVIDENCE
-- ============================================================
--
-- Bukti aspirasi bersifat sensitif.
--
-- Hanya Commission 2 dan Super Admin yang boleh membaca.
-- Upload metadata dibatasi kepada authenticated Commission 2.
-- ============================================================

drop policy if exists evidence_commission_2_read on public.aspiration_evidence;
drop policy if exists evidence_commission_2_insert on public.aspiration_evidence;
drop policy if exists evidence_super_admin_all on public.aspiration_evidence;

create policy evidence_commission_2_read
on public.aspiration_evidence
for select
to authenticated
using (
  public.is_commission_2()
);

create policy evidence_commission_2_insert
on public.aspiration_evidence
for insert
to authenticated
with check (
  public.is_commission_2()
);

create policy evidence_super_admin_all
on public.aspiration_evidence
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 9. ASPIRATION FORWARDS
-- ============================================================

drop policy if exists forwards_commission_2_read on public.aspiration_forwards;
drop policy if exists forwards_commission_2_insert on public.aspiration_forwards;
drop policy if exists forwards_commission_2_update on public.aspiration_forwards;
drop policy if exists forwards_viewer_read on public.aspiration_forwards;
drop policy if exists forwards_viewer_update on public.aspiration_forwards;
drop policy if exists forwards_super_admin_all on public.aspiration_forwards;

create policy forwards_commission_2_read
on public.aspiration_forwards
for select
to authenticated
using (
  public.is_commission_2()
);

create policy forwards_commission_2_insert
on public.aspiration_forwards
for insert
to authenticated
with check (
  public.is_commission_2()
  and forwarded_by = auth.uid()
);

create policy forwards_commission_2_update
on public.aspiration_forwards
for update
to authenticated
using (
  public.is_commission_2()
)
with check (
  public.is_commission_2()
);

create policy forwards_viewer_read
on public.aspiration_forwards
for select
to authenticated
using (
  public.is_viewer()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = aspiration_forwards.organization_id
  )
);

create policy forwards_viewer_update
on public.aspiration_forwards
for update
to authenticated
using (
  public.is_viewer()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = aspiration_forwards.organization_id
  )
)
with check (
  public.is_viewer()
);


create policy forwards_super_admin_all
on public.aspiration_forwards
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 10. ASPIRATION RESPONSES
-- ============================================================

drop policy if exists responses_commission_2_read on public.aspiration_responses;
drop policy if exists responses_viewer_read on public.aspiration_responses;
drop policy if exists responses_viewer_insert on public.aspiration_responses;
drop policy if exists responses_viewer_update on public.aspiration_responses;
drop policy if exists responses_super_admin_all on public.aspiration_responses;

create policy responses_commission_2_read
on public.aspiration_responses
for select
to authenticated
using (
  public.is_commission_2()
);

create policy responses_viewer_read
on public.aspiration_responses
for select
to authenticated
using (
  public.is_viewer()
  and responder_id = auth.uid()
);

create policy responses_viewer_insert
on public.aspiration_responses
for insert
to authenticated
with check (
  public.is_viewer()
  and responder_id = auth.uid()
  and exists (
    select 1
    from public.aspiration_forwards f
    join public.profiles p
      on p.id = auth.uid()
    where f.id = forward_id
      and f.organization_id = p.organization_id
      and f.status in ('pending', 'responded')
  )
);

create policy responses_viewer_update
on public.aspiration_responses
for update
to authenticated
using (
  public.is_viewer()
  and responder_id = auth.uid()
)
with check (
  public.is_viewer()
  and responder_id = auth.uid()
);

create policy responses_super_admin_all
on public.aspiration_responses
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 11. D-TRACE / TRANSPARENCY REPORTS
-- ============================================================

drop policy if exists transparency_public_read on public.transparency_reports;
drop policy if exists transparency_secretary_all on public.transparency_reports;
drop policy if exists transparency_commission_2_manage on public.transparency_reports;
drop policy if exists transparency_super_admin_all on public.transparency_reports;

create policy transparency_public_read
on public.transparency_reports
for select
to anon, authenticated
using (
  status = 'published'
  and deleted_at is null
);

create policy transparency_secretary_all
on public.transparency_reports
for all
to authenticated
using (
  public.is_secretary()
)
with check (
  public.is_secretary()
);

create policy transparency_commission_2_manage
on public.transparency_reports
for all
to authenticated
using (
  public.is_commission_2()
)
with check (
  public.is_commission_2()
);

create policy transparency_super_admin_all
on public.transparency_reports
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 12. DOCUMENTS / D-DAR
-- ============================================================
--
-- PUBLIC:
--   hanya dokumen Public.
--
-- INTERNAL:
--   pengurus DPM.
--
-- RESTRICTED:
--   melalui Access Request.
--
-- Secretary:
--   full management.
--
-- Super Admin:
--   full management.
-- ============================================================

drop policy if exists documents_public_read on public.documents;
drop policy if exists documents_internal_dpm_read on public.documents;
drop policy if exists documents_restricted_access_read on public.documents;
drop policy if exists documents_secretary_all on public.documents;
drop policy if exists documents_super_admin_all on public.documents;

create policy documents_public_read
on public.documents
for select
to anon, authenticated
using (
  visibility = 'public'
  and deleted_at is null
);

create policy documents_internal_dpm_read
on public.documents
for select
to authenticated
using (
  visibility = 'internal'
  and (
    public.is_super_admin()
    or public.is_secretary()
    or public.is_commission_1()
    or public.is_commission_2()
  )
);

create policy documents_restricted_access_read
on public.documents
for select
to authenticated
using (
  visibility = 'restricted'
  and (
    public.is_super_admin()
    or public.is_secretary()
    or exists (
      select 1
      from public.access_requests ar
      where ar.document_id = documents.id
        and ar.requester_id = auth.uid()
        and ar.status = 'approved'
        and (
          ar.expires_at is null
          or ar.expires_at > now()
        )
    )
  )
);

create policy documents_secretary_all
on public.documents
for all
to authenticated
using (
  public.is_secretary()
)
with check (
  public.is_secretary()
);

create policy documents_super_admin_all
on public.documents
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 13. ACCESS REQUESTS
-- ============================================================
--
-- Viewer:
--   dapat membuat request.
--
-- Viewer:
--   dapat membaca request miliknya.
--
-- Super Admin:
--   approve / reject / revoke.
-- ============================================================

drop policy if exists access_requests_viewer_insert on public.access_requests;
drop policy if exists access_requests_viewer_read on public.access_requests;
drop policy if exists access_requests_super_admin_all on public.access_requests;
drop policy if exists access_requests_secretary_read on public.access_requests;

create policy access_requests_viewer_insert
on public.access_requests
for insert
to authenticated
with check (
  public.is_viewer()
  and requester_id = auth.uid()
  and status = 'pending'
);

create policy access_requests_viewer_read
on public.access_requests
for select
to authenticated
using (
  public.is_viewer()
  and requester_id = auth.uid()
);

create policy access_requests_secretary_read
on public.access_requests
for select
to authenticated
using (
  public.is_secretary()
);

create policy access_requests_super_admin_all
on public.access_requests
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 14. NOTIFICATIONS
-- ============================================================
--
-- User hanya dapat membaca / mengubah notifikasi miliknya.
-- Super Admin dapat mengelola seluruh notifikasi.
-- ============================================================

drop policy if exists notifications_self_read on public.notifications;
drop policy if exists notifications_self_update on public.notifications;
drop policy if exists notifications_super_admin_all on public.notifications;

create policy notifications_self_read
on public.notifications
for select
to authenticated
using (
  recipient_id = auth.uid()
);

create policy notifications_self_update
on public.notifications
for update
to authenticated
using (
  recipient_id = auth.uid()
)
with check (
  recipient_id = auth.uid()
);

create policy notifications_super_admin_all
on public.notifications
for all
to authenticated
using (
  public.is_super_admin()
)
with check (
  public.is_super_admin()
);


-- ============================================================
-- 15. AUDIT LOGS
-- ============================================================
--
-- Audit log bersifat append-only secara konsep.
--
-- Super Admin:
--   full read.
--
-- Secretary:
--   read.
--
-- Insert otomatis nantinya dilakukan melalui trigger
-- pada migration 05.
--
-- Tidak diberikan UPDATE/DELETE kepada user biasa.
-- ============================================================

drop policy if exists audit_logs_super_admin_read on public.audit_logs;
drop policy if exists audit_logs_secretary_read on public.audit_logs;
drop policy if exists audit_logs_super_admin_insert on public.audit_logs;

create policy audit_logs_super_admin_read
on public.audit_logs
for select
to authenticated
using (
  public.is_super_admin()
);

create policy audit_logs_secretary_read
on public.audit_logs
for select
to authenticated
using (
  public.is_secretary()
);

create policy audit_logs_super_admin_insert
on public.audit_logs
for insert
to authenticated
with check (
  public.is_super_admin()
);


-- ============================================================
-- 16. DEFAULT DENY
-- ============================================================
--
-- Tidak membuat policy berarti akses ditolak oleh RLS.
--
-- Bagian ini sengaja tidak memberikan policy umum kepada:
--   - anon
--   - authenticated
--
-- untuk tabel sensitif.
--
-- Dengan demikian default behavior adalah DENY.
-- ============================================================


-- ============================================================
-- 17. FUNCTION PERMISSIONS
-- ============================================================
--
-- Helper functions boleh dipanggil oleh authenticated user.
-- Anonymous user tidak membutuhkan akses role-checking.
-- ============================================================

revoke all
on function public.current_user_role()
from public;

revoke all
on function public.is_authenticated_user()
from public;

revoke all
on function public.has_role(public.user_role)
from public;

revoke all
on function public.is_super_admin()
from public;

revoke all
on function public.is_secretary()
from public;

revoke all
on function public.is_commission_1()
from public;

revoke all
on function public.is_commission_2()
from public;

revoke all
on function public.is_viewer()
from public;

grant execute
on function public.current_user_role()
to authenticated;

grant execute
on function public.is_authenticated_user()
to authenticated;

grant execute
on function public.has_role(public.user_role)
to authenticated;

grant execute
on function public.is_super_admin()
to authenticated;

grant execute
on function public.is_secretary()
to authenticated;

grant execute
on function public.is_commission_1()
to authenticated;

grant execute
on function public.is_commission_2()
to authenticated;

grant execute
on function public.is_viewer()
to authenticated;


-- ============================================================
-- 18. FINAL
-- ============================================================

-- Jika script mencapai bagian ini tanpa error,
-- maka migration 02_rls_policies.sql telah terpasang.

select
  '02_rls_policies.sql berhasil diterapkan.' as result;