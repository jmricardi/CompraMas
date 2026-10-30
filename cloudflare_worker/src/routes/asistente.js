import { querySupabase, upsertSupabase, fetchWithRetryAndTimeout } from '../services/supabase.js';

const VTEX_DOMAINS = {
  carrefour: 'https://www.carrefour.com.ar',
  dia: 'https://diaonline.supermercadosdia.com.ar',
  jumbo: 'https://www.jumbo.com.ar',
  disco: 'https://www.disco.com.ar',
  vea: 'https://www.vea.com.ar',
  masonline: 'https://www.masonline.com.ar',
  changomas: 'https://www.masonline.com.ar',
};

function normalizeChainKey(rawChain = '') {
  const clean = rawChain
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();

  if (clean.includes('carrefour')) return 'carrefour';
  if (clean.includes('dia')) return 'dia';
  if (clean.includes('jumbo')) return 'jumbo';
  if (clean.includes('disco')) return 'disco';
  if (clean.includes('vea')) return 'vea';
  if (clean.includes('chango') || clean.includes('masonline') || clean.includes('mas online')) {
    return 'masonline';
  }
  return clean;
}

function extractPresentationFromTitle(title = '') {
  const match = title.match(/\b(\d+(?:[.,]\d+)?\s*(?:kg|g|gr|grs|l|lt|lts|ml|cc|un|u|unid))\b/i);
  return match ? match[1].trim() : '';
}

async function resolveVtexRegion(baseUrl, lat, lon, cp) {
  try {
    const cleanCp = (cp || '').replace(/\D/g, '').trim();
    const hasCp = cleanCp.length === 4;
    const hasCoords = lat !== null && lon !== null && !Number.isNaN(lat) && !Number.isNaN(lon);

    if (!hasCp && !hasCoords) return null;

    const queryParam = hasCp
      ? `postalCode=${cleanCp}`
      : `geoCoordinates=${lon};${lat}`;

    const regionUrl = `${baseUrl}/api/checkout/pub/regions?country=ARG&${queryParam}`;
    const res = await fetchWithRetryAndTimeout(
      regionUrl,
      {
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; CompraMasWorker/1.0)',
        },
      },
      1,
      3000
    );

    if (res.ok) {
      const list = await res.json();
      if (Array.isArray(list) && list.length > 0) {
        return list[0];
      }
    }
  } catch (_) {
    // Ignorar fallo de regionalización y continuar con consulta general VTEX
  }
  return null;
}

async function fetchProductFromVtex(chainKey, ean, { lat = null, lon = null, cp = null } = {}) {
  const baseUrl = VTEX_DOMAINS[chainKey];
  if (!baseUrl) return null;

  let regionId = null;
  let preferredSellerId = null;

  const regionData = await resolveVtexRegion(baseUrl, lat, lon, cp);
  if (regionData) {
    regionId = regionData.id || null;
    if (Array.isArray(regionData.sellers) && regionData.sellers.length > 0) {
      preferredSellerId = regionData.sellers[0]?.id || null;
    }
  }

  const headers = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; CompraMasWorker/1.0)',
  };

  if (regionId) {
    const segmentJson = JSON.stringify({ regionId, countryCode: 'ARG' });
    const encodedSegment = btoa(segmentJson);
    headers['Cookie'] = `vtex_segment=${encodedSegment}`;
  }

  const searchUrl = `${baseUrl}/api/catalog_system/pub/products/search?fq=alternateIds_Ean:${encodeURIComponent(ean)}`;
  const response = await fetchWithRetryAndTimeout(searchUrl, { headers }, 1, 4500);

  if (!response.ok && response.status !== 206) {
    return null;
  }

  const data = await response.json();
  if (!Array.isArray(data) || data.length === 0) {
    return null;
  }

  const prod = data[0];
  const items = Array.isArray(prod.items) ? prod.items : [];
  if (items.length === 0) return null;

  const item = items[0];
  const sellers = Array.isArray(item.sellers) ? item.sellers : [];
  let selectedSeller = null;

  if (preferredSellerId) {
    selectedSeller = sellers.find((s) => String(s.sellerId) === String(preferredSellerId));
  }
  if (!selectedSeller && sellers.length > 0) {
    selectedSeller = sellers[0];
  }

  const offer = selectedSeller?.commertialOffer || {};
  const price = typeof offer.Price === 'number' ? offer.Price : 0;
  const availableQty = typeof offer.AvailableQuantity === 'number' ? offer.AvailableQuantity : 1;

  const images = Array.isArray(item.images) ? item.images : [];
  const imageUrl = images.length > 0 ? images[0]?.imageUrl || null : null;

  const rawTitle = (prod.productName || item.nameComplete || item.name || '').toString().trim();
  const brand = (prod.brand || '').toString().trim();
  const content = extractPresentationFromTitle(rawTitle) || (item.measurementUnit ? `1 ${item.measurementUnit}` : '1 un');
  const linkText = prod.linkText ? `${baseUrl}/${prod.linkText}/p` : baseUrl;

  return {
    ean,
    name: rawTitle,
    brand,
    content,
    price: price > 0 ? price : 0,
    inStock: availableQty > 0,
    imageUrl,
    url: linkText,
    chainKey,
    sellerId: selectedSeller?.sellerId || preferredSellerId || null,
  };
}

