import Link from "next/link";
import { signIn } from "./actions";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) { const params = await searchParams; return <main className="shell section"><Link className="brand" href="/">DPM FIPP<small>UNIMA</small></Link><h1>Masuk ke Admin Panel</h1>{params.error && <p className="error">Email atau kata sandi tidak valid.</p>}<form className="form" action={signIn}><label>Email<input name="email" type="email" required autoComplete="email" /></label><label>Kata sandi<input name="password" type="password" required autoComplete="current-password" /></label><button className="button" type="submit">Masuk</button></form></main>; }
