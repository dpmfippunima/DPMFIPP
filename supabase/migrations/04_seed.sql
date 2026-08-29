-- ============================================================
-- DPM FIPP CMS
-- SUPABASE SEED V1 FINAL
-- Migration: 04_seed.sql
-- Database: PostgreSQL / Supabase
--
-- PURPOSE:
--   Mengisi data awal/master data sistem.
--
-- DEPENDENCIES:
--   01_schema.sql
--   02_rls_policies.sql
--   03_storage.sql
--
-- INCLUDED:
--   1. Periode kepengurusan 2026/2027
--   2. Data awal 12 ORMAWA FIPP
--
-- NOT INCLUDED:
--   - auth.users
--   - Password
--   - Akun pengguna
--   - Approval logs
--   - Aspirasi
--   - Konten
--   - Dokumen
--   - Audit logs
--
-- IMPORTANT:
--   - Tidak menggunakan ON CONFLICT.
--   - Aman dijalankan ulang.
--   - Tidak bergantung pada unique constraint tambahan.
-- ============================================================


-- ============================================================
-- 1. INITIAL PERIOD
-- ============================================================

insert into public.periods (
  name,
  year_start,
  year_end,
  is_active
)
select
  '2026/2027',
  2026,
  2027,
  false
where not exists (
  select 1
  from public.periods
  where year_start = 2026
    and year_end = 2027
);


-- ============================================================
-- 2. ENSURE ONLY 2026/2027 IS ACTIVE
-- ============================================================

update public.periods
set
  is_active = false,
  updated_at = now()
where is_active = true
  and not (
    year_start = 2026
    and year_end = 2027
  );


update public.periods
set
  is_active = true,
  updated_at = now()
where year_start = 2026
  and year_end = 2027;


-- ============================================================
-- 3. INITIAL ORMAWA
-- ============================================================
--
-- Total: 12 organisasi
--
-- Tidak ada data pengurus yang ditebak.
-- ============================================================


-- ------------------------------------------------------------
-- 3A. UPDATE EXISTING ORGANIZATIONS BY CODE
-- ------------------------------------------------------------

update public.organizations o
set
  period_id = p.id,
  name = seed.name,
  description = seed.description,
  status = 'active'::public.organization_status,
  deleted_at = null,
  updated_at = now()
from public.periods p
cross join (
  values
    (
      'BEM-FIPP',
      'BEM FIPP',
      'Badan Eksekutif Mahasiswa Fakultas Ilmu Pendidikan dan Psikologi'
    ),
    (
      'KPRM',
      'KPRM',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'HIMAPSI-JPPB',
      'HIMAPSI JPPB',
      'Himpunan mahasiswa bidang psikologi dan/atau program terkait'
    ),
    (
      'HIMAPRO-PGSD',
      'HIMAPRO PGSD',
      'Himpunan mahasiswa Program Studi Pendidikan Guru Sekolah Dasar'
    ),
    (
      'HIMAPRO-BK',
      'HIMAPRO BK',
      'Himpunan mahasiswa Program Studi Bimbingan dan Konseling'
    ),
    (
      'HIMAPRO-PKH',
      'HIMAPRO PKH',
      'Himpunan mahasiswa Program Studi Pendidikan Khusus'
    ),
    (
      'HIMAPRO-PGPAUD',
      'HIMAPRO PG-PAUD',
      'Himpunan mahasiswa Program Studi Pendidikan Guru Pendidikan Anak Usia Dini'
    ),
    (
      'UPK-MK-FIPP',
      'UPK-MK FIPP',
      'Unit kegiatan mahasiswa di lingkungan FIPP'
    ),
    (
      'BTM-FIPP',
      'BTM FIPP',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'KMK-FIPP',
      'KMK FIPP',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'MHDI-FIPP',
      'MHDI FIPP',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'MAPALA-PAEDAGOGIC',
      'MAPALA PAEDAGOGIC',
      'Mahasiswa Pecinta Alam Paedagogic'
    )
) as seed(code, name, description)
where
  p.year_start = 2026
  and p.year_end = 2027
  and o.code = seed.code;


-- ------------------------------------------------------------
-- 3B. INSERT MISSING ORGANIZATIONS
-- ------------------------------------------------------------

insert into public.organizations (
  period_id,
  name,
  code,
  description,
  status
)
select
  p.id,
  seed.name,
  seed.code,
  seed.description,
  'active'::public.organization_status
