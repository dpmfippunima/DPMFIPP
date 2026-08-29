-- ============================================================
-- DPM FIPP CMS
-- SUPABASE DATABASE SCHEMA V1 - FINAL
-- Migration: 01_schema.sql
-- Database: PostgreSQL / Supabase
--
-- PURPOSE
--   Foundation database untuk DPM FIPP CMS.
--
-- INCLUDED
--   - Extensions
--   - Enum types
--   - Period management
--   - Organization / ORMAWA
--   - User profiles & RBAC foundation
--   - Content / D-SIGHT
--   - Approval logs
--   - D-DAS / Aspirations
--   - Aspiration evidence
--   - Aspiration forwarding
--   - Aspiration responses
--   - D-TRACE
--   - D-DAR
--   - Access requests
--   - Notifications
--   - Audit logs
--   - updated_at trigger
--   - RLS activation
--   - Indexes & constraints
--
-- NOT INCLUDED
--   - RLS policies
--   - Storage buckets/policies
--   - Seed data
--   - Approval workflow functions
--   - SLA escalation functions
--   - Audit mutation triggers
--   - OTP implementation
--
-- FILE ORDER
--   01_schema.sql
--   02_rls_policies.sql
--   03_storage.sql
--   04_seed.sql
--   05_functions_triggers.sql
-- ============================================================


-- ============================================================
-- 0. EXTENSIONS
-- ============================================================

create extension if not exists pgcrypto;


-- ============================================================
-- 1. ENUM TYPES
-- ============================================================

-- ------------------------------------------------------------
-- USER
-- ------------------------------------------------------------

create type public.user_role as enum (
  'super_admin',
  'secretary',
  'commission_1',
  'commission_2',
  'viewer'
);

create type public.user_status as enum (
  'invited',
  'active',
  'inactive',
  'suspended'
);


-- ------------------------------------------------------------
-- ORGANIZATION
-- ------------------------------------------------------------

create type public.organization_status as enum (
  'active',
  'inactive',
  'archived'
);


-- ------------------------------------------------------------
-- CONTENT / D-SIGHT
-- ------------------------------------------------------------

create type public.content_type as enum (
  'kajian',
  'berita',
  'survei',
  'hasil_survei',
  'kebijakan',
  'opini'
);

create type public.content_status as enum (
  'draft',
  'pending_secretary',
  'pending_super_admin',
  'revision',
  'rejected',
  'published',
  'archived'
);


-- ------------------------------------------------------------
-- APPROVAL
-- ------------------------------------------------------------

create type public.approval_action as enum (
  'submitted',
  'approved',
  'revision',
  'rejected',
  'escalated',
  'self_approved'
);


-- ------------------------------------------------------------
-- D-DAS / ASPIRATION
-- ------------------------------------------------------------

create type public.aspiration_category as enum (
  'academic',
  'facility',
  'organization',
  'policy',
  'advocacy',
  'sexual_harassment',
  'corruption',
  'bullying',
  'abuse_of_authority',
  'serious_ethics_violation',
  'violence',
  'other'
);

create type public.aspiration_status as enum (
  'submitted',
  'in_review',
  'forwarded',
  'followed_up',
  'completed',
  'rejected',
  'archived'
);


-- ------------------------------------------------------------
-- FILE
-- ------------------------------------------------------------

create type public.file_type as enum (
  'image',
  'video',
  'audio',
  'document',
  'other'
);


-- ------------------------------------------------------------
-- ASPIRATION FORWARDING
-- ------------------------------------------------------------

create type public.forward_status as enum (
  'pending',
  'responded',
  'completed',
  'cancelled'
);


-- ------------------------------------------------------------
-- D-DAR
-- ------------------------------------------------------------

create type public.document_visibility as enum (
  'public',
  'internal',
  'restricted'
);

create type public.document_category as enum (
  'meeting',
  'kajian',
  'legislation',
  'incoming_letter',
  'outgoing_letter',
  'lpj',
  'supporting_document',
  'other'
);


-- ------------------------------------------------------------
-- ACCESS REQUEST
-- ------------------------------------------------------------

