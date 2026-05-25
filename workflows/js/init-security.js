const body = ($input.first().json?.body ?? $input.first().json) ?? {};
const msgId = body.id ?? body.key?.id ?? ('_' + Date.now());
const from = (body.from ?? body.key?.remoteJid ?? '').replace('@s.whatsapp.net', '');
const isAudio = ['audio', 'ptt', 'voice'].includes(body.type ?? '');
const msgType = isAudio ? 'audio' : 'text';
const rawText = (body.body ?? body.message?.conversation ?? '').trim();
const msgText = rawText.toLowerCase();

const AUTHORIZED = process.env.AUTHORIZED_NUMBER ?? '';
if (!from || from !== AUTHORIZED) return [];

// Dedup: ephemeral, kept in static data (loss on restart is acceptable)
const sd = $getWorkflowStaticData('global');
sd.processedIds = sd.processedIds ?? {};
const now = Date.now();
Object.keys(sd.processedIds).forEach(k => {
  if (now - sd.processedIds[k] > 3600000) delete sd.processedIds[k];
});
if (sd.processedIds[msgId]) return [];
sd.processedIds[msgId] = now;

return [{ json: { from, msgType, msgText, rawText, msgId, rawBody: body } }];
