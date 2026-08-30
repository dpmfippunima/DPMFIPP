import { PublicLayout } from "@/components/public-layout";
import AspirationForm from "./aspiration-form";

export default function AspirationPage() {
  return (
    <PublicLayout>
      <section className="shell section">
        <p className="eyebrow">D-DAS</p>

        <h1>Sampaikan aspirasi.</h1>

        <p>
          Sampaikan aspirasi, keluhan, atau masukan terkait lingkungan
          Fakultas Ilmu Pendidikan dan Psikologi UNIMA.
        </p>

        <div className="notice">
          Untuk menjaga keamanan dan kualitas tindak lanjut, aspirasi akan
          melalui proses peninjauan sebelum diteruskan kepada pihak terkait.
        </div>

        <AspirationForm />
      </section>
    </PublicLayout>
  );
}