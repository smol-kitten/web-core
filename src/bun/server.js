// Default Bun server.
// Replace this file by mounting your app to /app or setting BUN_ENTRY.
const port = parseInt(process.env.PORT || '3000', 10);

Bun.serve({
  port,
  fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === '/health') {
      return new Response('ok', { status: 200 });
    }
    return new Response(
      JSON.stringify({
        status: 'ok',
        runtime: 'bun',
        version: Bun.version,
        message: 'Mount your app to /app and set BUN_ENTRY to your entry point.',
        docs: 'https://github.com/smol-kitten/web-core',
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  },
});

console.log(`Bun default server listening on http://0.0.0.0:${port}`);
