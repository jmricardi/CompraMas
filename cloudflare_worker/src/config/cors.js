export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, If-None-Match, Cache-Control',
  'Access-Control-Expose-Headers': 'ETag, Cache-Control, Content-Type',
  'Access-Control-Max-Age': '86400',
};

export function handleOptions() {
  return new Response(null, {
    status: 204,
    headers: corsHeaders,
  });
}
