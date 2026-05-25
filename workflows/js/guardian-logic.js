// Each item is a row from PG Recover+Select (bot_messages WHERE status just set to 'sending')
const row = $json;
const PREMSG = process.env.DEFAULT_PREMESSAGE ?? '';
const AUTH   = process.env.AUTHORIZED_NUMBER  ?? '';

let text;
if (row.premessage_type === 'default')       text = PREMSG + '\n"' + row.message + '"';
else if (row.premessage_type === 'custom')   text = (row.custom_premessage ?? '') + '\n"' + row.message + '"';
else                                          text = row.message;

return [{ json: {
  msgId:          row.id,
  to:             row.destinataire,
  text,
  authNum:        AUTH,
  scheduledLocal: row.scheduled_local,
  destinataire:   row.destinataire,
  retryCount:     row.retry_count ?? 0
} }];
