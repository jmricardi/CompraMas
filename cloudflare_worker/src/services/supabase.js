export async function fetchWithRetryAndTimeout(url, options = {}, retries = 2, timeoutMs = 3500) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok && response.status >= 500 && attempt < retries) {
        const backoffMs = Math.pow(2, attempt) * 200;
        await new Promise((resolve) => setTimeout(resolve, backoffMs));
        continue;
      }

      return response;
    } catch (err) {
      clearTimeout(timeoutId);

      if (attempt >= retries) {
        throw new Error(
          err.name === 'AbortError'
            ? `Timeout excedido (${timeoutMs}ms) al contactar Supabase`
            : `Error de conexión con Supabase: ${err.message}`
        );
      }

      const backoffMs = Math.pow(2, attempt) * 200;
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
    }
  }
}

export async function querySupabase(table, queryParams = {}, env, options = {}) {
  // Limpiar caracteres invisibles (BOM \uFEFF o espacios) si viniesen del secret
  const rawUrl = env.SUPABASE_URL || 'https://ajrmzynmfmudcrsrcbjo.supabase.co';
  const supabaseUrl = rawUrl.replace(/^\uFEFF/, '').trim();
  const rawKey = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_ANON_KEY || '';
  const supabaseKey = rawKey.replace(/^\uFEFF/, '').trim();

  if (!supabaseKey) {
    throw new Error('Configuración incompleta: Falta SUPABASE_SERVICE_ROLE_KEY o SUPABASE_ANON_KEY.');
  }

  const searchParams = new URLSearchParams();
  for (const [key, value] of Object.entries(queryParams)) {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.append(key, value);
    }
  }

  const endpoint = `${supabaseUrl.replace(/\/+$/, '')}/rest/v1/${table}?${searchParams.toString()}`;

  const headers = {
    'apikey': supabaseKey,
    'Authorization': `Bearer ${supabaseKey}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  if (options.count) {
    headers['Prefer'] = `count=${options.count}`;
  }
  if (options.prefer) {
    headers['Prefer'] = options.prefer;
  }

  const response = await fetchWithRetryAndTimeout(endpoint, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Supabase Error (${response.status}): ${errorText}`);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

export async function upsertSupabase(table, payload, env, onConflict = null) {
  const queryParams = onConflict ? { on_conflict: onConflict } : {};
  return querySupabase(table, queryParams, env, {
    method: 'POST',
    body: payload,
    prefer: 'resolution=merge-duplicates,return=representation',
  });
}

export async function batchQueryInChunks(table, idColumn, ids, baseQueryParams, env, chunkSize = 50) {
  const uniqueIds = [...new Set(ids.filter(Boolean))];
  if (uniqueIds.length === 0) return [];

  const chunks = [];
  for (let i = 0; i < uniqueIds.length; i += chunkSize) {
    chunks.push(uniqueIds.slice(i, i + chunkSize));
  }

  const chunkPromises = chunks.map((chunk) => {
    const params = {
      ...baseQueryParams,
      [idColumn]: `in.(${chunk.join(',')})`,
    };
    return querySupabase(table, params, env);
  });

  const results = await Promise.all(chunkPromises);
  return results.flat();
}
