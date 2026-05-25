const sd = $getWorkflowStaticData('global');
sd.messages = sd.messages ?? [];
const now = Date.now();
const cfg = sd.config ?? {};

sd.messages.forEach(msg => {
  if (msg.status === 'sending' && msg.sendingStartedAt &&
      now - new Date(msg.sendingStartedAt).getTime() > 5 * 60 * 1000) {
    msg.status = 'pending';
    msg.sendingStartedAt = null;
    msg.nextRetryAtUtc = new Date(now + 2 * 60 * 1000).toISOString();
    msg.lastError = (msg.lastError ?? '') + ' [recovery]';
    msg.updatedAt = new Date(now).toISOString();
  }
});

const toSend = sd.messages.filter(msg =>
  msg.status === 'pending' &&
  new Date(msg.scheduledAtUtc).getTime() <= now &&
  (!msg.nextRetryAtUtc || new Date(msg.nextRetryAtUtc).getTime() <= now)
);

if (!toSend.length) return [];

const att = 'att_' + now;
toSend.forEach(msg => {
  msg.status = 'sending';
  msg.sendingStartedAt = new Date(now).toISOString();
  msg.sendAttemptId = att + '_' + msg.id;
  msg.updatedAt = new Date(now).toISOString();
});

const PREMSG = cfg.premessageDefaut ?? process.env.DEFAULT_PREMESSAGE ?? '';
const AUTH = cfg.numeroAutorise ?? process.env.AUTHORIZED_NUMBER ?? '';

return toSend.map(msg => {
  let t;
  if (msg.premessageType === 'default') t = PREMSG + '\n"' + msg.message + '"';
  else if (msg.premessageType === 'custom') t = (msg.customPremessage ?? '') + '\n"' + msg.message + '"';
  else t = msg.message;
  return { json: { msgId: msg.id, to: msg.destinataire, text: t, authNum: AUTH } };
});
