let { from, msgText, rawText, user } = $json;

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

const send = (text) => [{ json: { action: 'send', to: from, text, _db_user: toDbUser(user) } }];

const isSlash = msgText.startsWith('/');
const cmd = isSlash ? msgText.split(' ')[0] : null;
const cmdArg = isSlash ? (parseInt(msgText.split(' ')[1]) || null) : null;
const mc = (t) => isSlash && cmd === t;

if (user.etape > 0 && user.etape !== 99 && isSlash) {
  user.previousEtape = user.etape; user.etape = 99; user.pendingCmd = msgText;
  return send('Flow in progress. Abandon?\nyes / no');
}

if (user.etape === 99) {
  const ok = msgText === 'yes';
  if (ok) {
    msgText = user.pendingCmd;
    user.etape = 0; user.flux = {}; user.pendingCmd = null; user.previousEtape = null;
  } else {
    user.etape = user.previousEtape ?? 0; user.previousEtape = null; user.pendingCmd = null;
    return send('OK, continuing.');
  }
}

const fwd = (action, extra = {}) => [{ json: { action, from, rawText, msgText, user, n: cmdArg, ...extra } }];

if (mc('/list'))   return fwd('crud_liste');
if (mc('/view'))   return fwd('crud_voir');
if (mc('/edit'))   return fwd('crud_edit');
if (mc('/help'))   return fwd('aide');
if (mc('/cancel') && msgText.includes('all')) return fwd('crud_cancel_all');
if (mc('/cancel')) return fwd('crud_cancel');
return fwd('flux');
