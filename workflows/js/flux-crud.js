const { action, from, rawText, msgText, user, sd, n } = $json;
const fl = user?.flux ?? {};
const TZ = sd.config?.timezone ?? 'UTC';
const { DateTime } = require('luxon');

const M = {
  askDate:   'Number ok. Send date (ex: 20/05/2026)',
  askTime:   'Date ok. Send time (ex: 14:30)',
  askMsg:    'Time ok. Send your message (text or voice note)',
  askPre:    'Message received.\n1=Default pre-message\n2=None\n3=Custom',
  askCustom: 'Write your pre-message:',
  confirm:   (f) => 'Confirm?\n📍 ' + f.destinataire + '\n🕒 ' + f.scheduledLocal + '\n💬 "' + f.message + '"\n\nyes / no',
  saved:     (id) => 'Scheduled! Ref: ' + id + '\n/list to view',
  badNum:    'Invalid number. Ex: 33612345678',
  badDate:   'Invalid or past date. Ex: 20/05/2026',
  badTime:   'Invalid or past time. Ex: 14:30',
  badPre:    'Reply 1, 2 or 3',
  warnNone:  'Recipient will receive the message without any context.',
  cancelled: 'Flow cancelled.',
  noMsgs:    'No scheduled messages.',
  notFound:  'Message not found.',
  notCancel: 'Message already sent.',
  deleted:   'Message deleted.',
  deletedAll:'All messages deleted.',
  confirmDel:    (id) => 'Delete ' + id + '?\nyes / no',
  confirmDelAll: 'Delete ALL messages?\nyes / no',
  editMenu:  'What to edit?\n1=Number 2=Date 3=Time 4=Message 5=Pre-message',
  help: 'Commands: /list  /view [n]  /edit [n]  /cancel [n]  /help\n\n' +
        'Schedule a message:\n' +
        '  Send the recipient number, then follow the prompts:\n' +
        '  → date (ex: 25/05/2026)\n' +
        '  → time (ex: 14:30)\n' +
        '  → your message (text or voice note)\n' +
        '  → pre-message (1=default  2=none  3=custom)\n' +
        '  → confirm with yes\n\n' +
        '  Shortcut — send all at once:\n' +
        '  33612345678\n' +
        '  25/05/2026\n' +
        '  14:30\n' +
        '  Your message here\n\n' +
        'Voice notes → instant transcription by Gemini.\n' +
        'Timeout: 30 min of inactivity resets the flow.'
};

function pd(s) {
  if (/^\d{2}\/\d{2}\/\d{4}$/.test(s)) return DateTime.fromFormat(s, 'dd/MM/yyyy', { zone: TZ });
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return DateTime.fromFormat(s, 'yyyy-MM-dd', { zone: TZ });
  return null;
}
function vd(s) { const d = pd(s); return d?.isValid && d >= DateTime.now().setZone(TZ).startOf('day'); }
function vdt(ds, ts) {
  const d = pd(ds); if (!d?.isValid) return false;
  const [h, m] = ts.split(':').map(Number);
  if (isNaN(h) || isNaN(m) || h > 23 || m > 59) return false;
  return d.set({ hour: h, minute: m }) > DateTime.now().setZone(TZ);
}
function toSched(ds, ts) {
  const d = pd(ds); const [h, m] = ts.split(':').map(Number);
  const full = d.set({ hour: h, minute: m, second: 0 });
  return { utc: full.toUTC().toISO(), local: full.toFormat('dd/MM/yyyy') + ' at ' + ts + ' (' + TZ + ')' };
}

const isOui = msgText === 'yes';
const isNon = msgText === 'no';

if (action === 'aide') return [{ json: { action: 'send', to: from, text: M.help } }];

if (action === 'crud_liste') {
  const ms = (sd.messages ?? []).filter(m => ['pending', 'sending'].includes(m.status));
  if (!ms.length) return [{ json: { action: 'send', to: from, text: M.noMsgs } }];
  const list = ms.map((m, i) =>
    '#' + (i + 1) + ' ' + m.id.substring(0, 18) + '\n ' + m.destinataire + ' | 🕒 ' + m.scheduledLocal + ' | ' + m.status
  ).join('\n\n');
  return [{ json: { action: 'send', to: from, text: '📋 ' + list + '\n\n/view /edit /cancel' } }];
}

