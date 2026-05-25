const resp = $('Gemini Transcribe').first().json ?? {};
const { from, user } = $('Audio Handler').first().json;
const etape = $('Audio Handler').first().json.etape;

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

const err = resp?.error?.code;
if (err) {
  let m = 'Transcription failed.';
  if (err === 429) m = 'Gemini quota exceeded. Try again in a few minutes.';
  else if (err === 400) m = 'Audio unreadable by Gemini.';
  else if (err === 403) m = 'Invalid Gemini key.';
  return [{ json: { action: 'send', to: from, text: m, _db_user: toDbUser(user) } }];
}

const t = resp?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
if (!t) return [{ json: { action: 'send', to: from, text: 'Empty transcription.', _db_user: toDbUser(user) } }];

if (etape === 0) return [{ json: { action: 'send', to: from, text: '🎤 ' + t, _db_user: toDbUser(user) } }];

user.flux.pendingTranscription = t;
const fl = user.flux;
return [{
  json: {
    action: 'send', to: from,
    text: '🎤 ' + t + '\n\nUse as message?\n📍 ' + fl.destinataire + '  ' + fl.scheduledLocal + '\nyes / no',
    _db_user: toDbUser(user)
  }
}];
