const guardianItems = $('Guardian Logic').all();
const wahaResp = $input.first().json ?? {};
const src      = guardianItems[$itemIndex]?.json ?? {};
const msgId    = src.msgId;
const authNum  = src.authNum;
const now      = new Date().toISOString();

const wahaId = wahaResp?.id ?? wahaResp?.key?.id ?? null;

if (wahaId) {
  return [{ json: {
    action: 'notify', to: authNum,
    text: '✅ Message sent!\n📍 ' + src.destinataire + '\n🕒 ' + src.scheduledLocal,
    _db_msg: {
      id: msgId, status: 'sent',
      waha_message_id: wahaId, sent_at: now,
      retry_count: src.retryCount,
      next_retry_at: null, last_error: null, sending_started_at: null
    }
  }}];
}

const retryCount = (src.retryCount ?? 0) + 1;
const lastError  = JSON.stringify(wahaResp).substring(0, 300);

if (retryCount >= 3) {
  return [{ json: {
    action: 'notify', to: authNum,
    text: '❌ Failed (3 attempts)\n📍 ' + src.destinataire + '\nError: ' + lastError.substring(0, 80),
    _db_msg: {
      id: msgId, status: 'failed',
      retry_count: retryCount, last_error: lastError,
      next_retry_at: null, sending_started_at: null,
      waha_message_id: null, sent_at: null
    }
  }}];
}

return [{ json: {
  action: 'notify', to: authNum,
  text: '[log] Retry #' + retryCount + ' for ' + msgId,
  _db_msg: {
    id: msgId, status: 'pending',
    retry_count: retryCount, last_error: lastError,
    next_retry_at: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
    sending_started_at: null,
    waha_message_id: null, sent_at: null
  }
}}];