create type public.access_request_status as enum (
  'pending',
  'approved',
  'rejected',
  'expired',
  'revoked'
);


-- ------------------------------------------------------------
-- D-TRACE
-- ------------------------------------------------------------

create type public.transparency_type as enum (
  'aspiration_follow_up',
  'kajian_implementation',
  'legislation',
  'organization_monitoring',
  'work_program'
);

create type public.transparency_status as enum (
  'draft',
  'published',
  'archived'
);


-- ============================================================
-- 2. PERIODS / PERIODE KEPENGURUSAN
-- ============================================================

create table public.periods (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  year_start integer not null,
  year_end integer not null,

  is_active boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint periods_name_unique
    unique (name),

  constraint periods_year_check
    check (year_end = year_start + 1)
);


-- Hanya boleh ada satu periode aktif.
create unique index periods_one_active_idx
  on public.periods (is_active)
  where is_active = true;


-- ============================================================
-- 3. ORGANIZATIONS / ORMAWA
-- ============================================================

create table public.organizations (
  id uuid primary key default gen_random_uuid(),

  period_id uuid references public.periods(id)
    on delete restrict,

  name text not null,
  code text not null,
  description text,

  logo_path text,
  profile_path text,
  structure_path text,

  status public.organization_status not null default 'active',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);


create unique index organizations_code_unique_idx
  on public.organizations (lower(code));

create index organizations_period_idx
  on public.organizations (period_id);

create index organizations_status_idx
  on public.organizations (status);

create index organizations_period_status_idx
  on public.organizations (period_id, status);


-- ============================================================
-- 4. PROFILES / USER APPLICATION DATA
-- ============================================================
--
-- Supabase Auth tetap menjadi sumber autentikasi.
--
-- auth.users.id
--       |
--       v
-- profiles.id
--
-- Role dan data bisnis aplikasi disimpan di profiles.
-- ============================================================

create table public.profiles (
  id uuid primary key references auth.users(id)
    on delete cascade,

  full_name text not null,
  email text not null,

  role public.user_role not null,
  status public.user_status not null default 'invited',

  period_id uuid references public.periods(id)
    on delete restrict,

  organization_id uuid references public.organizations(id)
    on delete set null,

  avatar_path text,

  last_login_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);


create unique index profiles_email_unique_idx
  on public.profiles (lower(email));

create index profiles_role_idx
  on public.profiles (role);

create index profiles_status_idx
  on public.profiles (status);

create index profiles_period_idx
  on public.profiles (period_id);

create index profiles_organization_idx
  on public.profiles (organization_id);

create index profiles_period_role_idx
  on public.profiles (period_id, role);


-- ============================================================
-- 5. CONTENTS / D-SIGHT + GENERAL CONTENT
-- ============================================================
--
-- SATU CONTENT = SATU PENANGGUNG JAWAB.
--
-- author_id = penanggung jawab utama.
--
-- Draft hanya akan dapat dilihat oleh role yang sesuai melalui
-- 02_rls_policies.sql.
--
-- Periode kepengurusan disimpan secara eksplisit agar histori
-- antar-periode tetap terjaga.
-- ============================================================

create table public.contents (
  id uuid primary key default gen_random_uuid(),

  period_id uuid not null references public.periods(id)
    on delete restrict,

  author_id uuid not null references public.profiles(id)
    on delete restrict,

  title text not null,
  slug text not null,

  type public.content_type not null,
  status public.content_status not null default 'draft',

  excerpt text,
  body text,

  featured_image_path text,

  tags text[],

  submitted_at timestamptz,

  secretary_reviewed_at timestamptz,
  super_admin_reviewed_at timestamptz,

  published_at timestamptz,
  archived_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint contents_title_not_empty
    check (length(trim(title)) > 0),

  constraint contents_slug_not_empty
    check (length(trim(slug)) > 0)
);


create unique index contents_slug_unique_idx
  on public.contents (lower(slug));

create index contents_period_idx
  on public.contents (period_id);

create index contents_author_idx
  on public.contents (author_id);

create index contents_type_idx
  on public.contents (type);

create index contents_status_idx
  on public.contents (status);

create index contents_published_idx
  on public.contents (published_at);

