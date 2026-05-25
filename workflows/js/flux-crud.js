const { action, from, rawText, msgText, user, n } = $json;
const fl = user?.flux ?? {};
const TZ = process.env.TZ ?? 'UTC';
const { DateTime } = require('luxon');

// Messages loaded from PostgreSQL by the previous node
const messages = $('PG Read Messages').all().map(i => i.json);

const M = {
  askDate:      'Number ok. Send date (ex: 20/05/2026)',
  askTime:      'Date ok. Send time (ex: 14:30)',
  askMsg:       'Time ok. Send your message (text or voice note)',
  askPre:       'Message received.\n1=Default pre-message\n2=None\n3=Custom',
  askCustom:    'Write your pre-message:',
  confirm:      (f) => 'Confirm?\n📍 ' + f.destinataire + '\n🕒 ' + f.scheduledLocal + '\n💬 "' + f.message + '"\n\nyes / no',
  saved:        (id) => 'Scheduled! Ref: ' + id + '\n/list to view',
  badNum:       'Invalid number. Ex: 33612345678',
  badDate:      'Invalid or past date. Ex: 20/05/2026',
  badTime:      'Invalid or past time. Ex: 14:30',
  badPre:       'Reply 1, 2 or 3',
  warnNone:     'Recipient will receive the message without any context.',
  cancelled:    'Flow cancelled.',
  noMsgs:       'No scheduled messages.',
  notFound:     'Message not found.',
  notCancel:    'Message already sent.',
  deleted:      'Message deleted.',
  deletedAll:   'All messages deleted.',
  confirmDel:    (id) => 'Delete ' + id + '?\nyes / no',
  confirmDelAll: 'Delete ALL messages?\nyes / no',
  editMenu:     'What to edit?\n1=Number 2=Date+Time 3=Message 4=Pre-message',
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

const toDbUser = (u) => ({
  phone: from,
  step:  u.etape,
  draft: u.flux ?? {},
  flags: {
    previousEtape:   u.previousEtape,
    pendingCmd:      u.pendingCmd,
    pendingCancelId: u.pendingCancelId,
    pendingCancelAll:u.pendingCancelAll,
    editingMsgId:    u.editingMsgId,
    editingField:    u.editingField,
    editingDateVal:  u.editingDateVal
  }
});

const out = (text, db_msg = null) => [{
  json: { action: 'send', to: from, text, _db_user: toDbUser(user), _db_msg: db_msg }
}];

// ── CRUD commands ──────────────────────────────────────────────────────────────

if (action === 'aide') return out(M.help);

if (action === 'crud_liste') {
  const ms = messages.filter(r => ['pending', 'sending'].includes(r.status));
  if (!ms.length) return out(M.noMsgs);
  const list = ms.map((r, i) =>
    '#' + (i + 1) + ' ' + r.id.substring(0, 18) +
    '\n ' + r.destinataire + ' | 🕒 ' + r.scheduled_local + ' | ' + r.status
  ).join('\n\n');
  return out('📋 ' + list + '\n\n/view /edit /cancel');
}

if (action === 'crud_voir') {
  const r = messages.find(r => n ? r.id.includes(String(n)) : false);
  if (!r) return out(M.notFound);
  return out('📋 ' + r.id + '\n📍 ' + r.destinataire + '\n🕒 ' + r.scheduled_local + '\n💬 "' + r.message + '"\nStatus: ' + r.status);
}

if (action === 'crud_cancel') {
  const r = messages.find(r => n ? r.id.includes(String(n)) : false);
  if (!r) return out(M.notFound);
  if (r.status === 'sent') return out(M.notCancel);
  user.pendingCancelId = r.id;
  return out(M.confirmDel(r.id.substring(0, 18)));
}

if (action === 'crud_cancel_all') {
  user.pendingCancelAll = true;
  return out(M.confirmDelAll);
}

if (action === 'crud_edit') {
  const r = messages.find(r => n ? r.id.includes(String(n)) : false);
  if (!r) return out(M.notFound);
  user.editingMsgId = r.id; user.editingField = null; user.editingDateVal = null;
  return out(M.editMenu);
}

// ── Pending confirmations ──────────────────────────────────────────────────────

if (user.pendingCancelId && (isOui || isNon)) {
  const cid = user.pendingCancelId; user.pendingCancelId = null;
  if (isOui) return out(M.deleted, { op: 'cancel', id: cid });
  return out('OK.');
}

if (user.pendingCancelAll && (isOui || isNon)) {
  user.pendingCancelAll = false;
  if (isOui) return out(M.deletedAll, { op: 'cancel_all', owner: from });
  return out('OK.');
}

// ── Edit field selection ───────────────────────────────────────────────────────

if (user.editingMsgId && !user.editingField) {
  const choice = parseInt(msgText);
  if ([1, 2, 3, 4].includes(choice)) {
    user.editingField = ['destinataire', 'datetime', 'message', 'premessage_type'][choice - 1];
    const ask = [
      'New number:',
      'New date and time (ex: 20/05/2026 14:30):',
      'New message:',
      'Pre-message (1=default 2=none 3=custom):'
    ][choice - 1];
    return out(ask);
  }
  user.editingMsgId = null;
  return out('Cancelled.');
}

if (user.editingMsgId && user.editingField) {
  const r = messages.find(r => r.id === user.editingMsgId);
  if (!r) { user.editingMsgId = null; user.editingField = null; return out(M.notFound); }

  const f = user.editingField;
  let updateFields = {};

  if (f === 'destinataire') {
    if (!/^[0-9]{8,15}$/.test(rawText)) return out(M.badNum);
    updateFields.destinataire = rawText;
  } else if (f === 'datetime') {
    const parts = rawText.trim().split(/\s+/);
    if (parts.length < 2) return out('Send date and time together (ex: 20/05/2026 14:30)');
    const [ds, ts] = parts;
    if (!vd(ds)) return out(M.badDate);
    if (!vdt(ds, ts)) return out(M.badTime);
    const sc = toSched(ds, ts);
    updateFields.scheduled_at = sc.utc;
    updateFields.scheduled_local = sc.local;
  } else if (f === 'message') {
    updateFields.message = rawText;
  } else if (f === 'premessage_type') {
    if (msgText === '1') updateFields.premessage_type = 'default';
    else if (msgText === '2') updateFields.premessage_type = 'none';
    else if (msgText === '3') updateFields.premessage_type = 'custom';
    else return out(M.badPre);
  }

  user.editingMsgId = null; user.editingField = null; user.editingDateVal = null;
  const db_msg = Object.keys(updateFields).length ? { op: 'update', id: r.id, fields: updateFields } : null;
  return out('Modified!', db_msg);
}

// ── Scheduling flow ────────────────────────────────────────────────────────────

if (user.etape === 0) {
  const lines = rawText.split('\n').map(s => s.trim()).filter(Boolean);
  if (lines.length >= 4) {
    const [num, ds, ts, ...mp] = lines;
    if (!/^[0-9]{8,15}$/.test(num)) return out(M.badNum);
    if (!vd(ds)) return out(M.badDate);
    if (!vdt(ds, ts)) return out(M.badTime);
    const sc = toSched(ds, ts);
    fl.destinataire = num; fl.date = ds; fl.heure = ts; fl.message = mp.join(' ');
    fl.scheduledAtUtc = sc.utc; fl.scheduledLocal = sc.local;
    user.etape = 4; user.flux = fl;
    return out(M.askPre);
  }
  if (/^[0-9]{8,15}$/.test(rawText)) {
    fl.destinataire = rawText; user.etape = 1; user.flux = fl;
    return out(M.askDate);
  }
  return out(M.badNum);
}

if (user.etape === 1) {
  if (!vd(rawText)) return out(M.badDate);
  fl.date = rawText; user.etape = 2; user.flux = fl;
  return out(M.askTime);
}

if (user.etape === 2) {
  if (!vdt(fl.date, rawText)) return out(M.badTime);
  const sc = toSched(fl.date, rawText);
  fl.heure = rawText; fl.scheduledAtUtc = sc.utc; fl.scheduledLocal = sc.local;
  user.etape = 3; user.flux = fl;
  return out(M.askMsg);
}

if (user.etape === 3) {
  if (fl.pendingTranscription) {
    if (isOui)      { fl.message = fl.pendingTranscription; fl.pendingTranscription = null; }
    else if (isNon) {
      fl.pendingTranscription = null; user.flux = fl;
      return out('Send a message or voice note.');
    } else { fl.message = rawText; fl.pendingTranscription = null; }
  } else { fl.message = rawText; }
  user.etape = 4; user.flux = fl;
  return out(M.askPre);
}

if (user.etape === 4) {
  if      (msgText === '1') { fl.premessageType = 'default'; user.etape = 6; }
  else if (msgText === '2') { fl.premessageType = 'none';    user.etape = 6; }
  else if (msgText === '3') { user.etape = 5; user.flux = fl; return out(M.askCustom); }
  else return out(M.badPre);
  user.flux = fl;
  const pre = fl.premessageType === 'none' ? M.warnNone + '\n\n' : '';
  return out(pre + M.confirm(fl));
}

if (user.etape === 5) {
  fl.premessageType = 'custom'; fl.customPremessage = rawText;
  user.etape = 6; user.flux = fl;
  return out(M.confirm(fl));
}

if (user.etape === 6) {
  if (!isOui) {
    user.etape = 0; user.flux = {};
    return out(M.cancelled);
  }
  const id = 'msg_' + Date.now() + '_' + Math.random().toString(36).substr(2, 4);
  user.etape = 0; user.flux = {};
  return out(M.saved(id), {
    op: 'insert',
    data: {
      id, owner: from, destinataire: fl.destinataire, timezone: TZ,
      scheduledAtUtc: fl.scheduledAtUtc, scheduledLocal: fl.scheduledLocal,
      message: fl.message, premessageType: fl.premessageType,
      customPremessage: fl.customPremessage ?? null
    }
  });
}

return out('Type /help for help.');