async function autoIngestVtexProductToSupabase(vtexProd, env) {
  if (!vtexProd || !vtexProd.ean || !vtexProd.name) return;

  const productPayload = {
    id_producto: vtexProd.ean,
    productos_ean: vtexProd.ean,
    productos_descripcion: vtexProd.name,
    productos_marca: vtexProd.brand || null,
    imagen_url: vtexProd.imageUrl || null,
  };

  try {
    await upsertSupabase('productos', productPayload, env, 'id_producto');
  } catch (_) {
    // En caso de restricción de clave primaria o permisos, continuar con precios_online
  }

  if (vtexProd.price > 0) {
    const scraperTag = vtexProd.sellerId
      ? `worker_vtex_${vtexProd.sellerId}`
      : 'worker_vtex_autoingest';

    const pricePayload = {
      id_producto: vtexProd.ean,
      id_entidad: vtexProd.chainKey,
      precio: vtexProd.price,
      stock: vtexProd.inStock !== false,
      url: vtexProd.url,
      fecha_captura: new Date().toISOString(),
      nombre_scraper: scraperTag,
    };

    try {
      await upsertSupabase('precios_online', pricePayload, env);
    } catch (_) {
      // Ignorar errores de duplicados para no bloquear la respuesta al cliente
    }
  }
}