create index contents_author_status_idx
  on public.contents (author_id, status);

create index contents_period_status_idx
  on public.contents (period_id, status);


-- ============================================================
-- 6. CONTENT APPROVAL LOGS
-- ============================================================

create table public.approval_logs (
  id uuid primary key default gen_random_uuid(),

  content_id uuid not null references public.contents(id)
    on delete cascade,

  actor_id uuid references public.profiles(id)
    on delete set null,

  action public.approval_action not null,

  notes text,

  created_at timestamptz not null default now()
);


create index approval_logs_content_idx
  on public.approval_logs (content_id);

create index approval_logs_actor_idx
  on public.approval_logs (actor_id);

create index approval_logs_action_idx
  on public.approval_logs (action);

create index approval_logs_created_idx
  on public.approval_logs (created_at);


-- ============================================================
-- 7. ASPIRATIONS / D-DAS
-- ============================================================
--
-- Mahasiswa TIDAK perlu memiliki akun.
--
-- Public submission akan ditangani melalui RLS/API pada migration
-- berikutnya.
--
-- Aspirasi sensitif dapat menggunakan mode anonim.
--
-- Kategori yang diperbolehkan untuk anonymous:
--   - sexual_harassment
--   - corruption
--   - bullying
--   - abuse_of_authority
--   - serious_ethics_violation
--   - violence
--
-- Persyaratan bukti minimum untuk aspirasi anonim akan ditegakkan
-- melalui function/trigger pada 05_functions_triggers.sql,
-- karena evidence disimpan pada tabel terpisah.
-- ============================================================

create table public.aspirations (
  id uuid primary key default gen_random_uuid(),

  period_id uuid not null references public.periods(id)
    on delete restrict,

  ticket_number text not null,

  title text not null,
  description text not null,

  category public.aspiration_category not null,

  is_anonymous boolean not null default false,

  sender_name text,
  sender_email text,
  sender_phone text,

  otp_verified boolean not null default false,

  status public.aspiration_status not null default 'submitted',

  assigned_organization_id uuid references public.organizations(id)
    on delete set null,

  submitted_at timestamptz not null default now(),

  reviewed_at timestamptz,
  completed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint aspirations_title_not_empty
    check (length(trim(title)) > 0),

  constraint aspirations_description_not_empty
    check (length(trim(description)) > 0),

  constraint aspirations_anonymous_category_check
    check (
      is_anonymous = false
      or category in (
        'sexual_harassment',
        'corruption',
        'bullying',
        'abuse_of_authority',
        'serious_ethics_violation',
        'violence'
      )
    ),

  constraint aspirations_anonymous_sender_check
    check (
      is_anonymous = false
      or sender_name is null
    )
);


create unique index aspirations_ticket_unique_idx
  on public.aspirations (ticket_number);

create index aspirations_period_idx
  on public.aspirations (period_id);

create index aspirations_status_idx
  on public.aspirations (status);

create index aspirations_category_idx
  on public.aspirations (category);

create index aspirations_organization_idx
  on public.aspirations (assigned_organization_id);

create index aspirations_submitted_idx
  on public.aspirations (submitted_at);

create index aspirations_status_period_idx
  on public.aspirations (status, period_id);


-- ============================================================
-- 8. ASPIRATION EVIDENCE
-- ============================================================
--
-- File fisik disimpan di Supabase Storage.
--
-- Tabel ini hanya menyimpan metadata file.
--
-- Untuk aspirasi anonim sensitif, file akan berada pada private
-- bucket dan aksesnya dikendalikan oleh 03_storage.sql +
-- 02_rls_policies.sql.
-- ============================================================

create table public.aspiration_evidence (
  id uuid primary key default gen_random_uuid(),

  aspiration_id uuid not null references public.aspirations(id)
    on delete cascade,

  file_name text not null,
  file_path text not null,

  file_type public.file_type not null,

  mime_type text,
  file_size bigint,

  uploaded_at timestamptz not null default now(),

  constraint aspiration_evidence_file_size_check
    check (
      file_size is null
      or file_size >= 0
    )
);


