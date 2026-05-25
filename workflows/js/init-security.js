const body = ($input.first().json?.body ?? $input.first().json) ?? {};
const msgId = body.id ?? body.key?.id ?? ('_' + Date.now());
const from = (body.from ?? body.key?.remoteJid ?? '').replace('@s.whatsapp.net', '');
const isAudio = ['audio', 'ptt', 'voice'].includes(body.type ?? '');
const msgType = isAudio ? 'audio' : 'text';
const rawText = (body.body ?? body.message?.conversation ?? '').trim();
const msgText = rawText.toLowerCase();
const sd = $getWorkflowStaticData('global');
sd.processedIds = sd.processedIds ?? {};
sd.utilisateurs = sd.utilisateurs ?? {};
sd.messages = sd.messages ?? [];
sd.config = {
  numeroAutorise: sd.config?.numeroAutorise ?? process.env.AUTHORIZED_NUMBER ?? '',
  nomDefaut: sd.config?.nomDefaut ?? process.env.BOT_NAME ?? '',
  premessageDefaut: sd.config?.premessageDefaut ?? process.env.DEFAULT_PREMESSAGE ?? '',
  timezone: sd.config?.timezone ?? process.env.TZ ?? 'UTC'
};
const now = Date.now();
Object.keys(sd.processedIds).forEach(k => {
  if (now - sd.processedIds[k] > 3600000) delete sd.processedIds[k];
});
if (sd.processedIds[msgId]) return [];
sd.processedIds[msgId] = now;
if (!from || from !== sd.config.numeroAutorise) return [];
sd.utilisateurs[from] ??= {
  langue: 'en', etape: 0, previousEtape: null, pendingCmd: null, lastActivity: now, flux: {}
};
const user = sd.utilisateurs[from];
if (user.etape > 0 && (now - (user.lastActivity ?? 0)) > 30 * 60 * 1000) {
  user.etape = 0; user.flux = {}; user.previousEtape = null; user.pendingCmd = null;
  user.lastActivity = now; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: 'Flow cancelled (30 min inactive).' } }];
}
user.lastActivity = now;
sd.utilisateurs[from] = user;
return [{ json: { from, msgType, msgText, rawText, msgId, rawBody: body, user, sd } }];
