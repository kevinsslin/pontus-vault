"use client";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body>
        <main className="page">
          <section className="reveal">
            <p className="eyebrow">Error</p>
            <h1>Something went wrong.</h1>
            <p className="muted">
              {error.message}
              {error.digest ? ` (Digest: ${error.digest})` : ""}
            </p>
            <button className="button" type="button" onClick={() => reset()}>
              Try again
            </button>
          </section>
        </main>
      </body>
    </html>
  );
}

