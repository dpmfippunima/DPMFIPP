-- ============================================================
-- DPM FIPP CMS
-- SUPABASE FUNCTIONS & TRIGGERS V1 - FINAL
-- Migration: 05_functions_triggers.sql
-- Database: PostgreSQL / Supabase
--
-- FINAL VERSION
--
-- DEPENDENCIES:
--   01_schema.sql  -> SUDAH SUKSES
--   02_rls_policies.sql -> SUDAH SUKSES
--   03_storage.sql -> SUDAH SUKSES
--   04_seed.sql -> SUDAH SUKSES
--
-- IMPORTANT:
--
-- 1. JANGAN DROP FUNCTION has_role().
--    Fungsi tersebut digunakan oleh RLS Policy.
--
-- 2. JANGAN DROP FUNCTION is_super_admin(), dll.
--    Fungsi tersebut juga digunakan oleh RLS Policy.
--
-- 3. File ini sengaja menggunakan CREATE OR REPLACE
--    untuk fungsi yang aman diganti tanpa merusak dependency RLS.
--
-- 4. Scheduler functions TIDAK diberikan EXECUTE kepada
--    authenticated agar user biasa tidak dapat menjalankan
--    escalation/expiration secara manual.
--
-- 5. Audit trigger dibuat idempotent:
--    trigger lama dihapus per nama lalu dibuat kembali.
--
-- ============================================================


-- ============================================================
-- 0. PRE-FLIGHT CHECK
-- ============================================================
--
-- Pastikan schema dasar dan fungsi has_role dari migration 02
-- benar-benar tersedia.
--
-- Jika bagian ini gagal, JANGAN lanjutkan dengan memodifikasi
-- database. Periksa kembali migration 01-02.
-- ============================================================

do $$
begin

  if to_regclass('public.profiles') is null then
    raise exception
      '05 FINAL gagal: tabel public.profiles tidak ditemukan.';
  end if;

  if to_regclass('public.contents') is null then
    raise exception
      '05 FINAL gagal: tabel public.contents tidak ditemukan.';
  end if;

  if to_regclass('public.audit_logs') is null then
    raise exception
      '05 FINAL gagal: tabel public.audit_logs tidak ditemukan.';
  end if;

  if to_regprocedure('public.has_role(public.user_role)') is null then
    raise exception
      '05 FINAL gagal: public.has_role(public.user_role) tidak ditemukan. Pastikan 02_rls_policies.sql berhasil.';
  end if;

end $$;


-- ============================================================
-- 1. ROLE SHORTCUT FUNCTIONS
-- ============================================================
--
-- CATATAN:
--   public.has_role(...) TIDAK disentuh.
--
-- Fungsi berikut aman menggunakan CREATE OR REPLACE karena
-- signature-nya tidak berubah.
-- ============================================================


create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role('super_admin'::public.user_role);
$$;


create or replace function public.is_secretary()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role('secretary'::public.user_role);
$$;


create or replace function public.is_commission_1()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role('commission_1'::public.user_role);
$$;


create or replace function public.is_commission_2()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role('commission_2'::public.user_role);
$$;


create or replace function public.is_viewer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role('viewer'::public.user_role);
$$;


create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in (
        'super_admin'::public.user_role,
        'secretary'::public.user_role,
        'commission_1'::public.user_role,
        'commission_2'::public.user_role
      )
      and p.status = 'active'::public.user_status
      and p.deleted_at is null
  );
$$;


-- ============================================================
-- 2. CURRENT USER PROFILE
-- ============================================================

create or replace function public.current_user_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public
as $$
  select p
  from public.profiles p
  where p.id = auth.uid()
    and p.status = 'active'::public.user_status
    and p.deleted_at is null
  limit 1;
$$;


-- ============================================================
-- 3. AUDIT LOG WRITER
-- ============================================================
--
-- Fungsi ini dipakai oleh audit trigger.
--
-- IP menggunakan inet_client_addr() agar tidak gagal karena
-- header proxy yang bukan format inet.
--
-- User-Agent dibaca secara aman dari request.headers.
-- ============================================================