create index aspiration_evidence_aspiration_idx
  on public.aspiration_evidence (aspiration_id);

create index aspiration_evidence_file_type_idx
  on public.aspiration_evidence (file_type);


-- ============================================================
-- 9. ASPIRATION FORWARDING
-- ============================================================
--
-- Komisi 2 dapat meneruskan aspirasi kepada ORMAWA terkait.
-- ============================================================

create table public.aspiration_forwards (
  id uuid primary key default gen_random_uuid(),

  aspiration_id uuid not null references public.aspirations(id)
    on delete cascade,

  organization_id uuid not null references public.organizations(id)
    on delete restrict,

  forwarded_by uuid references public.profiles(id)
    on delete set null,

  instruction text,

  status public.forward_status not null default 'pending',

  forwarded_at timestamptz not null default now(),
  responded_at timestamptz,
  completed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


create index aspiration_forwards_aspiration_idx
  on public.aspiration_forwards (aspiration_id);

create index aspiration_forwards_organization_idx
  on public.aspiration_forwards (organization_id);

create index aspiration_forwards_status_idx
  on public.aspiration_forwards (status);

create index aspiration_forwards_org_status_idx
  on public.aspiration_forwards (organization_id, status);


-- ============================================================
-- 10. ASPIRATION RESPONSES
-- ============================================================
--
-- Viewer/ORMAWA dapat memberikan respons terhadap forwarding
-- yang memang ditujukan kepada organisasinya.
-- ============================================================

create table public.aspiration_responses (
  id uuid primary key default gen_random_uuid(),

  aspiration_id uuid not null references public.aspirations(id)
    on delete cascade,

  forward_id uuid references public.aspiration_forwards(id)
    on delete cascade,

  responder_id uuid references public.profiles(id)
    on delete set null,

  message text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint aspiration_responses_message_not_empty
    check (length(trim(message)) > 0)
);


create index aspiration_responses_aspiration_idx
  on public.aspiration_responses (aspiration_id);

create index aspiration_responses_forward_idx
  on public.aspiration_responses (forward_id);

create index aspiration_responses_responder_idx
  on public.aspiration_responses (responder_id);

create index aspiration_responses_created_idx
  on public.aspiration_responses (created_at);


-- ============================================================
-- 11. D-TRACE / TRANSPARENCY REPORTS
-- ============================================================

create table public.transparency_reports (
  id uuid primary key default gen_random_uuid(),

  period_id uuid not null references public.periods(id)
    on delete restrict,

  organization_id uuid references public.organizations(id)
    on delete set null,

  created_by uuid references public.profiles(id)
    on delete set null,

  title text not null,

  type public.transparency_type not null,

  status public.transparency_status not null default 'draft',

  summary text,
  body text,

  source_content_id uuid references public.contents(id)
    on delete set null,

  source_aspiration_id uuid references public.aspirations(id)
    on delete set null,

  published_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint transparency_reports_title_not_empty
    check (length(trim(title)) > 0)
);


create index transparency_reports_period_idx
  on public.transparency_reports (period_id);

create index transparency_reports_organization_idx
  on public.transparency_reports (organization_id);

create index transparency_reports_status_idx
  on public.transparency_reports (status);

create index transparency_reports_type_idx
  on public.transparency_reports (type);

create index transparency_reports_period_status_idx
  on public.transparency_reports (period_id, status);


-- ============================================================
-- 12. D-DAR / DOCUMENT REPOSITORY
-- ============================================================
--
-- visibility:
--
--   public
--       dapat dibaca/diunduh publik
--
--   internal
--       hanya akun internal DPM yang berwenang
--
--   restricted
--       membutuhkan Access Request
-- ============================================================

create table public.documents (
  id uuid primary key default gen_random_uuid(),

  period_id uuid not null references public.periods(id)
    on delete restrict,

  uploaded_by uuid references public.profiles(id)
    on delete set null,

  title text not null,

  category public.document_category not null,

  description text,

  file_name text not null,
  file_path text not null,

  mime_type text,
  file_size bigint,

  visibility public.document_visibility not null default 'internal',

  published_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint documents_title_not_empty
    check (length(trim(title)) > 0),

  constraint documents_file_size_check
    check (
      file_size is null
      or file_size >= 0
    )
);


create index documents_period_idx
  on public.documents (period_id);

create index documents_category_idx
  on public.documents (category);

create index documents_visibility_idx
  on public.documents (visibility);

create index documents_uploaded_by_idx
  on public.documents (uploaded_by);

create index documents_visibility_period_idx
  on public.documents (visibility, period_id);

create index documents_published_idx
  on public.documents (published_at);


-- ============================================================
-- 13. ACCESS REQUESTS
-- ============================================================
--
-- Viewer dapat meminta akses terhadap dokumen Restricted.
--
-- Jika disetujui, 05_functions_triggers.sql akan menangani
-- pemberian akses berbatas waktu berdasarkan expires_at.
-- ============================================================

create table public.access_requests (
  id uuid primary key default gen_random_uuid(),

  document_id uuid not null references public.documents(id)
    on delete cascade,

  requester_id uuid not null references public.profiles(id)
    on delete cascade,

  reason text not null,

  requested_duration_hours integer,

  status public.access_request_status not null default 'pending',

  reviewed_by uuid references public.profiles(id)
    on delete set null,

  review_notes text,

  approved_at timestamptz,
  rejected_at timestamptz,

  expires_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint access_requests_reason_not_empty
    check (length(trim(reason)) > 0),

  constraint access_requests_duration_check
    check (
      requested_duration_hours is null
      or requested_duration_hours > 0
    )
);


create index access_requests_document_idx
  on public.access_requests (document_id);

create index access_requests_requester_idx
  on public.access_requests (requester_id);

create index access_requests_status_idx
  on public.access_requests (status);

create index access_requests_expires_idx
  on public.access_requests (expires_at);

create index access_requests_requester_status_idx
  on public.access_requests (requester_id, status);


-- ============================================================
-- 14. NOTIFICATIONS
-- ============================================================
--
-- Digunakan untuk:
--   - Approval notification
--   - SLA escalation
--   - Access request
--   - Aspiration forwarding
--   - System notification
-- ============================================================

create table public.notifications (
  id uuid primary key default gen_random_uuid(),

  recipient_id uuid not null references public.profiles(id)
    on delete cascade,

  title text not null,
  message text not null,

  type text,

  entity_type text,
  entity_id uuid,

  is_read boolean not null default false,

  created_at timestamptz not null default now(),
  read_at timestamptz
);


create index notifications_recipient_idx
  on public.notifications (recipient_id);

create index notifications_unread_idx
  on public.notifications (recipient_id, is_read);

create index notifications_entity_idx
  on public.notifications (entity_type, entity_id);

create index notifications_created_idx
  on public.notifications (created_at);


-- ============================================================
-- 15. AUDIT LOGS
-- ============================================================
--
-- Audit log bersifat append-only secara konsep.
--
-- Trigger pengisian otomatis akan dibuat pada
-- 05_functions_triggers.sql.
--
-- Data yang direkam dapat mencakup:
--   - user_id
--   - action
--   - entity
--   - entity_id
--   - IP address
--   - user agent
--   - changeset JSON
--   - timestamp
-- ============================================================

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),

  user_id uuid references public.profiles(id)
    on delete set null,

  action text not null,
  entity text not null,

  entity_id uuid,

  ip_address inet,
  user_agent text,

  changeset_json jsonb,

  created_at timestamptz not null default now()
);


