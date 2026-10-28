// Bordbar POC: serves the page and proxies the ICE onboard portal API,
// which sends no CORS headers and so cannot be fetched from the browser directly.
// Usage: bun server.ts [--demo] [--port 8788]

const args = Bun.argv.slice(2);
const demo = args.includes("--demo");
const port = Number(args[args.indexOf("--port") + 1]) || 8788;

const PORTAL = "https://iceportal.de/api1/rs";
const routes: Record<string, { live: string; fixture: string }> = {
  "/api/status": { live: `${PORTAL}/status`, fixture: "fixtures/status.json" },
  "/api/trip": { live: `${PORTAL}/tripInfo/trip`, fixture: "fixtures/trip.json" },
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

Bun.serve({
  port,
  async fetch(req) {
    const { pathname } = new URL(req.url);
    const route = routes[pathname];

    if (route) {
      if (demo) return new Response(Bun.file(new URL(route.fixture, import.meta.url)));
      try {
        // Off the train iceportal.de does not resolve or hangs, so keep the timeout short.
        const res = await fetch(route.live, { signal: AbortSignal.timeout(4000) });
        if (!res.ok) return json({ error: `portal returned ${res.status}` }, 502);
        return json(await res.json());
      } catch (e) {
        return json({ error: "not on ICE WiFi", detail: String(e) }, 503);
      }
    }

    const file = Bun.file(new URL(`public${pathname === "/" ? "/index.html" : pathname}`, import.meta.url));
    return (await file.exists()) ? new Response(file) : new Response("not found", { status: 404 });
  },
});

console.log(`Bordbar on http://localhost:${port}${demo ? " (demo data)" : ""}`);