create or replace function public.write_audit_log(
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_changeset jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_user_agent text;
begin

  begin
    v_user_agent :=
      nullif(
        current_setting('request.headers', true),
        ''
      )::jsonb ->> 'user-agent';
  exception
    when others then
      v_user_agent := null;
  end;

  insert into public.audit_logs (
    user_id,
    action,
    entity,
    entity_id,
    ip_address,
    user_agent,
    changeset_json
  )
  values (
    auth.uid(),
    p_action,
    p_entity,
    p_entity_id,
    inet_client_addr(),
    v_user_agent,
    p_changeset
  )
  returning id into v_id;

  return v_id;

exception
  when others then
    /*
     * Audit failure tidak boleh membatalkan transaksi utama.
     */
    return null;
end;
$$;


-- ============================================================
-- 4. GENERIC AUDIT TRIGGER FUNCTION
-- ============================================================
--
-- Mencatat:
--   INSERT
--   UPDATE
--   DELETE
--
-- Tidak dipasang pada audit_logs agar tidak recursive.
-- ============================================================

create or replace function public.audit_row_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_entity_id uuid;
  v_changes jsonb;
begin

  if tg_op = 'INSERT' then

    v_action := 'create';

    begin
      v_entity_id := (to_jsonb(new)->>'id')::uuid;
    exception
      when others then
        v_entity_id := null;
    end;

    v_changes := jsonb_build_object(
      'new',
      to_jsonb(new)
    );

  elsif tg_op = 'UPDATE' then

    v_action := 'update';

    begin
      v_entity_id := (to_jsonb(new)->>'id')::uuid;
    exception
      when others then
        v_entity_id := null;
    end;

    v_changes := jsonb_build_object(
      'old',
      to_jsonb(old),
      'new',
      to_jsonb(new)
    );

  elsif tg_op = 'DELETE' then

    v_action := 'delete';

    begin
      v_entity_id := (to_jsonb(old)->>'id')::uuid;
    exception
      when others then
        v_entity_id := null;
    end;

    v_changes := jsonb_build_object(
      'old',
      to_jsonb(old)
    );

  else
    return null;
  end if;


  perform public.write_audit_log(
    v_action,
    tg_table_name,
    v_entity_id,
    v_changes
  );


  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;

end;
$$;


-- ============================================================
-- 5. CONTENT SUBMISSION
-- ============================================================
--
-- Commission 1:
--
--   draft
--      ↓
--   pending_secretary
--
-- Hanya pemilik content yang dapat submit.
-- ============================================================

create or replace function public.submit_content(
  p_content_id uuid
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
begin

  if not public.is_commission_1() then
    raise exception
      'Hanya Commission 1 yang dapat submit content.';
  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  if v_content.author_id <> auth.uid() then
    raise exception
      'Anda bukan penanggung jawab content ini.';
  end if;


  if v_content.status <> 'draft'::public.content_status then
    raise exception
      'Content hanya dapat disubmit dari status draft.';
  end if;


  update public.contents
  set
    status = 'pending_secretary'::public.content_status,
    submitted_at = now(),
    updated_at = now()
  where id = p_content_id
  returning * into v_content;


  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  values (
    p_content_id,
    auth.uid(),
    'submitted'::public.approval_action,
    'Content submitted to Secretary.'
  );


  return v_content;

end;
$$;


-- ============================================================
-- 6. CONTENT APPROVAL
-- ============================================================
--
-- Secretary:
--   hanya dapat approve pending_secretary.
--
-- Super Admin:
--   dapat approve pending_secretary maupun
--   pending_super_admin.
--
-- Approval menghasilkan published.
-- ============================================================

create or replace function public.approve_content(
  p_content_id uuid
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
  v_is_super_admin boolean;
  v_is_secretary boolean;
begin

  v_is_super_admin := public.is_super_admin();
  v_is_secretary := public.is_secretary();


  if not v_is_secretary
     and not v_is_super_admin then

    raise exception
      'Hanya Secretary atau Super Admin yang dapat melakukan approval.';

  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  /*
   * Secretary hanya menangani tahap pertama.
   */
  if v_is_secretary
     and not v_is_super_admin
     and v_content.status <> 'pending_secretary'::public.content_status then

    raise exception
      'Secretary hanya dapat approve content pada tahap pending_secretary.';

  end if;


  /*
   * Super Admin dapat menangani kedua tahap.
   */
  if v_is_super_admin
     and v_content.status not in (
       'pending_secretary'::public.content_status,
       'pending_super_admin'::public.content_status
     ) then

    raise exception
      'Content tidak berada pada tahap approval.';

  end if;


  update public.contents
  set
    status = 'published'::public.content_status,
    published_at = coalesce(published_at, now()),

    secretary_reviewed_at =
      case
        when v_is_secretary
          and v_content.status = 'pending_secretary'::public.content_status
        then now()
        else secretary_reviewed_at
      end,

    super_admin_reviewed_at =
      case
        when v_is_super_admin
          and v_content.status = 'pending_super_admin'::public.content_status
        then now()
        else super_admin_reviewed_at
      end,

    updated_at = now()

  where id = p_content_id

  returning * into v_content;


  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  values (
    p_content_id,
    auth.uid(),
    'approved'::public.approval_action,
    case
      when v_is_super_admin
        then 'Content approved by Super Admin.'
      else
        'Content approved by Secretary.'
    end
  );


  return v_content;

end;
$$;


-- ============================================================
-- 7. REQUEST CONTENT REVISION
-- ============================================================

create or replace function public.request_content_revision(
  p_content_id uuid,
  p_notes text
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
begin

  if not public.is_secretary()
     and not public.is_super_admin() then

    raise exception
      'Hanya Secretary atau Super Admin yang dapat meminta revisi.';

  end if;


  if nullif(trim(p_notes), '') is null then
    raise exception
      'Catatan revisi wajib diisi.';
  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  if v_content.status not in (
    'pending_secretary'::public.content_status,
    'pending_super_admin'::public.content_status
  ) then

    raise exception
      'Content tidak berada pada tahap review.';

  end if;


  update public.contents
  set
    status = 'revision'::public.content_status,
    updated_at = now()
  where id = p_content_id
  returning * into v_content;


  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  values (
    p_content_id,
    auth.uid(),
    'revision'::public.approval_action,
    p_notes
  );


  return v_content;

end;
$$;


-- ============================================================
-- 8. REJECT CONTENT
-- ============================================================

create or replace function public.reject_content(
  p_content_id uuid,
  p_notes text
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
begin

  if not public.is_secretary()
     and not public.is_super_admin() then

    raise exception
      'Hanya Secretary atau Super Admin yang dapat menolak content.';

  end if;


  if nullif(trim(p_notes), '') is null then
    raise exception
      'Alasan penolakan wajib diisi.';
  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  if v_content.status not in (
    'pending_secretary'::public.content_status,
    'pending_super_admin'::public.content_status
  ) then

    raise exception
      'Content tidak berada pada tahap review.';

  end if;


  update public.contents
  set
    status = 'rejected'::public.content_status,
    updated_at = now()
  where id = p_content_id
  returning * into v_content;


  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  values (
    p_content_id,
    auth.uid(),
    'rejected'::public.approval_action,
    p_notes
  );


  return v_content;

end;
$$;


-- ============================================================
-- 9. PUBLISH CONTENT
-- ============================================================
--
-- Publish hanya dapat dilakukan terhadap content yang sudah
-- berstatus published.
--
-- Fungsi ini mempertahankan published_at apabila sudah ada.
-- ============================================================

create or replace function public.publish_content(
  p_content_id uuid
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
begin

  if not public.is_secretary()
     and not public.is_super_admin() then

    raise exception
      'Hanya Secretary atau Super Admin yang dapat publish.';

  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  if v_content.status <> 'published'::public.content_status then
    raise exception
      'Content harus berstatus published sebelum dipublish.';
  end if;


  update public.contents
  set
    published_at = coalesce(published_at, now()),
    updated_at = now()
  where id = p_content_id
  returning * into v_content;


  return v_content;

end;
$$;


-- ============================================================
-- 10. ARCHIVE CONTENT
-- ============================================================

create or replace function public.archive_content(
  p_content_id uuid
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
begin

  if not public.is_secretary()
     and not public.is_super_admin() then

    raise exception
      'Hanya Secretary atau Super Admin yang dapat archive.';

  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  if v_content.status <> 'published'::public.content_status then
    raise exception
      'Hanya content published yang dapat diarsipkan.';
  end if;


  update public.contents
  set
    status = 'archived'::public.content_status,
    archived_at = now(),
    updated_at = now()
  where id = p_content_id
  returning * into v_content;


  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  values (
    p_content_id,
    auth.uid(),
    'approved'::public.approval_action,
    'Content archived.'
  );


  return v_content;

end;
$$;


-- ============================================================
-- 11. ESCALATE PENDING CONTENTS
-- ============================================================
--
-- SLA:
--
-- pending_secretary
--       |
--       | 36 jam
--       v
-- pending_super_admin
--
-- HANYA scheduler/system yang seharusnya menjalankan fungsi ini.
--
-- Fungsi mengembalikan jumlah content yang benar-benar
-- berhasil di-escalate dan membuat SATU approval log per row.
--
-- Tidak menggunakan updated_at sebagai cara mencari row yang
-- baru di-update, sehingga tidak menghasilkan duplicate audit/
-- approval log.
-- ============================================================

create or replace function public.escalate_pending_contents()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin

  with escalated as (
    update public.contents
    set
      status = 'pending_super_admin'::public.content_status,
      updated_at = now()
    where status = 'pending_secretary'::public.content_status
      and submitted_at is not null
      and submitted_at <= now() - interval '36 hours'
      and deleted_at is null
    returning id
  )
  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  select
    e.id,
    null,
    'escalated'::public.approval_action,
    'Automatically escalated after 36 hours.'
  from escalated e;


  get diagnostics v_count = row_count;


  return v_count;

end;
$$;


-- ============================================================
-- 12. SELF APPROVAL FALLBACK
-- ============================================================
--
-- Timeline:
--
-- T+0
--   Commission 1 submit
--
-- T+36
--   Secretary timeout
--   -> Super Admin stage
--
-- T+48
--   Super Admin juga timeout 12 jam
--   -> Commission 1 dapat fallback self approval
--
-- Self approval hanya:
--   - Commission 1
--   - pemilik content
--   - status pending_super_admin
--   - minimal 48 jam sejak submitted_at
-- ============================================================

create or replace function public.self_approve_content(
  p_content_id uuid
)
returns public.contents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents;
begin

  if not public.is_commission_1() then
    raise exception
      'Self approval hanya dapat dilakukan oleh Commission 1.';
  end if;


  select *
  into v_content
  from public.contents
  where id = p_content_id
    and deleted_at is null
  for update;


  if not found then
    raise exception
      'Content tidak ditemukan.';
  end if;


  if v_content.author_id <> auth.uid() then
    raise exception
      'Self approval hanya dapat dilakukan oleh penanggung jawab content.';
  end if;


  if v_content.status <> 'pending_super_admin'::public.content_status then
    raise exception
      'Content belum berada pada tahap fallback.';
  end if;


  if v_content.submitted_at is null then
    raise exception
      'Waktu submit tidak tersedia.';
  end if;


  /*
   * 36 jam Secretary + 12 jam Super Admin = 48 jam.
   */
  if v_content.submitted_at >
     now() - interval '48 hours' then

    raise exception
      'Fallback self approval belum aktif. Tunggu sampai 48 jam setelah submit.';

  end if;


  update public.contents
  set
    status = 'published'::public.content_status,
    published_at = coalesce(published_at, now()),
    updated_at = now()
  where id = p_content_id
  returning * into v_content;


  insert into public.approval_logs (
    content_id,
    actor_id,
    action,
    notes
  )
  values (
    p_content_id,
    auth.uid(),
    'self_approved'::public.approval_action,
    'Fallback self approval after Secretary and Super Admin timeout.'
  );


  return v_content;

end;
$$;


-- ============================================================
-- 13. APPROVE ACCESS REQUEST
-- ============================================================
--
-- Hanya Super Admin.
--
-- Default duration:
--   24 jam
--
-- Minimum duration:
--   1 jam
-- ============================================================

create or replace function public.approve_access_request(
  p_request_id uuid
)
returns public.access_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.access_requests;
  v_duration integer;
begin

  if not public.is_super_admin() then
    raise exception
      'Hanya Super Admin yang dapat menyetujui Access Request.';
  end if;


  select *
  into v_request
  from public.access_requests
  where id = p_request_id
  for update;


  if not found then
    raise exception
      'Access Request tidak ditemukan.';
  end if;


  if v_request.status <> 'pending'::public.access_request_status then
    raise exception
      'Access Request tidak berada pada status pending.';
  end if;


  v_duration := greatest(
    coalesce(v_request.requested_duration_hours, 24),
    1
  );


  update public.access_requests
  set
    status = 'approved'::public.access_request_status,
    reviewed_by = auth.uid(),
    approved_at = now(),
    rejected_at = null,
    expires_at = now() + make_interval(hours => v_duration),
    updated_at = now()
  where id = p_request_id
  returning * into v_request;


  return v_request;

end;
$$;


-- ============================================================
-- 14. REJECT ACCESS REQUEST
-- ============================================================

create or replace function public.reject_access_request(
  p_request_id uuid,
  p_notes text
)
returns public.access_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.access_requests;
begin

  if not public.is_super_admin() then
    raise exception
      'Hanya Super Admin yang dapat menolak Access Request.';
  end if;


  select *
  into v_request
  from public.access_requests
  where id = p_request_id
  for update;


  if not found then
    raise exception
      'Access Request tidak ditemukan.';
  end if;


  if v_request.status <> 'pending'::public.access_request_status then
    raise exception
      'Access Request tidak berada pada status pending.';
  end if;


  update public.access_requests
  set
    status = 'rejected'::public.access_request_status,
    reviewed_by = auth.uid(),
    review_notes = nullif(trim(p_notes), ''),
    approved_at = null,
    rejected_at = now(),
    expires_at = null,
    updated_at = now()
  where id = p_request_id
  returning * into v_request;


  return v_request;

end;
$$;


-- ============================================================
-- 15. EXPIRE ACCESS REQUESTS
-- ============================================================
--
-- approved + expires_at sudah lewat
--       ↓
-- expired
--
-- Fungsi untuk scheduler/system.
-- ============================================================

create or replace function public.expire_access_requests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin

  update public.access_requests
  set
    status = 'expired'::public.access_request_status,
    updated_at = now()
  where status = 'approved'::public.access_request_status
    and expires_at is not null
    and expires_at <= now();


  get diagnostics v_count = row_count;


  return v_count;

end;
$$;


-- ============================================================
-- 16. REMOVE OLD AUDIT TRIGGERS
-- ============================================================
--
-- Hanya trigger dengan nama yang kita kelola.
--
-- TIDAK menghapus trigger lain di database.
-- ============================================================

drop trigger if exists audit_periods
on public.periods;

drop trigger if exists audit_organizations
on public.organizations;

drop trigger if exists audit_profiles
on public.profiles;

drop trigger if exists audit_contents
on public.contents;

drop trigger if exists audit_approval_logs
on public.approval_logs;

drop trigger if exists audit_aspirations
on public.aspirations;

drop trigger if exists audit_aspiration_evidence
on public.aspiration_evidence;

drop trigger if exists audit_aspiration_forwards
on public.aspiration_forwards;

drop trigger if exists audit_aspiration_responses
on public.aspiration_responses;

drop trigger if exists audit_transparency_reports
on public.transparency_reports;

drop trigger if exists audit_documents
on public.documents;

drop trigger if exists audit_access_requests
on public.access_requests;

drop trigger if exists audit_notifications
on public.notifications;


-- ============================================================
-- 17. CREATE FINAL AUDIT TRIGGERS
-- ============================================================

create trigger audit_periods
after insert or update or delete
on public.periods
for each row
execute function public.audit_row_changes();


create trigger audit_organizations
after insert or update or delete
on public.organizations
for each row
execute function public.audit_row_changes();


create trigger audit_profiles
after insert or update or delete
on public.profiles
for each row
execute function public.audit_row_changes();


create trigger audit_contents
after insert or update or delete
on public.contents
for each row
execute function public.audit_row_changes();


create trigger audit_approval_logs
after insert or update or delete
on public.approval_logs
for each row
execute function public.audit_row_changes();


create trigger audit_aspirations
after insert or update or delete
on public.aspirations
for each row
execute function public.audit_row_changes();


create trigger audit_aspiration_evidence
after insert or update or delete
on public.aspiration_evidence
for each row
execute function public.audit_row_changes();


create trigger audit_aspiration_forwards
after insert or update or delete
on public.aspiration_forwards
for each row
execute function public.audit_row_changes();


create trigger audit_aspiration_responses
after insert or update or delete
on public.aspiration_responses
for each row
execute function public.audit_row_changes();


create trigger audit_transparency_reports
after insert or update or delete
on public.transparency_reports
for each row
execute function public.audit_row_changes();


create trigger audit_documents
after insert or update or delete
on public.documents
for each row
execute function public.audit_row_changes();


create trigger audit_access_requests
after insert or update or delete
on public.access_requests
for each row
execute function public.audit_row_changes();


create trigger audit_notifications
after insert or update or delete
on public.notifications
for each row
execute function public.audit_row_changes();


-- ============================================================
-- 18. FUNCTION PRIVILEGES
-- ============================================================
--
-- SECURITY DEFINER bukan berarti semua orang otomatis boleh
-- memanggil fungsi.
--
-- Client application:
--   authenticated
--
-- Scheduler/system:
--   service_role
--
-- has_role() TIDAK diubah privilege-nya di sini karena
-- fungsi tersebut sudah menjadi dependency RLS dari migration 02.
-- ============================================================


revoke all on function public.is_super_admin()
from public, anon, authenticated;

grant execute on function public.is_super_admin()
to authenticated;


revoke all on function public.is_secretary()
from public, anon, authenticated;

grant execute on function public.is_secretary()
to authenticated;


revoke all on function public.is_commission_1()
from public, anon, authenticated;

grant execute on function public.is_commission_1()
to authenticated;


revoke all on function public.is_commission_2()
from public, anon, authenticated;

grant execute on function public.is_commission_2()
to authenticated;


revoke all on function public.is_viewer()
from public, anon, authenticated;

grant execute on function public.is_viewer()
to authenticated;


revoke all on function public.is_staff()
from public, anon, authenticated;

grant execute on function public.is_staff()
to authenticated;


revoke all on function public.current_user_profile()
from public, anon, authenticated;

grant execute on function public.current_user_profile()
to authenticated;


revoke all on function public.submit_content(uuid)
from public, anon, authenticated;

grant execute on function public.submit_content(uuid)
to authenticated;


revoke all on function public.approve_content(uuid)
from public, anon, authenticated;

grant execute on function public.approve_content(uuid)
to authenticated;


revoke all on function public.request_content_revision(uuid, text)
from public, anon, authenticated;

grant execute on function public.request_content_revision(uuid, text)
to authenticated;


revoke all on function public.reject_content(uuid, text)
from public, anon, authenticated;

grant execute on function public.reject_content(uuid, text)
to authenticated;


revoke all on function public.publish_content(uuid)
from public, anon, authenticated;

grant execute on function public.publish_content(uuid)
to authenticated;


revoke all on function public.archive_content(uuid)
from public, anon, authenticated;

grant execute on function public.archive_content(uuid)
to authenticated;


revoke all on function public.self_approve_content(uuid)
from public, anon, authenticated;

grant execute on function public.self_approve_content(uuid)
to authenticated;


revoke all on function public.approve_access_request(uuid)
from public, anon, authenticated;

grant execute on function public.approve_access_request(uuid)
to authenticated;


revoke all on function public.reject_access_request(uuid, text)
from public, anon, authenticated;

grant execute on function public.reject_access_request(uuid, text)
to authenticated;


-- ============================================================
-- SCHEDULER FUNCTIONS
-- ============================================================
--
-- Tidak diberikan kepada authenticated.
--
-- Fungsi ini idealnya dipanggil oleh scheduler / pg_cron /
-- service backend.
-- ============================================================

revoke all on function public.escalate_pending_contents()
from public, anon, authenticated;

grant execute on function public.escalate_pending_contents()
to service_role;


revoke all on function public.expire_access_requests()
from public, anon, authenticated;

grant execute on function public.expire_access_requests()
to service_role;


-- ============================================================
-- INTERNAL AUDIT FUNCTIONS
-- ============================================================
--
-- Tidak perlu dipanggil langsung oleh client.
-- Trigger akan menjalankannya.
-- ============================================================

revoke all on function public.write_audit_log(
  text,
  text,
  uuid,
  jsonb
)
from public, anon, authenticated;


revoke all on function public.audit_row_changes()
from public, anon, authenticated;


-- ============================================================
-- 19. FUNCTION SECURITY SETTINGS
-- ============================================================

alter function public.is_super_admin()
  set search_path = public;

alter function public.is_secretary()
  set search_path = public;

alter function public.is_commission_1()
  set search_path = public;

alter function public.is_commission_2()
  set search_path = public;

alter function public.is_viewer()
  set search_path = public;

alter function public.is_staff()
  set search_path = public;

alter function public.current_user_profile()
  set search_path = public;

alter function public.write_audit_log(
  text,
  text,
  uuid,
  jsonb
)
set search_path = public;

alter function public.audit_row_changes()
  set search_path = public;

alter function public.submit_content(uuid)
  set search_path = public;

alter function public.approve_content(uuid)
  set search_path = public;

alter function public.request_content_revision(uuid, text)
  set search_path = public;

alter function public.reject_content(uuid, text)
  set search_path = public;

alter function public.publish_content(uuid)
  set search_path = public;

alter function public.archive_content(uuid)
  set search_path = public;

alter function public.escalate_pending_contents()
  set search_path = public;

alter function public.self_approve_content(uuid)
  set search_path = public;

alter function public.approve_access_request(uuid)
  set search_path = public;

alter function public.reject_access_request(uuid, text)
  set search_path = public;

alter function public.expire_access_requests()
  set search_path = public;


-- ============================================================
-- 20. FINAL VERIFICATION - REQUIRED FUNCTIONS
-- ============================================================

do $$
declare
  v_missing text;
begin

  select string_agg(x.name, ', ' order by x.name)
  into v_missing
  from (
    values
      ('is_super_admin', 'public.is_super_admin()'),
      ('is_secretary', 'public.is_secretary()'),
      ('is_commission_1', 'public.is_commission_1()'),
      ('is_commission_2', 'public.is_commission_2()'),
      ('is_viewer', 'public.is_viewer()'),
      ('is_staff', 'public.is_staff()'),
      ('current_user_profile', 'public.current_user_profile()'),
      ('submit_content', 'public.submit_content(uuid)'),
      ('approve_content', 'public.approve_content(uuid)'),
      ('request_content_revision', 'public.request_content_revision(uuid,text)'),
      ('reject_content', 'public.reject_content(uuid,text)'),
      ('publish_content', 'public.publish_content(uuid)'),
      ('archive_content', 'public.archive_content(uuid)'),
      ('escalate_pending_contents', 'public.escalate_pending_contents()'),
      ('self_approve_content', 'public.self_approve_content(uuid)'),
      ('approve_access_request', 'public.approve_access_request(uuid)'),
      ('reject_access_request', 'public.reject_access_request(uuid,text)'),
      ('expire_access_requests', 'public.expire_access_requests()'),
      ('write_audit_log', 'public.write_audit_log(text,text,uuid,jsonb)'),
      ('audit_row_changes', 'public.audit_row_changes()')
  ) as x(name, signature)
  where to_regprocedure(x.signature) is null;


  if v_missing is not null then
    raise exception
      '05 FINAL gagal: fungsi berikut tidak ditemukan: %',
      v_missing;
  end if;

end $$;


-- ============================================================
-- 21. FINAL VERIFICATION - AUDIT TRIGGERS
-- ============================================================

do $$
declare
  v_trigger_count integer;
begin

  select count(*)
  into v_trigger_count
  from pg_trigger t
  join pg_class c
    on c.oid = t.tgrelid
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and t.tgenabled <> 'D'
    and t.tgname in (
      'audit_periods',
      'audit_organizations',
      'audit_profiles',
      'audit_contents',
      'audit_approval_logs',
      'audit_aspirations',
      'audit_aspiration_evidence',
      'audit_aspiration_forwards',
      'audit_aspiration_responses',
      'audit_transparency_reports',
      'audit_documents',
      'audit_access_requests',
      'audit_notifications'
    );


  if v_trigger_count <> 13 then
    raise exception
      '05 FINAL gagal: expected 13 audit triggers, ditemukan %.',
      v_trigger_count;
  end if;

end $$;


-- ============================================================
-- 22. FINAL VERIFICATION - CORE TABLES
-- ============================================================

do $$
declare
  v_missing text;
begin

  select string_agg(x.table_name, ', ' order by x.table_name)
  into v_missing
  from (
    values
      ('periods'),
      ('organizations'),
      ('profiles'),
      ('contents'),
      ('approval_logs'),
      ('aspirations'),
      ('aspiration_evidence'),
      ('aspiration_forwards'),
      ('aspiration_responses'),
      ('transparency_reports'),
      ('documents'),
      ('access_requests'),
      ('notifications'),
      ('audit_logs')
  ) as x(table_name)
  where to_regclass('public.' || x.table_name) is null;


  if v_missing is not null then
    raise exception
      '05 FINAL gagal: tabel berikut tidak ditemukan: %',
      v_missing;
  end if;

end $$;


-- ============================================================
-- 23. FINAL VERIFICATION - SEED
-- ============================================================

do $$
declare
  v_period_count integer;
  v_active_count integer;
  v_org_count integer;
begin

  select count(*)
  into v_period_count
  from public.periods
  where year_start = 2026
    and year_end = 2027;


  if v_period_count <> 1 then
    raise exception
      '05 FINAL gagal: periode 2026/2027 tidak ditemukan secara unik.';
  end if;


  select count(*)
  into v_active_count
  from public.periods
  where is_active = true;


  if v_active_count <> 1 then
    raise exception
      '05 FINAL gagal: harus ada tepat satu periode aktif. Ditemukan %.',
      v_active_count;
  end if;


  select count(*)
  into v_org_count
  from public.organizations o
  join public.periods p
    on p.id = o.period_id
  where p.year_start = 2026
    and p.year_end = 2027
    and o.status = 'active'::public.organization_status
    and o.deleted_at is null;


  if v_org_count < 12 then
    raise exception
      '05 FINAL gagal: ORMAWA aktif kurang dari 12. Ditemukan %.',
      v_org_count;
  end if;

end $$;


-- ============================================================
-- 24. FINAL STATUS
-- ============================================================
--
-- Jika SQL Editor berhasil mencapai bagian ini tanpa ERROR,
-- maka:
--
--   01_schema.sql              OK
--   02_rls_policies.sql        OK
--   03_storage.sql             OK
--   04_seed.sql                OK
--   05_functions_triggers.sql  OK
--
--
-- CONTENT WORKFLOW
--
-- Commission 1
--      |
--      | submit_content()
--      v
-- draft
--      |
--      v
-- pending_secretary
--      |
--      | Secretary approve
--      v
-- published
--
--
-- TIMEOUT WORKFLOW
--
-- pending_secretary
--      |
--      | 36 jam
--      v
-- pending_super_admin
--      |
--      | 12 jam
--      v
-- fallback tersedia
--      |
--      v
-- Commission 1 self_approve_content()
--      |
--      v
-- published
--
--
-- ACCESS REQUEST
--
-- Viewer
--      |
--      v
-- pending
--      |
--      +---- Super Admin approve ----> approved
--      |                                |
--      |                                | expires_at
--      |                                v
--      |                              expired
--      |
--      +---- Super Admin reject -----> rejected
--
--
-- AUDIT
--
-- INSERT / UPDATE / DELETE
--          |
--          v
-- audit_row_changes()
--          |
--          v
-- write_audit_log()
--          |
--          v
-- audit_logs
--
--
-- SCHEDULER
--
-- escalate_pending_contents()
--      -> 36-hour Secretary SLA
--
-- expire_access_requests()
--      -> automatic access expiration
--
-- ============================================================


-- ============================================================
-- END OF 05_functions_triggers.sql FINAL
-- ============================================================