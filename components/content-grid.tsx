import type { PublicContent } from "@/lib/types";

export function ContentGrid({ items }: { items: PublicContent[] }) {
  if (!items.length) return <div className="empty">Belum ada publikasi yang tersedia.</div>;
  return <div className="grid">{items.map((item) => <article className="card" key={item.id}>{item.featured_image_path && <img alt="" src={item.featured_image_path} />}<span className="tag">{item.type.replaceAll("_", " ")}</span><h3>{item.title}</h3><p>{item.excerpt || "Baca informasi selengkapnya dari DPM FIPP UNIMA."}</p></article>)}</div>;
}