if (action === 'crud_voir') {
  const msg = (sd.messages ?? []).find(m => n ? m.id.includes(String(n)) : false);
  if (!msg) return [{ json: { action: 'send', to: from, text: M.notFound } }];
  return [{ json: { action: 'send', to: from,
    text: '📋 ' + msg.id + '\n📍 ' + msg.destinataire + '\n🕒 ' + msg.scheduledLocal + '\n💬 "' + msg.message + '"\nStatus: ' + msg.status
  } }];
}

if (action === 'crud_cancel') {
  const msg = (sd.messages ?? []).find(m => n ? m.id.includes(String(n)) : false);
  if (!msg) return [{ json: { action: 'send', to: from, text: M.notFound } }];
  if (msg.status === 'sent') return [{ json: { action: 'send', to: from, text: M.notCancel } }];
  user.pendingCancelId = msg.id; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.confirmDel(msg.id.substring(0, 18)) } }];
}

if (action === 'crud_cancel_all') {
  user.pendingCancelAll = true; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.confirmDelAll } }];
}

if (action === 'crud_edit') {
  const msg = (sd.messages ?? []).find(m => n ? m.id.includes(String(n)) : false);
  if (!msg) return [{ json: { action: 'send', to: from, text: M.notFound } }];
  user.editingMsgId = msg.id; user.editingField = null;
  sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.editMenu } }];
}

if (user.pendingCancelId && (isOui || isNon)) {
  const cid = user.pendingCancelId; user.pendingCancelId = null;
  sd.utilisateurs[from] = user;
  if (isOui) {
    const msg = (sd.messages ?? []).find(m => m.id === cid);
    if (msg) { msg.status = 'cancelled'; msg.updatedAt = new Date().toISOString(); }
    return [{ json: { action: 'send', to: from, text: M.deleted } }];
  }
  return [{ json: { action: 'send', to: from, text: 'OK.' } }];
}

if (user.pendingCancelAll && (isOui || isNon)) {
  user.pendingCancelAll = false; sd.utilisateurs[from] = user;
  if (isOui) {
    (sd.messages ?? []).forEach(m => {
      if (['pending', 'sending'].includes(m.status)) {
        m.status = 'cancelled'; m.updatedAt = new Date().toISOString();
      }
    });
    return [{ json: { action: 'send', to: from, text: M.deletedAll } }];
  }
  return [{ json: { action: 'send', to: from, text: 'OK.' } }];
}

if (user.editingMsgId && !user.editingField) {
  const choice = parseInt(msgText);
  if ([1, 2, 3, 4, 5].includes(choice)) {
    user.editingField = ['destinataire', 'date', 'heure', 'message', 'premessageType'][choice - 1];
    sd.utilisateurs[from] = user;
    const ask = ['New number:', 'New date (ex: 20/05/2026):', 'New time (ex: 14:30):', 'New message:', 'Pre-message (1=default 2=none 3=custom):'][choice - 1];
    return [{ json: { action: 'send', to: from, text: ask } }];
  }
  user.editingMsgId = null; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: 'Cancelled.' } }];
}

if (user.editingMsgId && user.editingField) {
  const msg = (sd.messages ?? []).find(m => m.id === user.editingMsgId);
  if (msg) {
    const f = user.editingField;
    if (f === 'destinataire') {
      if (!/^[0-9]{8,15}$/.test(rawText)) return [{ json: { action: 'send', to: from, text: M.badNum } }];
      msg.destinataire = rawText;
    } else if (f === 'date') {
      if (!vd(rawText)) return [{ json: { action: 'send', to: from, text: M.badDate } }];
      msg.date = rawText;
    } else if (f === 'heure') {
      if (!vdt(msg.date ?? msg.scheduledLocal, rawText)) return [{ json: { action: 'send', to: from, text: M.badTime } }];
      const sc = toSched(msg.date ?? msg.scheduledLocal.split(' ')[0], rawText);
      msg.scheduledAtUtc = sc.utc; msg.scheduledLocal = sc.local; msg.heure = rawText;
    } else if (f === 'message') {
      msg.message = rawText;
    } else if (f === 'premessageType') {
      if (msgText === '1') msg.premessageType = 'default';
      else if (msgText === '2') msg.premessageType = 'none';
      else if (msgText === '3') msg.premessageType = 'custom';
    }
    msg.updatedAt = new Date().toISOString();
  }
  user.editingMsgId = null; user.editingField = null; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: 'Modified!' } }];
}

