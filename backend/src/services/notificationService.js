const admin = require('../config/firebase');
const User = require('../models/User');
const logger = require('./logger');

// ─── Send to single user ──────────────────────────────────────────────────────
exports.sendPushNotification = async ({ userId, title, body, data = {} }) => {
  try {
    const user = await User.findById(userId).select('fcmTokens name');
    if (!user || !user.fcmTokens?.length) return;

    const validTokens = user.fcmTokens.filter(Boolean);
    if (!validTokens.length) return;

    const message = {
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high', notification: { sound: 'default', channelId: 'society_ledger' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      tokens: validTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // Remove invalid tokens
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error?.code === 'messaging/registration-token-not-registered') {
        invalidTokens.push(validTokens[idx]);
      }
    });

    if (invalidTokens.length) {
      await User.findByIdAndUpdate(userId, {
        $pull: { fcmTokens: { $in: invalidTokens } },
      });
    }

    logger.info(`Notification sent to user ${userId}: ${title}`);
    return response;
  } catch (err) {
    logger.error('Push notification error:', err);
  }
};

// ─── Broadcast to all users ───────────────────────────────────────────────────
exports.sendBroadcastNotification = async ({ title, body, data = {}, roles } = {}) => {
  try {
    const filter = roles ? { role: { $in: roles }, isActive: true } : { isActive: true };
    const users = await User.find(filter).select('fcmTokens');

    const allTokens = [...new Set(users.flatMap((u) => u.fcmTokens || []).filter(Boolean))];
    if (!allTokens.length) return;

    // FCM allows max 500 tokens per multicast
    const chunkSize = 500;
    for (let i = 0; i < allTokens.length; i += chunkSize) {
      const chunk = allTokens.slice(i, i + chunkSize);
      await admin.messaging().sendEachForMulticast({
        notification: { title, body },
        data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        android: { priority: 'high' },
        tokens: chunk,
      });
    }

    logger.info(`Broadcast notification sent: ${title} to ${allTokens.length} devices`);
  } catch (err) {
    logger.error('Broadcast notification error:', err);
  }
};
