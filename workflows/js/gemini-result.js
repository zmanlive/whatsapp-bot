const resp = $('Gemini Transcribe').first().json ?? {};
const { from, user, sd, etape } = $('Audio Handler').first().json;
const err = resp?.error?.code;
if (err) {
  let m = 'Transcription failed.';
  if (err === 429) m = 'Gemini quota exceeded. Try again in a few minutes.';
  else if (err === 400) m = 'Audio unreadable by Gemini.';
  else if (err === 403) m = 'Invalid Gemini key.';
  return [{ json: { action: 'send', to: from, text: m } }];
}
const t = resp?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
if (!t) return [{ json: { action: 'send', to: from, text: 'Empty transcription.' } }];
if (etape === 0) return [{ json: { action: 'send', to: from, text: '🎤 ' + t } }];
user.flux.pendingTranscription = t;
sd.utilisateurs[from] = user;
const fl = user.flux;
return [{
  json: {
    action: 'send', to: from,
    text: '🎤 ' + t + '\n\nUse as message?\n📍 ' + fl.destinataire + '  ' + fl.scheduledLocal + '\nyes / no'
  }
}];