if (user.etape === 0) {
  const lines = rawText.split('\n').map(s => s.trim()).filter(Boolean);
  if (lines.length >= 4) {
    const [num, ds, ts, ...mp] = lines;
    if (!/^[0-9]{8,15}$/.test(num)) return [{ json: { action: 'send', to: from, text: M.badNum } }];
    if (!vd(ds)) return [{ json: { action: 'send', to: from, text: M.badDate } }];
    if (!vdt(ds, ts)) return [{ json: { action: 'send', to: from, text: M.badTime } }];
    const sc = toSched(ds, ts);
    fl.destinataire = num; fl.date = ds; fl.heure = ts; fl.message = mp.join(' ');
    fl.scheduledAtUtc = sc.utc; fl.scheduledLocal = sc.local;
    user.etape = 4; user.flux = fl; sd.utilisateurs[from] = user;
    return [{ json: { action: 'send', to: from, text: M.askPre } }];
  }
  if (/^[0-9]{8,15}$/.test(rawText)) {
    fl.destinataire = rawText; user.etape = 1; user.flux = fl; sd.utilisateurs[from] = user;
    return [{ json: { action: 'send', to: from, text: M.askDate } }];
  }
  return [{ json: { action: 'send', to: from, text: M.badNum } }];
}

if (user.etape === 1) {
  if (!vd(rawText)) return [{ json: { action: 'send', to: from, text: M.badDate } }];
  fl.date = rawText; user.etape = 2; user.flux = fl; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.askTime } }];
}

if (user.etape === 2) {
  if (!vdt(fl.date, rawText)) return [{ json: { action: 'send', to: from, text: M.badTime } }];
  const sc = toSched(fl.date, rawText);
  fl.heure = rawText; fl.scheduledAtUtc = sc.utc; fl.scheduledLocal = sc.local;
  user.etape = 3; user.flux = fl; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.askMsg } }];
}

if (user.etape === 3) {
  if (fl.pendingTranscription) {
    if (isOui) { fl.message = fl.pendingTranscription; fl.pendingTranscription = null; }
    else if (isNon) {
      fl.pendingTranscription = null; user.flux = fl; sd.utilisateurs[from] = user;
      return [{ json: { action: 'send', to: from, text: 'Send a message or voice note.' } }];
    } else { fl.message = rawText; fl.pendingTranscription = null; }
  } else { fl.message = rawText; }
  user.etape = 4; user.flux = fl; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.askPre } }];
}

if (user.etape === 4) {
  if (msgText === '1') { fl.premessageType = 'default'; user.etape = 6; }
  else if (msgText === '2') { fl.premessageType = 'none'; user.etape = 6; }
  else if (msgText === '3') {
    user.etape = 5; user.flux = fl; sd.utilisateurs[from] = user;
    return [{ json: { action: 'send', to: from, text: M.askCustom } }];
  } else return [{ json: { action: 'send', to: from, text: M.badPre } }];
  user.flux = fl; sd.utilisateurs[from] = user;
  const pre = fl.premessageType === 'none' ? M.warnNone + '\n\n' : '';
  return [{ json: { action: 'send', to: from, text: pre + M.confirm(fl) } }];
}

if (user.etape === 5) {
  fl.premessageType = 'custom'; fl.customPremessage = rawText;
  user.etape = 6; user.flux = fl; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.confirm(fl) } }];
}

if (user.etape === 6) {
  if (!isOui) {
    user.etape = 0; user.flux = {}; sd.utilisateurs[from] = user;
    return [{ json: { action: 'send', to: from, text: M.cancelled } }];
  }
  const id = 'msg_' + Date.now() + '_' + Math.random().toString(36).substr(2, 4);
  const nm = {
    id, destinataire: fl.destinataire, timezone: TZ,
    scheduledAtUtc: fl.scheduledAtUtc, scheduledLocal: fl.scheduledLocal,
    message: fl.message, premessageType: fl.premessageType,
    customPremessage: fl.customPremessage ?? null,
    status: 'pending', retryCount: 0, nextRetryAtUtc: null,
    sendingStartedAt: null, sendAttemptId: null, wahaMessageId: null,
    lastError: null, createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(), sentAt: null
  };
  sd.messages.push(nm);
  user.etape = 0; user.flux = {}; sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: M.saved(id) } }];
}

return [{ json: { action: 'send', to: from, text: 'Type /help for help.' } }];
