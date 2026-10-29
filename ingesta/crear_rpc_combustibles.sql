CREATE OR REPLACE FUNCTION get_combustibles_cercanos(
    p_lat double precision,
    p_lon double precision,
    p_radio_km double precision DEFAULT 15.0,
    p_filtro_producto text DEFAULT NULL
)
RETURNS TABLE (
    idempresa integer,
    empresa text,
    empresabandera text,
    direccion text,
    localidad text,
    latitud numeric,
    longitud numeric,
    distancia_km double precision,
    precios json
)
LANGUAGE sql
STABLE
AS $$
WITH bounds AS (
    SELECT 
        p_lat - (p_radio_km / 111.0) AS min_lat,
        p_lat + (p_radio_km / 111.0) AS max_lat,
        p_lon - (p_radio_km / 85.0)  AS min_lon,
        p_lon + (p_radio_km / 85.0)  AS max_lon
),
estaciones_filtradas AS (
    SELECT DISTINCT ON (c.idempresa, c.direccion, c.producto)
        c.idempresa,
        c.empresa,
        c.empresabandera,
        c.direccion,
        c.localidad,
        c.latitud,
        c.longitud,
        c.producto,
        c.precio,
        c.fecha_vigencia
    FROM combustibles c, bounds b
    WHERE c.latitud BETWEEN b.min_lat AND b.max_lat
      AND c.longitud BETWEEN b.min_lon AND b.max_lon
    ORDER BY c.idempresa, c.direccion, c.producto, c.fecha_vigencia DESC
),
agrupadas AS (
    SELECT 
        ef.idempresa,
        ef.empresa,
        ef.empresabandera,
        ef.direccion,
        ef.localidad,
        ef.latitud,
        ef.longitud,
        (6371 * acos(
            least(1.0, greatest(-1.0,
                cos(radians(p_lat)) * cos(radians(ef.latitud::double precision)) *
                cos(radians(ef.longitud::double precision) - radians(p_lon)) +
                sin(radians(p_lat)) * sin(radians(ef.latitud::double precision))
            ))
        )) AS distancia_km,
        COALESCE(
            json_agg(
                json_build_object(
                    'producto', ef.producto,
                    'precio', ef.precio,
                    'fecha_vigencia', ef.fecha_vigencia
                ) ORDER BY ef.precio ASC
            ) FILTER (WHERE ef.producto IS NOT NULL AND ef.precio IS NOT NULL),
            '[]'::json
        ) AS precios
    FROM estaciones_filtradas ef
    GROUP BY ef.idempresa, ef.empresa, ef.empresabandera, ef.direccion, ef.localidad, ef.latitud, ef.longitud
)
SELECT 
    a.idempresa,
    a.empresa,
    a.empresabandera,
    a.direccion,
    a.localidad,
    a.latitud,
    a.longitud,
    ROUND(a.distancia_km::numeric, 2)::double precision AS distancia_km,
    a.precios
FROM agrupadas a
WHERE a.distancia_km <= p_radio_km
  AND (
      p_filtro_producto IS NULL 
      OR p_filtro_producto = '' 
      OR p_filtro_producto = 'Todos'
      OR json_array_length(a.precios) = 0
      OR EXISTS (
          SELECT 1 FROM json_array_elements(a.precios) elem 
          WHERE elem->>'producto' ILIKE '%' || p_filtro_producto || '%'
      )
  )
ORDER BY a.distancia_km ASC
LIMIT 400;
$$;

GRANT EXECUTE ON FUNCTION get_combustibles_cercanos TO public, anon, authenticated;