from public.periods p
cross join (
  values
    (
      'BEM-FIPP',
      'BEM FIPP',
      'Badan Eksekutif Mahasiswa Fakultas Ilmu Pendidikan dan Psikologi'
    ),
    (
      'KPRM',
      'KPRM',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'HIMAPSI-JPPB',
      'HIMAPSI JPPB',
      'Himpunan mahasiswa bidang psikologi dan/atau program terkait'
    ),
    (
      'HIMAPRO-PGSD',
      'HIMAPRO PGSD',
      'Himpunan mahasiswa Program Studi Pendidikan Guru Sekolah Dasar'
    ),
    (
      'HIMAPRO-BK',
      'HIMAPRO BK',
      'Himpunan mahasiswa Program Studi Bimbingan dan Konseling'
    ),
    (
      'HIMAPRO-PKH',
      'HIMAPRO PKH',
      'Himpunan mahasiswa Program Studi Pendidikan Khusus'
    ),
    (
      'HIMAPRO-PGPAUD',
      'HIMAPRO PG-PAUD',
      'Himpunan mahasiswa Program Studi Pendidikan Guru Pendidikan Anak Usia Dini'
    ),
    (
      'UPK-MK-FIPP',
      'UPK-MK FIPP',
      'Unit kegiatan mahasiswa di lingkungan FIPP'
    ),
    (
      'BTM-FIPP',
      'BTM FIPP',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'KMK-FIPP',
      'KMK FIPP',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'MHDI-FIPP',
      'MHDI FIPP',
      'Organisasi mahasiswa FIPP'
    ),
    (
      'MAPALA-PAEDAGOGIC',
      'MAPALA PAEDAGOGIC',
      'Mahasiswa Pecinta Alam Paedagogic'
    )
) as seed(code, name, description)
where
  p.year_start = 2026
  and p.year_end = 2027
  and not exists (
    select 1
    from public.organizations existing
    where existing.code = seed.code
  );


-- ============================================================
-- 4. RESTORE ORGANIZATION PERIOD
-- ============================================================
--
-- Memastikan seluruh ORMAWA seed berada pada periode 2026/2027.
-- ============================================================

update public.organizations o
set
  period_id = p.id,
  status = 'active'::public.organization_status,
  deleted_at = null,
  updated_at = now()
from public.periods p
where
  p.year_start = 2026
  and p.year_end = 2027
  and o.code in (
    'BEM-FIPP',
    'KPRM',
    'HIMAPSI-JPPB',
    'HIMAPRO-PGSD',
    'HIMAPRO-BK',
    'HIMAPRO-PKH',
    'HIMAPRO-PGPAUD',
    'UPK-MK-FIPP',
    'BTM-FIPP',
    'KMK-FIPP',
    'MHDI-FIPP',
    'MAPALA-PAEDAGOGIC'
  );


-- ============================================================
-- 5. DATA INTEGRITY CHECK - PERIOD
-- ============================================================

do $$
declare
  v_period_count integer;
begin

  select count(*)
  into v_period_count
  from public.periods
  where
    year_start = 2026
    and year_end = 2027;

  if v_period_count <> 1 then
    raise exception
      '04_seed.sql gagal: periode 2026/2027 harus tepat satu. Ditemukan %.',
      v_period_count;
  end if;

end $$;


-- ============================================================
-- 6. DATA INTEGRITY CHECK - ACTIVE PERIOD
-- ============================================================

do $$
declare
  v_active_count integer;
begin

  select count(*)
  into v_active_count
  from public.periods
  where is_active = true;

  if v_active_count <> 1 then
    raise exception
      '04_seed.sql gagal: harus ada tepat satu periode aktif. Ditemukan %.',
      v_active_count;
  end if;

end $$;


-- ============================================================
-- 7. DATA INTEGRITY CHECK - 12 ORMAWA
-- ============================================================

do $$
declare
  v_org_count integer;
begin

  select count(*)
  into v_org_count
  from public.organizations o
  inner join public.periods p
    on p.id = o.period_id
  where
    p.year_start = 2026
    and p.year_end = 2027
    and o.status = 'active'
    and o.deleted_at is null
    and o.code in (
      'BEM-FIPP',
      'KPRM',
      'HIMAPSI-JPPB',
      'HIMAPRO-PGSD',
      'HIMAPRO-BK',
      'HIMAPRO-PKH',
      'HIMAPRO-PGPAUD',
      'UPK-MK-FIPP',
      'BTM-FIPP',
      'KMK-FIPP',
      'MHDI-FIPP',
      'MAPALA-PAEDAGOGIC'
    );

  if v_org_count <> 12 then
    raise exception
      '04_seed.sql gagal: harus ada tepat 12 ORMAWA aktif. Ditemukan %.',
      v_org_count;
  end if;

end $$;


-- ============================================================
-- 8. FINAL VERIFICATION
-- ============================================================
--
-- Jika script mencapai bagian ini tanpa exception,
-- maka seed berhasil.
-- ============================================================

do $$
begin
  raise notice '============================================';
  raise notice '04_seed.sql berhasil dijalankan.';
  raise notice 'Periode aktif: 2026/2027';
  raise notice 'ORMAWA aktif: 12';
  raise notice '============================================';
end $$;


-- ============================================================
-- OPTIONAL MANUAL VERIFICATION
-- ============================================================
--
-- Jalankan terpisah jika ingin melihat hasil:
--
-- SELECT
--   id,
--   name,
--   year_start,
--   year_end,
--   is_active
-- FROM public.periods
-- ORDER BY year_start;
--
--
-- SELECT
--   o.id,
--   o.name,
--   o.code,
--   o.status,
--   p.name AS period
-- FROM public.organizations o
-- JOIN public.periods p
--   ON p.id = o.period_id
-- ORDER BY o.name;
--
-- ============================================================


-- ============================================================
-- END OF 04_seed.sql FINAL
-- ============================================================