export async function handleAsistenteRoute(url, request, env, ctx) {
  const path = url.pathname;

  // GET /api/asistente/producto?ean=779...&chain=carrefour&lat=...&lon=...
  if (path === '/api/asistente/producto' && request.method === 'GET') {
    const rawEan = (url.searchParams.get('ean') || '').trim();
    const rawChain = (url.searchParams.get('chain') || '').trim();
    const lat = url.searchParams.get('lat') ? parseFloat(url.searchParams.get('lat')) : null;
    const lon = url.searchParams.get('lon') ? parseFloat(url.searchParams.get('lon')) : null;
    const cp = url.searchParams.get('cp') || null;

    if (!rawEan) {
      return new Response(JSON.stringify({ error: 'Parámetro ean requerido' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const chainKey = normalizeChainKey(rawChain);
    const eanVariants = Array.from(
      new Set([
        rawEan,
        rawEan.length < 13 ? rawEan.padStart(13, '0') : rawEan,
        rawEan.replace(/^0+/, ''),
      ].filter(Boolean))
    );

    const orFilter = `(${eanVariants.map((v) => `id_producto.eq.${v},productos_ean.eq.${v}`).join(',')})`;

    // PASO A: Buscar producto en Supabase
    let supabaseProduct = null;
    try {
      const rows = await querySupabase(
        'productos',
        {
          or: orFilter,
          select: 'id_producto,productos_ean,productos_descripcion,productos_marca,imagen_url',
          limit: '1',
        },
        env
      );
      if (Array.isArray(rows) && rows.length > 0) {
        supabaseProduct = rows[0];
      }
    } catch (_) {}

    if (supabaseProduct) {
      const prodId = String(supabaseProduct.id_producto || rawEan);
      let resolvedPrice = 0;

      // Buscar precio en precios físicos y precios_online de Supabase
      try {
        const [physicalRows, onlineRows] = await Promise.all([
          querySupabase(
            'precios',
            {
              id_producto: `eq.${prodId}`,
              select: 'productos_precio_lista,productos_precio_unitario_promo1,id_entidad,comercio(comercio_bandera_nombre,comercio_razon_social)',
              order: 'productos_precio_lista.asc',
              limit: '20',
            },
            env
          ).catch(() => []),
          querySupabase(
            'precios_online',
            {
              id_producto: `eq.${prodId}`,
              select: 'precio,id_entidad,stock',
              order: 'precio.asc',
              limit: '10',
            },
            env
          ).catch(() => []),
        ]);

        // Priorizar el precio de la cadena seleccionada si existe
        if (chainKey && Array.isArray(onlineRows)) {
          const matchOnline = onlineRows.find((r) =>
            normalizeChainKey(String(r.id_entidad || '')) === chainKey && Number(r.precio) > 0
          );
          if (matchOnline) {
            resolvedPrice = Number(matchOnline.precio);
          }
        }

        if (resolvedPrice <= 0 && chainKey && Array.isArray(physicalRows)) {
          const matchPhysical = physicalRows.find((r) => {
            const comercioObj = r.comercio || {};
            const label = `${comercioObj.comercio_bandera_nombre || ''} ${comercioObj.comercio_razon_social || ''}`;
            return normalizeChainKey(label) === chainKey;
          });
          if (matchPhysical) {
            resolvedPrice = Number(
              matchPhysical.productos_precio_unitario_promo1 ||
              matchPhysical.productos_precio_lista ||
              0
            );
          }
        }

        // Fallback al menor precio general registrado en Supabase
        if (resolvedPrice <= 0) {
          if (Array.isArray(physicalRows) && physicalRows.length > 0) {
            resolvedPrice = Number(
              physicalRows[0].productos_precio_unitario_promo1 ||
              physicalRows[0].productos_precio_lista ||
              0
            );
          } else if (Array.isArray(onlineRows) && onlineRows.length > 0) {
            resolvedPrice = Number(onlineRows[0].precio || 0);
          }
        }
      } catch (_) {}

      // Si no tenía precio para la cadena VTEX actual, intentar enriquecer el precio desde VTEX
      if (resolvedPrice <= 0 && VTEX_DOMAINS[chainKey]) {
        const vtexPriceData = await fetchProductFromVtex(chainKey, rawEan, { lat, lon, cp });
        if (vtexPriceData && vtexPriceData.price > 0) {
          resolvedPrice = vtexPriceData.price;
          if (ctx && typeof ctx.waitUntil === 'function') {
            ctx.waitUntil(autoIngestVtexProductToSupabase(vtexPriceData, env));
          } else {
            await autoIngestVtexProductToSupabase(vtexPriceData, env);
          }
        }
      }

      const rawDesc = String(supabaseProduct.productos_descripcion || '');
      const content = extractPresentationFromTitle(rawDesc) || '1 un';

      return new Response(
        JSON.stringify({
          found: true,
          source: 'supabase',
          product: {
            ean: String(supabaseProduct.productos_ean || prodId),
            name: rawDesc,
            brand: String(supabaseProduct.productos_marca || ''),
            content,
            price: resolvedPrice,
            imageUrl: supabaseProduct.imagen_url || null,
            chain: chainKey,
          },
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-store',
          },
        }
      );
    }

    // PASO B: Producto NO está en Supabase -> Consultar VTEX de la cadena seleccionada (o cadenas principales)
    const candidateChains = VTEX_DOMAINS[chainKey]
      ? [chainKey]
      : ['carrefour', 'dia', 'masonline', 'jumbo', 'disco', 'vea'];

    let vtexProduct = null;
    for (const cKey of candidateChains) {
      vtexProduct = await fetchProductFromVtex(cKey, rawEan, { lat, lon, cp });
      if (vtexProduct && vtexProduct.name) {
        break;
      }
    }

    if (vtexProduct && vtexProduct.name) {
      // Auto-Ingesta inmediata en Supabase para que a futuro se continúe extrayendo el precio
      await autoIngestVtexProductToSupabase(vtexProduct, env);

      return new Response(
        JSON.stringify({
          found: true,
          source: 'vtex_ingested',
          product: {
            ean: vtexProduct.ean,
            name: vtexProduct.name,
            brand: vtexProduct.brand,
            content: vtexProduct.content,
            price: vtexProduct.price,
            imageUrl: vtexProduct.imageUrl,
            chain: vtexProduct.chainKey,
          },
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': 'no-store',
          },
        }
      );
    }

    // No encontrado ni en Supabase ni en VTEX -> Retornar estructura para carga manual
    return new Response(
      JSON.stringify({
        found: false,
        source: 'none',
        product: {
          ean: rawEan,
          name: '',
          brand: '',
          content: '1 un',
          price: 0,
          imageUrl: null,
          chain: chainKey,
        },
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-store',
        },
      }
    );
  }

  return null;
}
