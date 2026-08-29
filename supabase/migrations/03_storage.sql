-- ============================================================
-- DPM FIPP CMS
-- SUPABASE STORAGE V1
-- Migration: 03_storage.sql
-- Database: PostgreSQL / Supabase
--
-- PURPOSE:
--   Menyiapkan Supabase Storage bucket dan Storage Policies.
--
-- DEPENDENCIES:
--   01_schema.sql
--   02_rls_policies.sql
--
-- BUCKETS:
--   1. dpm-public
--      Media publik / featured image / aset publik.
--
--   2. dpm-documents
--      Arsip D-DAR.
--
--   3. dpm-aspiration-evidence
--      Bukti aspirasi D-DAS.
--      PRIVATE.
--
-- IMPORTANT:
--   - Tidak mengubah ownership storage.objects.
--   - Tidak menjalankan ALTER TABLE storage.objects.
--   - Tidak membuat trigger pada storage.objects.
--   - Policy menggunakan storage.objects yang memang disediakan
--     oleh Supabase Storage.
-- ============================================================


-- ============================================================
-- 0. STORAGE BUCKETS
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public
)
values
  (
    'dpm-public',
    'dpm-public',
    true
  ),
  (
    'dpm-documents',
    'dpm-documents',
    false
  ),
  (
    'dpm-aspiration-evidence',
    'dpm-aspiration-evidence',
    false
  )
on conflict (id) do update
set
  public = excluded.public;


-- ============================================================
-- 1. HELPER FUNCTION
-- ============================================================
--
-- Mengambil role user dari public.profiles.
--
-- Function ini hanya membaca profile.
-- Hak akses sebenarnya tetap ditentukan oleh Storage Policy.
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


-- ============================================================
-- 2. STORAGE POLICIES
-- ============================================================
--
-- Semua policy dibuat pada storage.objects.
--
-- Kita TIDAK:
--   ALTER TABLE storage.objects
--   CREATE TRIGGER storage.objects
--   Mengubah ownership storage.objects
--
-- Supabase sudah menyediakan tabel tersebut.
-- ============================================================


-- ============================================================
-- 2A. DPM-PUBLIC
-- ============================================================
--
-- Bucket:
--   dpm-public
--
-- Fungsi:
--   Featured image, logo, gambar publik, dan media publik.
--
-- READ:
--   Publik.
--
-- INSERT / UPDATE / DELETE:
--   Super Admin dan Secretary.
-- ============================================================


drop policy if exists "dpm_public_select" on storage.objects;

create policy "dpm_public_select"
on storage.objects
for select
using (
  bucket_id = 'dpm-public'
);


drop policy if exists "dpm_public_insert_admin" on storage.objects;

create policy "dpm_public_insert_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'dpm-public'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
);


drop policy if exists "dpm_public_update_admin" on storage.objects;

create policy "dpm_public_update_admin"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'dpm-public'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
)
with check (
  bucket_id = 'dpm-public'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
);


drop policy if exists "dpm_public_delete_admin" on storage.objects;

create policy "dpm_public_delete_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'dpm-public'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
);


-- ============================================================
-- 2B. DPM-DOCUMENTS
-- ============================================================
--
-- Bucket:
--   dpm-documents
--
-- Fungsi:
--   D-DAR.
--
-- Bucket PRIVATE.
--
-- READ:
--   Super Admin
--   Secretary
--   Commission 1
--   Commission 2
--
--   Viewer hanya dapat membaca dokumen PUBLIC melalui
--   aplikasi berdasarkan visibility pada public.documents.
--
-- WRITE:
--   Super Admin
--   Secretary
--
-- DELETE:
--   Super Admin
--   Secretary
-- ============================================================


drop policy if exists "dpm_documents_select_internal" on storage.objects;

create policy "dpm_documents_select_internal"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'dpm-documents'
  and public.current_user_role() in (
    'super_admin',
    'secretary',
    'commission_1',
    'commission_2'
  )
);


drop policy if exists "dpm_documents_insert_admin" on storage.objects;

create policy "dpm_documents_insert_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'dpm-documents'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
);


drop policy if exists "dpm_documents_update_admin" on storage.objects;

