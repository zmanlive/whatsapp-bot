let { from, msgText, rawText, user, sd } = $json;
const isSlash = msgText.startsWith('/');
const cmd = isSlash ? msgText.split(' ')[0] : null;
const cmdArg = isSlash ? (parseInt(msgText.split(' ')[1]) || null) : null;
const mc = (t) => isSlash && cmd === t;

if (user.etape > 0 && user.etape !== 99 && isSlash) {
  user.previousEtape = user.etape; user.etape = 99; user.pendingCmd = msgText;
  sd.utilisateurs[from] = user;
  return [{ json: { action: 'send', to: from, text: 'Flow in progress. Abandon?\nyes / no' } }];
}
if (user.etape === 99) {
  const ok = msgText === 'yes';
  if (ok) {
    msgText = user.pendingCmd;
    user.etape = 0; user.flux = {}; user.pendingCmd = null; user.previousEtape = null;
    sd.utilisateurs[from] = user;
  } else {
    user.etape = user.previousEtape ?? 0; user.previousEtape = null; user.pendingCmd = null;
    sd.utilisateurs[from] = user;
    return [{ json: { action: 'send', to: from, text: 'OK, continuing.' } }];
  }
}
if (mc('/list'))   return [{ json: { action: 'crud_liste',      from, sd } }];
if (mc('/view'))   return [{ json: { action: 'crud_voir',       from, sd, n: cmdArg } }];
if (mc('/edit'))   return [{ json: { action: 'crud_edit',       from, sd, n: cmdArg } }];
if (mc('/help'))   return [{ json: { action: 'aide',            from } }];
if (mc('/cancel') && msgText.includes('all'))
                   return [{ json: { action: 'crud_cancel_all', from, sd } }];
if (mc('/cancel')) return [{ json: { action: 'crud_cancel',     from, sd, n: cmdArg } }];
return [{ json: { action: 'flux', from, rawText, msgText, user, sd } }];
