import { useEffect, useState } from 'react';

type Health = { status: string };
type Greeting = { message: string };

export default function App() {
  const [health, setHealth] = useState<Health | null>(null);
  const [greeting, setGreeting] = useState<Greeting | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [h, g] = await Promise.all([
          fetch('/health').then((r) => r.json()),
          fetch('/greeting').then((r) => r.json()),
        ]);
        if (!cancelled) {
          setHealth(h as Health);
          setGreeting(g as Greeting);
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
    <div className="card">
      <h1>React（Vite + TypeScript）</h1>
      <p>
        由 Rust API 提供 <code>/ui</code> 静态资源；请求 <code>/health</code>、
        <code>/greeting</code> 与页面同源。
      </p>
      {error && <p style={{ color: '#b91c1c' }}>{error}</p>}
      <p>
        <strong>/health</strong>:{' '}
        {health ? JSON.stringify(health) : '加载中…'}
      </p>
      <p>
        <strong>/greeting</strong>:{' '}
        {greeting ? JSON.stringify(greeting) : '加载中…'}
      </p>
    </div>
  );
}
