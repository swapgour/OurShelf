// Cloudflare Worker — does two jobs for OurShelf, both free, no Blaze/card:
//
// 1. "notify" (default/no `type`): replaces the Firebase Cloud Function
//    trigger. Given a groupId, reads that group's members from Firestore,
//    collects their fcmTokens, and sends each one a push via the FCM HTTP
//    v1 API — skipping whoever triggered it.
//
// 2. "ask": powers the Ask AI assistant. Reads the group's own shopping
//    list, pantry and purchase history from Firestore, hands it to a Groq
//    model as context, and returns an answer grounded in that data only.
//    The model to use is fetched live from Groq's /models endpoint on every
//    call (never hardcoded), so if a model is renamed or retired, the next
//    request just picks whatever's current — nothing to redeploy.
//
// Required secrets (dashboard → Settings → Variables and Secrets):
//   FIREBASE_PROJECT_ID    e.g. ourshelf-de6b0
//   FIREBASE_CLIENT_EMAIL  the "client_email" from a Firebase service
//                          account JSON (Project Settings → Service
//                          accounts → Generate new private key)
//   FIREBASE_PRIVATE_KEY   the "private_key" from that same JSON, pasted
//                          as-is including the BEGIN/END lines
//   GROQ_API_KEY           your Groq API secret key (console.groq.com)
//
// Generating the Firebase service-account key does NOT require Blaze —
// it's free on the Spark plan.

async function importPrivateKey(pem) {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    // Strip literal backslash-n (how some dashboards store a pasted \n) as
    // well as real whitespace/newlines, so either form decodes cleanly.
    .replace(/\\n/g, '')
    .replace(/\s/g, '');
  const binary = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binary,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function base64url(bytes) {
  const str = typeof bytes === 'string' ? bytes : String.fromCharCode(...new Uint8Array(bytes));
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function getAccessToken(env) {
  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: env.FIREBASE_CLIENT_EMAIL,
    scope:
      'https://www.googleapis.com/auth/datastore ' +
      'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const toSign = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claim))}`;
  const key = await importPrivateKey(env.FIREBASE_PRIVATE_KEY);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(toSign),
  );
  const jwt = `${toSign}.${base64url(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' +
      encodeURIComponent(jwt),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error('token error: ' + JSON.stringify(data));
  return data.access_token;
}

async function firestoreGet(env, token, path) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/${path}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) return null;
  return res.json();
}

/// Lists a whole collection (used for items/pantry — small per-family
/// collections, so one page comfortably covers them).
async function firestoreList(env, token, path, pageSize = 300) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/${path}?pageSize=${pageSize}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) return [];
  const data = await res.json();
  return data.documents || [];
}

// Decodes one Firestore REST "Value" into a plain JS value, recursively.
function fsDecode(value) {
  if (value == null) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('mapValue' in value) {
    const out = {};
    for (const [k, v] of Object.entries(value.mapValue.fields || {})) out[k] = fsDecode(v);
    return out;
  }
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(fsDecode);
  return null;
}

function docToPlain(doc) {
  const out = { id: doc.name.split('/').pop() };
  for (const [k, v] of Object.entries(doc.fields || {})) out[k] = fsDecode(v);
  return out;
}

async function handleNotify(request, env, payload) {
  const { groupId, excludeUid, title, body } = payload;
  if (!groupId || !title || !body) {
    return new Response('missing fields', { status: 400 });
  }

  const token = await getAccessToken(env);
  const groupDoc = await firestoreGet(env, token, `groups/${groupId}`);
  const membersMap = groupDoc ? (docToPlain(groupDoc).members || {}) : {};
  const uids = Object.keys(membersMap).filter((uid) => uid !== excludeUid);
  if (uids.length === 0) return new Response('no recipients', { status: 200 });

  const tokens = [];
  for (const uid of uids) {
    const userDoc = await firestoreGet(env, token, `users/${uid}`);
    const fcmTokens = userDoc ? docToPlain(userDoc).fcmTokens : null;
    if (Array.isArray(fcmTokens)) tokens.push(...fcmTokens);
  }
  if (tokens.length === 0) return new Response('no tokens', { status: 200 });

  await Promise.all(
    tokens.map((t) =>
      fetch(`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: t,
            notification: { title, body },
            data: { groupId: String(groupId) },
          },
        }),
      }),
    ),
  );
  return new Response('sent', { status: 200 });
}

