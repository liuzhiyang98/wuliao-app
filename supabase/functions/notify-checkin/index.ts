// Supabase Edge Function: notify-checkin
// 由 Supabase 数据库 webhook 在 `checkins` 表 INSERT 时触发。
// 读取情侣双方保存在 profiles.fcm_token 的设备令牌，
// 经 Firebase Cloud Messaging (HTTP v1) 下发「自动报备」通知。
// 即使双方 App 都被杀、挂在后台，也能收到推送（系统级通道）。
//
// 说明：用 Deno 内置 WebCrypto 自签 JWT 向 Google OAuth 换取 access token，
// 不依赖任何第三方 npm 包，在 Supabase Edge Functions 的 Deno 运行时下最稳。

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PROJECT_ID = Deno.env.get('FCM_PROJECT_ID')!;
const SA = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!);

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
  auth: { persistSession: false },
});

// ---- 用服务账号私钥自签 JWT，向 Google OAuth 换 access token ----
function b64u(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function signJwt(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const enc = (o: unknown) => b64u(new TextEncoder().encode(JSON.stringify(o)));
  const data = `${enc(header)}.${enc(payload)}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(data),
  );
  return `${data}.${b64u(new Uint8Array(sig))}`;
}

let _accessToken = '';
let _exp = 0;

async function accessToken(): Promise<string> {
  const now = Date.now();
  if (_accessToken && _exp > now + 60_000) return _accessToken;
  const jwt = await signJwt(SA);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const j = await res.json();
  _accessToken = j.access_token;
  _exp = now + (j.expires_in ?? 3600) * 1000;
  return _accessToken;
}

async function sendFcm(token: string, title: string, body: string) {
  const at = await accessToken();
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${at}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: {
            notification: { channel_id: 'wuliao_auto', color: '#E96A8B' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );
  return res.ok;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record || !record.couple_id || !record.user_id) {
      return new Response('ok');
    }

    const isEnter = record.event_type === 'enter';
    const place = record.place_name ?? '某个地点';
    const verb = isEnter ? '到了' : '离开了';
    const title = isEnter ? '📍 自动报备' : '🚪 自动报备';
    const selfBody = `你${verb}${place}`;
    const partnerBody = `Ta ${verb}${place}`;

    // 取情侣双方的 fcm_token
    const { data: members } = await supabase
      .from('profiles')
      .select('id, fcm_token')
      .eq('couple_id', record.couple_id);

    for (const m of members ?? []) {
      if (!m.fcm_token) continue;
      const body = m.id === record.user_id ? selfBody : partnerBody;
      await sendFcm(m.fcm_token, title, body);
    }
    return new Response('ok');
  } catch (e) {
    return new Response('error: ' + (e as Error).message);
  }
});
