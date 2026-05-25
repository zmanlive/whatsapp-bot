const init = $('Init Security').first().json;
const pgRows = $input.all();
const now = Date.now();
const from = init.from;

const row = pgRows[0]?.json ?? null;
let user;

if (row && row.phone) {
  const flags = (row.flags && typeof row.flags === 'object') ? row.flags : {};
  user = {
    etape:          row.step ?? 0,
    flux:           (row.draft && typeof row.draft === 'object') ? row.draft : {},
    previousEtape:  flags.previousEtape  ?? null,
    pendingCmd:     flags.pendingCmd     ?? null,
    pendingCancelId:flags.pendingCancelId?? null,
    pendingCancelAll:flags.pendingCancelAll ?? false,
    editingMsgId:   flags.editingMsgId   ?? null,
    editingField:   flags.editingField   ?? null,
    editingDateVal: flags.editingDateVal ?? null,
    lastActivity:   row.last_activity ? new Date(row.last_activity).getTime() : now
  };
} else {
  user = {
    etape: 0, flux: {}, previousEtape: null, pendingCmd: null,
    pendingCancelId: null, pendingCancelAll: false,
    editingMsgId: null, editingField: null, editingDateVal: null,
    lastActivity: now
  };
}

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

if (user.etape > 0 && (now - user.lastActivity) > 30 * 60 * 1000) {
  user.etape = 0; user.flux = {}; user.previousEtape = null; user.pendingCmd = null;
  return [{ json: {
    ...init, user, _early_exit: true,
    action: 'send', to: from, text: 'Flow cancelled (30 min inactive).',
    _db_user: toDbUser(user)
  }}];
}

user.lastActivity = now;
return [{ json: { ...init, user, _early_exit: false } }];