create policy "dpm_documents_update_admin"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'dpm-documents'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
)
with check (
  bucket_id = 'dpm-documents'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
);


drop policy if exists "dpm_documents_delete_admin" on storage.objects;

create policy "dpm_documents_delete_admin"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'dpm-documents'
  and public.current_user_role() in (
    'super_admin',
    'secretary'
  )
);


-- ============================================================
-- 2C. DPM-ASPIRATION-EVIDENCE
-- ============================================================
--
-- Bucket:
--   dpm-aspiration-evidence
--
-- PRIVATE.
--
-- Sangat penting:
--   Bukti aspirasi dapat berisi informasi sensitif.
--
-- READ:
--   Commission 2
--   Super Admin
--
-- INSERT:
--   Public submission TIDAK dilakukan langsung ke Storage.
--
--   Upload bukti aspirasi sebaiknya dilakukan melalui backend/
--   server-side flow setelah validasi CAPTCHA + OTP.
--
--   Karena itu tidak diberikan INSERT policy kepada anon.
--
-- UPDATE / DELETE:
--   Super Admin dan Commission 2.
-- ============================================================


drop policy if exists "dpm_aspiration_evidence_select" on storage.objects;

create policy "dpm_aspiration_evidence_select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'dpm-aspiration-evidence'
  and public.current_user_role() in (
    'super_admin',
    'commission_2'
  )
);


drop policy if exists "dpm_aspiration_evidence_insert" on storage.objects;

create policy "dpm_aspiration_evidence_insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'dpm-aspiration-evidence'
  and public.current_user_role() in (
    'super_admin',
    'commission_2'
  )
);


drop policy if exists "dpm_aspiration_evidence_update" on storage.objects;

create policy "dpm_aspiration_evidence_update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'dpm-aspiration-evidence'
  and public.current_user_role() in (
    'super_admin',
    'commission_2'
  )
)
with check (
  bucket_id = 'dpm-aspiration-evidence'
  and public.current_user_role() in (
    'super_admin',
    'commission_2'
  )
);


drop policy if exists "dpm_aspiration_evidence_delete" on storage.objects;

create policy "dpm_aspiration_evidence_delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'dpm-aspiration-evidence'
  and public.current_user_role() in (
    'super_admin',
    'commission_2'
  )
);


-- ============================================================
-- 3. FILE SIZE / MIME TYPE POLICY NOTE
-- ============================================================
--
-- Pembatasan ukuran dan MIME type akan ditegakkan pada:
--
--   A. Supabase Storage bucket configuration
--   B. Backend validation
--
-- Untuk bukti aspirasi, format yang diizinkan berdasarkan PRD:
--
--   JPG
--   PNG
--   MP4
--   MP3
--   PDF
--
-- Jangan mengandalkan MIME type dari browser saja.
-- Backend wajib melakukan validasi tambahan.
-- ============================================================


-- ============================================================
-- 4. RECOMMENDED OBJECT PATH STRUCTURE
-- ============================================================
--
-- dpm-public/
--
--   branding/
--     logo/
--
--   content/
--     {period_id}/
--       {content_id}/
--         featured/
--
--
-- dpm-documents/
--
--   {period_id}/
--     {document_id}/
--       original-file
--
--
-- dpm-aspiration-evidence/
--
--   {period_id}/
--     {aspiration_id}/
--       {evidence_id}/
--         original-file
--
-- Object path akan dibuat oleh aplikasi/backend.
-- Jangan menerima file_path mentah dari client tanpa validasi.
-- ============================================================


-- ============================================================
-- 5. VERIFICATION
-- ============================================================
--
-- Query berikut dapat digunakan setelah migration untuk
-- memeriksa bucket.
--
-- SELECT
--   id,
--   name,
--   public
-- FROM storage.buckets
-- WHERE id IN (
--   'dpm-public',
--   'dpm-documents',
--   'dpm-aspiration-evidence'
-- )
-- ORDER BY id;
--
--
-- Untuk memeriksa policy:
--
-- SELECT
--   policyname,
--   cmd
-- FROM pg_policies
-- WHERE schemaname = 'storage'
--   AND tablename = 'objects'
-- ORDER BY policyname;
-- ============================================================


-- ============================================================
-- END OF 03_storage.sql
-- ============================================================