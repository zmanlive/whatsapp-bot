const { from, user, rawBody } = $json;
const fs  = rawBody?.message?.audioMessage?.fileLength ?? 0;
const dur = rawBody?.message?.audioMessage?.seconds ?? 0;
const mUrl = $('Webhook WAHA').first().json?.payload?.media?.url ?? '';
const mId  = rawBody?.id ?? '';

if (fs > 25 * 1024 * 1024)
  return [{ json: { action: 'send', to: from, text: 'Audio too large (max 25MB).', _db_user: null } }];
if (dur > 300)
  return [{ json: { action: 'send', to: from, text: 'Audio too long (max 5 min).', _db_user: null } }];
if (!mUrl)
  return [{ json: { action: 'send', to: from, text: 'Audio unavailable. Try again.', _db_user: null } }];

return [{ json: { action: 'transcribe', from, user, mediaUrl: mUrl, mediaId: mId, etape: user.etape } }];
