import { useEffect, useState } from 'react';

type Health = { status: string };
type DbVersion = { version: string };
type Greeting = { message: string };

export default function App() {
  const [health, setHealth] = useState<Health | null>(null);
  const [dbVersion, setDbVersion] = useState<DbVersion | null>(null);
  const [greeting, setGreeting] = useState<Greeting | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [h, d, g] = await Promise.all([
          fetch('/health').then((r) => _parseJson<Health>(r)),
          fetch('/db-version').then((r) => _parseJson<DbVersion>(r)),
          fetch('/greeting').then((r) => _parseJson<Greeting>(r)),
        ]);
        if (!cancelled) {
          setHealth(h);
          setDbVersion(d);
          setGreeting(g);
        }
      } catch (e) {
        if (!cancelled) setError(String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="app">
      <h1>API + PostgreSQL</h1>
      <p className="lede">
        主界面由 React 提供；与 <code>/ui</code> 同源请求 <code>/health</code>、
        <code>/db-version</code>、<code>/greeting</code>。
      </p>
      {error && <p className="error">{error}</p>}
      <SectionCard title="/health" body={health ? JSON.stringify(health, null, 2) : '加载中…'} />
      <SectionCard title="/db-version" body={dbVersion ? JSON.stringify(dbVersion, null, 2) : '加载中…'} />
      <SectionCard title="/greeting" body={greeting ? JSON.stringify(greeting, null, 2) : '加载中…'} />
    </div>
  );
}

async function _parseJson<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`HTTP ${res.status}: ${t || res.statusText}`);
  }
  return res.json() as Promise<T>;
}

function SectionCard({ title, body }: { title: string; body: string }) {
  return (
    <section className="section">
      <h2 className="section-title">{title}</h2>
      <pre className="section-body">{body}</pre>
    </section>
  );
}
