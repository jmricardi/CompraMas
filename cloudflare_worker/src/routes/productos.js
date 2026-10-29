import { querySupabase, batchQueryInChunks } from '../services/supabase.js';

export async function handleProductosRoute(url, request, env) {
  const path = url.pathname;
  const segments = path.split('/').filter(Boolean);

  // GET /api/productos/:id
  if (segments.length === 3 && segments[1] === 'productos') {
    const id = segments[2];
    const data = await querySupabase(
      'productos',
      {
        id_producto: `eq.${id}`,
        select: 'id_producto,productos_ean,productos_descripcion,productos_marca',
        limit: '1',
      },
      env
    );

    if (!data || data.length === 0) {
      return new Response(JSON.stringify({ error: 'Producto no encontrado' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(data[0]), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600',
      },
    });
  }

  // GET /api/productos/batch?ids=1,2,3
  if (path === '/api/productos/batch' && request.method === 'GET') {
    const rawIds = url.searchParams.get('ids') || '';
    const ids = rawIds.split(',').map((s) => s.trim()).filter(Boolean);

    const data = await batchQueryInChunks(
      'productos',
      'id_producto',
      ids,
      {
        select: 'id_producto,productos_ean,productos_descripcion,productos_marca',
      },
      env,
      50
    );

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=1800',
      },
    });
  }

  // GET /api/productos?q=yerba&limit=20
  if (path === '/api/productos' && request.method === 'GET') {
    const query = url.searchParams.get('q')?.trim() || '';
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '20', 10), 50);

    const params = {
      select: 'id_producto,productos_ean,productos_descripcion,productos_marca',
      limit: String(limit),
      order: 'productos_descripcion.asc',
    };

    if (query) {
      params['productos_descripcion'] = `ilike.%${query}%`;
    }

    const data = await querySupabase('productos', params, env);

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300',
      },
    });
  }

  return null;
}