async function buildGroupContext(env, token, groupId) {
  const groupDoc = await firestoreGet(env, token, `groups/${groupId}`);
  const group = groupDoc ? docToPlain(groupDoc) : {};
  const membersMap = group.members || {};
  const memberNames = Object.values(membersMap)
    .map((m) => m.displayName)
    .filter(Boolean)
    .join(', ') || 'Unknown';

  const items = (await firestoreList(env, token, `groups/${groupId}/items`)).map(docToPlain);
  const pantry = (await firestoreList(env, token, `groups/${groupId}/pantry`)).map(docToPlain);

  const toBuy = items.filter((i) => i.status === 'to_buy');
  const bought = items.filter((i) => i.status === 'bought');

  const lines = [];
  lines.push(`Today's date: ${new Date().toISOString().slice(0, 10)}`);
  lines.push(`Group: ${group.name || 'Family'} | Members: ${memberNames}`);

  lines.push(`\nTO-BUY LIST (${toBuy.length} items):`);
  for (const i of toBuy) {
    lines.push(`- ${i.name} | qty ${i.quantity ?? '?'} ${i.unit ?? ''} | category ${i.category ?? 'Other'} | added by ${i.addedByName ?? '?'}`);
  }

  lines.push(`\nPURCHASE HISTORY (${bought.length} items):`);
  for (const i of bought) {
    lines.push(
      `- ${i.name} | qty ${i.quantity ?? '?'} ${i.unit ?? ''} | price ₹${i.price ?? '?'} | ` +
        `bought ${i.boughtAt ?? '?'} | paid by ${i.paidByName ?? i.addedByName ?? '?'} | category ${i.category ?? 'Other'}`,
    );
  }

  lines.push(`\nPANTRY (${pantry.length} items):`);
  for (const p of pantry) {
    lines.push(
      `- ${p.name} | level ${p.level ?? '?'} | category ${p.category ?? 'Other'}` +
        (p.expiryDate ? ` | expires ${p.expiryDate}` : ''),
    );
  }

  return lines.join('\n');
}

const NON_CHAT_MODEL = /whisper|tts|guard|vision|embed|safety/i;
const PREFERRED_MODEL_PATTERNS = [/gpt-oss-120b/, /llama-3\.3-70b/, /70b/, /versatile/, /gpt-oss/];

async function listGroqModels(apiKey) {
  const res = await fetch('https://api.groq.com/openai/v1/models', {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  if (!res.ok) return [];
  const data = await res.json();
  return (data.data || []).filter((m) => m.active !== false).map((m) => m.id);
}

function pickBestModel(models, exclude = []) {
  const candidates = models.filter((id) => !exclude.includes(id) && !NON_CHAT_MODEL.test(id));
  for (const pattern of PREFERRED_MODEL_PATTERNS) {
    const hit = candidates.find((id) => pattern.test(id));
    if (hit) return hit;
  }
  return candidates[0] || models.find((id) => !exclude.includes(id)) || null;
}

async function askGroq(env, context, question, history) {
  const models = await listGroqModels(env.GROQ_API_KEY);
  if (models.length === 0) throw new Error('No Groq models available — check GROQ_API_KEY');

  const systemPrompt =
    "You are OurShelf's family grocery assistant. Answer the question using " +
    "ONLY the household data below — never invent items, prices or members " +
    "that aren't listed. Be concise and friendly. If the data doesn't " +
    "answer the question, say so honestly instead of guessing.\n\n" +
    "Format every answer in Markdown, rendered in a chat bubble:\n" +
    "- Use a Markdown table whenever you list more than two items with any " +
    "attribute (name + price, name + quantity, member + amount, etc).\n" +
    "- Use bullet points for simple lists, **bold** for totals/important " +
    "numbers, and short headings only if the answer has distinct sections.\n" +
    "- Sprinkle a few relevant emojis in naturally (🛒 🥦 🥛 💰 ✅ etc.) — " +
    "don't overdo it, one or two per section is enough.\n" +
    "- Keep it skimmable: short lines, no big walls of text.\n\n" + context;

  const messages = [
    { role: 'system', content: systemPrompt },
    ...(Array.isArray(history) ? history : []),
    { role: 'user', content: question },
  ];

  let model = pickBestModel(models);
  const tried = [];
  for (let attempt = 0; attempt < 2 && model; attempt++) {
    tried.push(model);
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: 0.4,
        max_completion_tokens: 700,
      }),
    });
    if (res.ok) {
      const data = await res.json();
      return data.choices?.[0]?.message?.content?.trim() || "I couldn't come up with an answer.";
    }
    // The chosen model may have just been renamed/retired — pick a
    // different live model and try once more before giving up.
    const bodyText = await res.text();
    const next = pickBestModel(models, tried);
    if (!next) throw new Error(`Groq error (model ${model}): ${bodyText}`);
    model = next;
  }
  throw new Error('Groq request failed after retrying with an alternate model.');
}

async function handleAsk(request, env, payload) {
  const { groupId, question, history } = payload;
  if (!groupId || !question) return new Response('missing fields', { status: 400 });

  const token = await getAccessToken(env);
  const context = await buildGroupContext(env, token, groupId);
  const answer = await askGroq(env, context, question, history);
  return new Response(JSON.stringify({ answer }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return new Response('ok', { status: 200 });

    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response('bad request', { status: 400 });
    }

    try {
      if (payload.type === 'ask') return await handleAsk(request, env, payload);
      return await handleNotify(request, env, payload);
    } catch (err) {
      return new Response('error: ' + err.message, { status: 500 });
    }
  },
};
