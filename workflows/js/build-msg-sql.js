// Converts _db_msg from Flux CRUD Handler into a { query, params } pair for
// the downstream Postgres executeQuery node. Returns [] when no operation needed.
const { _db_msg } = $('Flux CRUD Handler').first().json;
if (!_db_msg) return [];

const now = new Date().toISOString();
let query, params;

if (_db_msg.op === 'insert') {
  const d = _db_msg.data;
  query = `INSERT INTO bot_messages
    (id, owner, destinataire, timezone, scheduled_at, scheduled_local,
     message, premessage_type, custom_premessage, status, retry_count, created_at, updated_at)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'pending',0,$10,$10)
    ON CONFLICT (id) DO NOTHING`;
  params = [
    d.id, d.owner, d.destinataire, d.timezone,
    d.scheduledAtUtc, d.scheduledLocal,
    d.message, d.premessageType, d.customPremessage ?? null, now
  ];

} else if (_db_msg.op === 'cancel') {
  query  = `UPDATE bot_messages SET status='cancelled', updated_at=$2 WHERE id=$1`;
  params = [_db_msg.id, now];

} else if (_db_msg.op === 'cancel_all') {
  query  = `UPDATE bot_messages SET status='cancelled', updated_at=$1
            WHERE owner=$2 AND status IN ('pending','sending')`;
  params = [now, _db_msg.owner];

} else if (_db_msg.op === 'update') {
  const keys = Object.keys(_db_msg.fields);
  const sets = keys.map((k, i) => `${k}=$${i + 2}`).join(', ');
  query  = `UPDATE bot_messages SET ${sets}, updated_at=$${keys.length + 2} WHERE id=$1`;
  params = [_db_msg.id, ...Object.values(_db_msg.fields), now];

} else {
  return [];
}

return [{ json: { query, params } }];