create index audit_logs_user_idx
  on public.audit_logs (user_id);

create index audit_logs_entity_idx
  on public.audit_logs (entity, entity_id);

create index audit_logs_action_idx
  on public.audit_logs (action);

create index audit_logs_created_idx
  on public.audit_logs (created_at);


-- ============================================================
-- 16. GENERIC UPDATED_AT FUNCTION
-- ============================================================
--
-- Fungsi teknis dasar.
--
-- Ini bukan workflow approval.
-- Ini bukan RLS.
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ============================================================
-- 17. UPDATED_AT TRIGGERS
-- ============================================================

create trigger periods_set_updated_at
before update on public.periods
for each row
execute function public.set_updated_at();


create trigger organizations_set_updated_at
before update on public.organizations
for each row
execute function public.set_updated_at();


create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();


create trigger contents_set_updated_at
before update on public.contents
for each row
execute function public.set_updated_at();


create trigger aspirations_set_updated_at
before update on public.aspirations
for each row
execute function public.set_updated_at();


create trigger aspiration_forwards_set_updated_at
before update on public.aspiration_forwards
for each row
execute function public.set_updated_at();


create trigger aspiration_responses_set_updated_at
before update on public.aspiration_responses
for each row
execute function public.set_updated_at();


create trigger transparency_reports_set_updated_at
before update on public.transparency_reports
for each row
execute function public.set_updated_at();


