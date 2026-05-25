const sd = $getWorkflowStaticData('global');
const guardianItems = $('Guardian Logic').all();
const wahaResp = $input.first().json ?? {};
const src = guardianItems[$itemIndex]?.json ?? {};
const msgId = src.msgId;
const authNum = src.authNum;
const now = new Date().toISOString();
const msg = (sd.messages ?? []).find(m => m.id === msgId);

if (!msg) return [{ json: { action: 'notify', to: authNum, text: '[log] not found: ' + msgId } }];

const wahaId = wahaResp?.id ?? wahaResp?.key?.id ?? null;
if (wahaId) {
  msg.status = 'sent'; msg.wahaMessageId = wahaId; msg.sentAt = now;
  msg.updatedAt = now; msg.sendingStartedAt = null;
  return [{ json: { action: 'notify', to: authNum,
    text: '✅ Message sent!\n📍 ' + msg.destinataire + '\n🕒 ' + msg.scheduledLocal
  } }];
}

msg.retryCount = (msg.retryCount ?? 0) + 1;
msg.lastError = JSON.stringify(wahaResp).substring(0, 300);
msg.updatedAt = now; msg.sendingStartedAt = null;

if (msg.retryCount >= 3) {
  msg.status = 'failed';
  return [{ json: { action: 'notify', to: authNum,
    text: '❌ Failed (3 attempts)\n📍 ' + msg.destinataire + '\nError: ' + msg.lastError.substring(0, 80)
  } }];
}

msg.status = 'pending';
msg.nextRetryAtUtc = new Date(Date.now() + 2 * 60 * 1000).toISOString();
return [{ json: { action: 'notify', to: authNum, text: '[log] Retry #' + msg.retryCount + ' for ' + msgId } }];
