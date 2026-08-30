
import Link from "next/link";

import { ContentGrid } from "@/components/content-grid";
import { PublicLayout } from "@/components/public-layout";
import { getPublishedContent } from "@/lib/public-data";

export default async function HomePage() {
  const content = await getPublishedContent();

  return (
    <PublicLayout>
      {/* ================= HERO ================= */}

      <section className="hero">
        <div className="heroOverlay" />

        <div className="heroContent">
          <span className="heroEyebrow">
            DEWAN PERWAKILAN MAHASISWA
          </span>

          <h1>
            DPM FIPP
            <span>UNIMA</span>
          </h1>

          <p>
            Wadah representasi, aspirasi, legislasi, dan
            pengawasan mahasiswa Fakultas Ilmu Pendidikan
            dan Psikologi Universitas Negeri Manado.
          </p>

          <div className="heroActions">
            <Link
              href="/tentang"
              className="heroPrimaryButton"
            >
              Jelajahi DPM
            </Link>

            <Link
              href="/aspirasi"
              className="heroSecondaryButton"
            >
              Kirim Aspirasi
            </Link>
          </div>
        </div>
      </section>

      {/* ================= QUICK ACCESS ================= */}

      <section className="homeSection quickAccessSection">
        <div className="sectionContainer">
          <div className="sectionHeading">
            <span>LAYANAN DPM FIPP</span>

            <h2>
              Akses Informasi dan Layanan
            </h2>

            <p>
              Berbagai layanan yang dapat digunakan oleh
              mahasiswa Fakultas Ilmu Pendidikan dan Psikologi
              UNIMA.
            </p>
          </div>

          <div className="quickAccessGrid">

            <Link
              href="/aspirasi"
              className="quickAccessCard"
            >
              <span className="quickAccessNumber">
                01
              </span>

              <h3>
                Aspirasi Mahasiswa
              </h3>

              <p>
                Sampaikan aspirasi, masukan, maupun
                permasalahan kepada DPM FIPP.
              </p>

              <span className="quickAccessArrow">
                →
              </span>
            </Link>


            <Link
              href="/berita"
              className="quickAccessCard"
            >
              <span className="quickAccessNumber">
                02
              </span>

              <h3>
                Publikasi
              </h3>

              <p>
                Ikuti informasi dan kegiatan terbaru
                dari DPM FIPP UNIMA.
              </p>

              <span className="quickAccessArrow">
                →
              </span>
            </Link>


            <Link
              href="/tentang"
              className="quickAccessCard"
            >
              <span className="quickAccessNumber">
                03
              </span>

              <h3>
                Tentang DPM
              </h3>

              <p>
                Pelajari struktur, fungsi, dan
                peran DPM FIPP UNIMA.
              </p>

              <span className="quickAccessArrow">
                →
              </span>
            </Link>

          </div>
        </div>
      </section>


      {/* ================= PUBLICATIONS ================= */}

      <section className="homeSection publicationSection">
        <div className="sectionContainer">

          <div className="sectionHeaderRow">
            <div className="sectionHeading">
              <span>PUBLIKASI TERBARU</span>

              <h2>
                Informasi Terkini
              </h2>

              <p>
                Informasi dan publikasi terbaru
                dari Dewan Perwakilan Mahasiswa FIPP UNIMA.
              </p>
            </div>

            <Link
              href="/berita"
              className="viewAllButton"
            >
              Lihat Semua →
            </Link>
          </div>


          {/* ContentGrid menggunakan props "items" */}

          <ContentGrid items={content} />

        </div>
      </section>


      {/* ================= CTA ================= */}

      <section className="homeCTA">

        <div className="homeCTAOverlay" />

        <div className="homeCTAContent">

          <span>
            PARTISIPASI MAHASISWA
          </span>

          <h2>
            Suaramu Memiliki Peran.
          </h2>

          <p>
            DPM FIPP UNIMA hadir sebagai wadah representasi
            mahasiswa dalam menyampaikan aspirasi, mengawal
            kebijakan, dan membangun lingkungan kampus yang
            lebih baik.
          </p>

          <Link
            href="/aspirasi"
            className="heroPrimaryButton"
          >
            Sampaikan Aspirasi
          </Link>

        </div>

      </section>

    </PublicLayout>
  );
}