import { corsHeaders, handleOptions } from './config/cors.js';
import { handleProductosRoute } from './routes/productos.js';
import { handleAsistenteRoute } from './routes/asistente.js';

async function generateETag(data) {
  const msgUint8 = new TextEncoder().encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-1', msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
  return `"${hashHex}"`;
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return handleOptions();
    }

    const url = new URL(request.url);

    // Health check
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(JSON.stringify({
        status: 'online',
        gateway: 'CompraMas Edge API Gateway',
        domain: 'api-compramas.arandulabs.dev',
        timestamp: new Date().toISOString()
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache'
        }
      });
    }

    const cache = caches.default;
    const cacheKey = new Request(url.toString(), {
      method: 'GET',
      headers: request.headers,
    });

    if (request.method === 'GET') {
      const cachedResponse = await cache.match(cacheKey);
      if (cachedResponse) {
        const clientIfNoneMatch = request.headers.get('If-None-Match');
        const cachedETag = cachedResponse.headers.get('ETag');

        if (clientIfNoneMatch && cachedETag && clientIfNoneMatch === cachedETag) {
          return new Response(null, {
            status: 304,
            headers: {
              ...corsHeaders,
              'ETag': cachedETag,
              'Cache-Control': cachedResponse.headers.get('Cache-Control') || 'public, max-age=60',
            },
          });
        }
        return cachedResponse;
      }
    }

    try {
      let response = null;

      if (url.pathname.startsWith('/api/productos')) {
        response = await handleProductosRoute(url, request, env);
      } else if (url.pathname.startsWith('/api/asistente')) {
        response = await handleAsistenteRoute(url, request, env, ctx);
      }

      if (!response) {
        return new Response(
          JSON.stringify({ error: 'Endpoint no encontrado o no permitido' }),
          {
            status: 404,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          }
        );
      }

      if (request.method === 'GET' && response.status === 200) {
        const bodyText = await response.text();
        const etag = await generateETag(bodyText);

        const clientETag = request.headers.get('If-None-Match');
        if (clientETag && clientETag === etag) {
          return new Response(null, {
            status: 304,
            headers: {
              ...corsHeaders,
              'ETag': etag,
              'Cache-Control': response.headers.get('Cache-Control') || 'public, max-age=60',
            },
          });
        }

        const newHeaders = new Headers(response.headers);
        Object.entries(corsHeaders).forEach(([k, v]) => newHeaders.set(k, v));
        newHeaders.set('ETag', etag);

        const finalResponse = new Response(bodyText, {
          status: response.status,
          headers: newHeaders,
        });

        ctx.waitUntil(cache.put(cacheKey, finalResponse.clone()));
        return finalResponse;
      }

      const modifiedHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([k, v]) => modifiedHeaders.set(k, v));

      return new Response(response.body, {
        status: response.status,
        headers: modifiedHeaders,
      });
    } catch (err) {
      return new Response(
        JSON.stringify({
          error: 'Error interno en Gateway',
          message: err.message,
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }
  },
};