create trigger documents_set_updated_at
before update on public.documents
for each row
execute function public.set_updated_at();


create trigger access_requests_set_updated_at
before update on public.access_requests
for each row
execute function public.set_updated_at();


-- ============================================================
-- 18. ROW LEVEL SECURITY
-- ============================================================
--
-- RLS hanya DIAKTIFKAN di sini.
--
-- POLICY belum dibuat.
--
-- Seluruh policy akan dibuat secara terpisah pada:
--
--   02_rls_policies.sql
--
-- Dengan demikian prinsip default-deny PostgreSQL tetap berlaku
-- sampai policy yang tepat dipasang.
-- ============================================================

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
-- 19. FINAL SUPPORTING INDEXES
-- ============================================================

create index organizations_name_search_idx
  on public.organizations (lower(name));

create index profiles_name_search_idx
  on public.profiles (lower(full_name));

create index contents_title_search_idx
  on public.contents (lower(title));

create index aspirations_title_search_idx
  on public.aspirations (lower(title));

create index documents_title_search_idx
  on public.documents (lower(title));


-- ============================================================
-- 20. SCHEMA COMMENTS
-- ============================================================

comment on table public.periods is
  'Periode kepengurusan DPM FIPP. Hanya satu periode dapat aktif pada satu waktu.';

comment on table public.organizations is
  'Data organisasi mahasiswa/ORMAWA dalam lingkungan FIPP.';

comment on table public.profiles is
  'Profil bisnis pengguna aplikasi yang terhubung dengan Supabase Auth.';

comment on table public.contents is
  'Konten D-SIGHT dan Content Management. Setiap konten memiliki satu penanggung jawab utama melalui author_id.';

comment on table public.approval_logs is
  'Riwayat tindakan approval terhadap konten.';

comment on table public.aspirations is
  'Data aspirasi mahasiswa yang dikirim melalui D-DAS. Pengiriman tidak membutuhkan akun mahasiswa.';

comment on table public.aspiration_evidence is
  'Metadata bukti digital yang terkait dengan aspirasi. File fisik disimpan pada Supabase Storage.';

comment on table public.aspiration_forwards is
  'Riwayat penerusan aspirasi dari DPM kepada ORMAWA terkait.';

comment on table public.aspiration_responses is
  'Respons ORMAWA terhadap aspirasi yang diteruskan.';

comment on table public.transparency_reports is
  'Data laporan transparansi D-TRACE.';

comment on table public.documents is
  'Repositori dokumen D-DAR dengan klasifikasi public, internal, dan restricted.';

comment on table public.access_requests is
  'Permintaan akses sementara terhadap dokumen restricted.';

comment on table public.notifications is
  'Notifikasi internal aplikasi untuk pengguna terautentikasi.';

comment on table public.audit_logs is
  'Jejak audit transaksi dan perubahan data sistem.';


-- ============================================================
-- 21. FINAL CHECK CONSTRAINTS
-- ============================================================

-- Memastikan konten memiliki tepat satu penanggung jawab.
-- author_id sudah NOT NULL sehingga setiap konten wajib memiliki
-- satu author/assignee.

-- Memastikan aspiration anonymous hanya boleh untuk kategori
-- sensitif yang telah ditentukan.
-- Constraint sudah diterapkan pada tabel aspirations.

-- Memastikan periode hanya dapat memiliki satu active record.
-- Unique partial index sudah diterapkan pada periods.


-- ============================================================
-- END OF 01_schema.sql
-- ============================================================