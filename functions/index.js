const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();

/**
 * Get FCM tokens for a user.
 */
async function getUserFcmTokens(userId) {
  try {
    const snapshot = await db
      .collection('users')
      .doc(userId)
      .collection('fcmTokens')
      .get();

    if (snapshot.empty) {
      return [];
    }

    return snapshot.docs
      .map(doc => doc.data().token || doc.id)
      .filter(token => typeof token === 'string' && token.trim().length > 0);
  } catch (error) {
    console.error(`Error getting FCM tokens for user ${userId}:`, error);
    return [];
  }
}

/**
 * Helper to send OneSignal notification via REST API.
 */
/**
 * Daily aggregation function - runs at 23:59 every day
 * Aggregates daily usage from Realtime DB to Firestore
 */
exports.dailyAggregation = functions.pubsub
  .schedule('59 23 * * *')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    console.log('Starting daily aggregation...');
    
    try {
      // Get all users
      const usersSnapshot = await db.collection('users').get();
      
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        console.log(`Processing user: ${userId}`);
        
        // Get today's usage from Realtime DB
        const todayUsageRef = rtdb.ref(`users/${userId}/todayUsage`);
        const todayUsageSnapshot = await todayUsageRef.once('value');
        
        if (!todayUsageSnapshot.exists()) {
          console.log(`No usage data for user ${userId}`);
          continue;
        }
        
        const todayUsage = todayUsageSnapshot.val();
        const today = new Date();
        const dateKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
        
        // Get current rate
        const rateDoc = await db.collection('admin').doc('current_rate').get();
        const currentRate = rateDoc.exists ? rateDoc.data().rate_per_kwh : 12.50;
        
        // Calculate total cost
        const totalCost = (todayUsage.totalKwh || 0) * currentRate;
        
        // Save to Firestore daily trends
        await db.collection('users').doc(userId)
          .collection('energy_trends').doc('daily')
          .collection('data').doc(dateKey).set({
            totalKwh: todayUsage.totalKwh || 0,
            totalCost: totalCost,
            totalUsageTime: todayUsage.totalUsageTime || 0,
            date: dateKey,
            timestamp: admin.firestore.Timestamp.fromDate(today),
            rate: currentRate,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        
        // Update weekly aggregation
        await updateWeeklyAggregation(userId, today);
        
        // Update monthly aggregation
        await updateMonthlyAggregation(userId, today);
        
        // Reset today's usage for next day
        await todayUsageRef.set({
          totalKwh: 0.0,
          totalCost: 0.0,
          totalUsageTime: 0,
          date: dateKey,
          lastUpdated: today.toISOString(),
        });
        
        console.log(`Daily aggregation completed for user ${userId}`);
      }
      
      console.log('Daily aggregation completed successfully');
      return null;
    } catch (error) {
      console.error('Error in daily aggregation:', error);
      throw error;
    }
  });

/**
 * Weekly aggregation function
 */
async function updateWeeklyAggregation(userId, date) {
  const startOfWeek = new Date(date);
  startOfWeek.setDate(date.getDate() - date.getDay() + 1); // Monday
  startOfWeek.setHours(0, 0, 0, 0);
  
  const endOfWeek = new Date(startOfWeek);
  endOfWeek.setDate(startOfWeek.getDate() + 6); // Sunday
  endOfWeek.setHours(23, 59, 59, 999);
  
  const weekKey = `${startOfWeek.getFullYear()}-W${String(Math.ceil((startOfWeek - new Date(startOfWeek.getFullYear(), 0, 1)) / (7 * 24 * 60 * 60 * 1000))).padStart(2, '0')}`;
  
  // Get all daily data for this week
  const dailyQuery = await db.collection('users').doc(userId)
    .collection('energy_trends').doc('daily')
    .collection('data')
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startOfWeek))
    .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endOfWeek))
    .get();
  
  let totalKwh = 0;
  let totalCost = 0;
  let totalUsageTime = 0;
  
  dailyQuery.docs.forEach(doc => {
    const data = doc.data();
    totalKwh += data.totalKwh || 0;
    totalCost += data.totalCost || 0;
    totalUsageTime += data.totalUsageTime || 0;
  });
  
  // Save weekly aggregation
  await db.collection('users').doc(userId)
    .collection('energy_trends').doc('weekly')
    .collection('data').doc(weekKey).set({
      totalKwh: totalKwh,
      totalCost: totalCost,
      totalUsageTime: totalUsageTime,
      week: weekKey,
      startDate: startOfWeek.toISOString().split('T')[0],
      endDate: endOfWeek.toISOString().split('T')[0],
      timestamp: admin.firestore.Timestamp.fromDate(date),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * Monthly aggregation function
 */
async function updateMonthlyAggregation(userId, date) {
  const startOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
  const endOfMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0);
  
  const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
  
  // Get all daily data for this month
  const dailyQuery = await db.collection('users').doc(userId)
    .collection('energy_trends').doc('daily')
    .collection('data')
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startOfMonth))
    .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endOfMonth))
    .get();
  
  let totalKwh = 0;
  let totalCost = 0;
  let totalUsageTime = 0;
  
  dailyQuery.docs.forEach(doc => {
    const data = doc.data();
    totalKwh += data.totalKwh || 0;
    totalCost += data.totalCost || 0;
    totalUsageTime += data.totalUsageTime || 0;
  });
  
  // Save monthly aggregation
  await db.collection('users').doc(userId)
    .collection('energy_trends').doc('monthly')
    .collection('data').doc(monthKey).set({
      totalKwh: totalKwh,
      totalCost: totalCost,
      totalUsageTime: totalUsageTime,
      month: monthKey,
      startDate: startOfMonth.toISOString().split('T')[0],
      endDate: endOfMonth.toISOString().split('T')[0],
      timestamp: admin.firestore.Timestamp.fromDate(date),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * Threshold notification function
 * Triggers when usage exceeds 80% of target
 */
exports.thresholdNotification = functions.firestore
  .document('users/{userId}/energy_trends/daily/data/{date}')
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const data = snap.data();
    
    try {
      // Get user's energy target
      const targetDoc = await db.collection('users').doc(userId)
        .collection('energyTarget').doc('currentTarget').get();
      
      if (!targetDoc.exists) {
        console.log(`No energy target found for user ${userId}`);
        return null;
      }
      
      const target = targetDoc.data();
      const threshold = target.alert_threshold || 80;
      const thresholdValue = target.target_cost * (threshold / 100);
      
      // Check if threshold is exceeded
      if (data.totalCost >= thresholdValue) {
        // Check if notification was already sent today
        const today = new Date().toISOString().split('T')[0];
        const notificationKey = `threshold_${today}`;
        const notificationDoc = await db.collection('users').doc(userId)
          .collection('notifications').doc(notificationKey).get();
        
        if (notificationDoc.exists) {
          console.log(`Threshold notification already sent for user ${userId} today`);
          return null;
        }
        
        // Calculate percentage
        const percentage = Math.round((data.totalCost / target.target_cost) * 100);
        const tokens = await getUserFcmTokens(userId);

        if (tokens.length === 0) {
          console.log(`No FCM tokens registered for user ${userId}`);
          return null;
        }

        const nowIso = new Date().toISOString();

        const message = {
          tokens,
          data: {
            type: 'threshold_reached',
            current_cost: data.totalCost.toFixed(2),
            target_cost: target.target_cost.toFixed(2),
            threshold: threshold.toString(),
            percentage: percentage.toString(),
            timestamp: nowIso,
          },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'threshold_alerts',
              sound: 'default',
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: {
                sound: 'default',
                category: 'threshold_alerts',
                'content-available': 1,
              },
            },
          },
          notification: {
            title: 'Energy Alert!',
            body: `You've reached ${percentage}% of your daily energy target (₱${data.totalCost.toFixed(2)})`,
          },
        };

        const thresholdResponse =
          await admin.messaging().sendEachForMulticast(message);
        console.log(
          `Threshold FCM notification dispatched for user ${userId}: success=${thresholdResponse.successCount}, failure=${thresholdResponse.failureCount}`,
        );
        
        // Mark notification as sent
        await db.collection('users').doc(userId)
          .collection('notifications').doc(notificationKey).set({
            sent: true,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            type: 'threshold_reached',
            currentCost: data.totalCost,
            targetCost: target.target_cost,
            threshold: threshold,
          });
        
        // Add to recent activity
        await db.collection('users').doc(userId)
          .collection('recent_activity').add({
            type: 'threshold_reached',
            message: `Energy usage reached ${Math.round((data.totalCost / target.target_cost) * 100)}% of target`,
            meta: {
              currentCost: data.totalCost,
              targetCost: target.target_cost,
              threshold: threshold,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            userId: userId,
          });
        
        console.log(`Threshold notification sent to user ${userId}`);
      }
      
      return null;
    } catch (error) {
      console.error('Error in threshold notification:', error);
      throw error;
    }
  });

/**
 * Budget alert notification function
 * Triggers when a budget alert document is created in budget_alerts collection
 */
exports.budgetAlertNotification = functions.firestore
  .document('users/{userId}/budget_alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const alertId = context.params.alertId;
    const alertData = snap.data();

    try {
      const budgetId = alertData.budgetId || 'current';

      const budgetDoc = await db
        .collection('users')
        .doc(userId)
        .collection('budget_target')
        .doc(budgetId)
        .get();

      if (!budgetDoc.exists) {
        console.log(`No budget target found for user ${userId}`);
        await snap.ref.update({
          sent: false,
          error: 'missing_budget_target',
        });
        return null;
      }

      const prefs = budgetDoc.data();
      if (prefs.alertEnabled === false) {
        console.log(
          `Alerts disabled for user ${userId}, budget ${budgetId}. Skipping.`,
        );
        await snap.ref.update({
          sent: false,
          skipped: 'alerts_disabled',
        });
        return null;
      }

      const now = new Date();
      const snoozedUntil = prefs.snoozedUntil
        ? prefs.snoozedUntil.toDate()
        : null;
      if (snoozedUntil && snoozedUntil > now) {
        console.log(
          `Alert snoozed for user ${userId} until ${snoozedUntil.toISOString()}`,
        );
        await snap.ref.update({
          sent: false,
          skipped: 'snoozed',
        });
        return null;
      }

      const lastDismissedAt = prefs.lastAlertDismissedAt
        ? prefs.lastAlertDismissedAt.toDate()
        : null;
      if (
        lastDismissedAt &&
        lastDismissedAt.getTime() >= snap.createTime.toDate().getTime()
      ) {
        console.log(
          `Alert ${alertId} was created before dismissal (${lastDismissedAt.toISOString()})`,
        );
        await snap.ref.update({
          sent: false,
          skipped: 'dismissed',
        });
        return null;
      }

      const lastAlertSentAt = prefs.lastAlertSentAt
        ? prefs.lastAlertSentAt.toDate()
        : null;
      if (lastAlertSentAt) {
        const minutesSinceLast =
          (now.getTime() - lastAlertSentAt.getTime()) / 60000;
        if (minutesSinceLast < 5) {
          console.log(
            `Alert throttled for user ${userId} – last alert ${minutesSinceLast.toFixed(
              1,
            )} minutes ago`,
          );
          await snap.ref.update({
            sent: false,
            skipped: 'throttled',
          });
          return null;
        }
      }

      const tokens = await getUserFcmTokens(userId);
      if (tokens.length === 0) {
        console.log(`No FCM tokens registered for user ${userId}`);
        await snap.ref.update({
          sent: false,
          skipped: 'no_tokens',
        });
        return null;
      }

      const consumedCost = Number(alertData.consumedCost || 0);
      const remainingBudget = Number(alertData.remainingBudget || 0);
      const totalBudget = Number(alertData.totalBudget || 0);
      const thresholdPercentage =
        Number(alertData.thresholdPercentage || alertData.usedPercentage || 0);
      const alertType = alertData.alertType || 'threshold';
      const budgetName = alertData.budgetName || 'Budget Target';
      const percentage =
        alertType === 'total_budget'
          ? 100
          : Math.round(
              Number(alertData.usedPercentage || thresholdPercentage),
            );

      const title =
        alertType === 'total_budget' ? 'Total Budget Reached!' : 'Budget Alert!';
      const body = `You've reached ₱${consumedCost.toFixed(
        2,
      )} of ₱${totalBudget.toFixed(2)} (${percentage}%).`;

      const message = {
        tokens,
        data: {
          type: 'budget_alert',
          alert_type: alertType,
          budget_id: budgetId,
          budget_name: budgetName,
          alert_id: alertId,
          current_amount: consumedCost.toFixed(2),
          budget_total: totalBudget.toFixed(2),
          remaining_budget: remainingBudget.toFixed(2),
          threshold_percentage: thresholdPercentage.toString(),
          timestamp: now.toISOString(),
        },
        android: {
          priority: 'high',
          notification: {
            channel_id: 'energy_alerts',
            sound: 'default',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: {
            aps: {
              sound: 'default',
              category: 'BUDGET_ALERT',
              'content-available': 1,
            },
          },
        },
        notification: {
          title: `${title} • ${budgetName}`,
          body,
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `Budget alert FCM dispatched for user ${userId}: success=${response.successCount}, failure=${response.failureCount}`,
      );

      await snap.ref.update({
        sent: true,
        deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      await db
        .collection('users')
        .doc(userId)
        .collection('budget_target')
        .doc(budgetId)
        .set(
          {
            lastAlertSentAt: admin.firestore.FieldValue.serverTimestamp(),
            lastAlertSentType: alertType,
          },
          { merge: true },
        );

      await db
        .collection('users')
        .doc(userId)
        .collection('recent_activity')
        .add({
          type: 'budget_alert',
          message: `${title} (${percentage}%)`,
          meta: {
            consumedCost,
            remainingBudget,
            totalBudget,
            thresholdPercentage,
            alertType,
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          userId,
        });

      return null;
    } catch (error) {
      console.error('Error in budget alert notification:', error);
      await snap.ref.update({
        sent: false,
        error: error.message,
      });
      return null;
    }
  });

exports.testBudgetAlert = functions.https.onRequest(async (req, res) => {
  try {
    const { userId, budgetId = 'current', alertType = 'threshold' } = req.body;
    if (!userId) {
      res.status(400).send('Missing userId');
      return;
    }

    const tokens = await getUserFcmTokens(userId);
    if (tokens.length === 0) {
      res.status(400).send('No FCM tokens registered for this user');
      return;
    }

    const message = {
      tokens,
      data: {
        type: 'budget_alert',
        alert_type: alertType,
        budget_id: budgetId,
        budget_name: 'Test Budget',
        alert_id: `test_${Date.now()}`,
        current_amount: '850.50',
        budget_total: '1000.00',
        remaining_budget: '149.50',
        threshold_percentage: alertType === 'total_budget' ? '100' : '85',
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: 'energy_alerts',
          sound: 'default',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: {
          aps: {
            sound: 'default',
            category: 'BUDGET_ALERT',
          },
        },
      },
      notification: {
        title:
          alertType === 'total_budget'
            ? 'Total Budget Reached!'
            : 'Budget Alert!',
        body: 'Test budget alert notification.',
      },
    };

    await admin.messaging().sendEachForMulticast(message);
    res.status(200).send('Test alert dispatched');
  } catch (error) {
    console.error('Error sending test alert:', error);
    res.status(500).send(error.message);
  }
});

/**
 * Monthly reset function - runs on the 1st of every month
 * Resets all appliance usage data
 */
exports.monthlyReset = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    console.log('Starting monthly reset...');
    
    try {
      // Get all users
      const usersSnapshot = await db.collection('users').get();
      
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        console.log(`Resetting usage for user: ${userId}`);
        
        // Reset all appliances
        const appliancesRef = rtdb.ref(`users/${userId}/appliances`);
        const appliancesSnapshot = await appliancesRef.once('value');
        
        if (appliancesSnapshot.exists()) {
          const appliances = appliancesSnapshot.val();
          const updates = {};
          
          Object.keys(appliances).forEach(applianceId => {
            updates[`${applianceId}/totalUsageTime`] = 0;
            updates[`${applianceId}/kwh`] = 0.0;
            updates[`${applianceId}/isOn`] = false;
            updates[`${applianceId}/startTime`] = null;
            updates[`${applianceId}/lastUpdated`] = new Date().toISOString();
          });
          
          await appliancesRef.update(updates);
        }
        
        // Reset today's usage
        await rtdb.ref(`users/${userId}/todayUsage`).set({
          totalKwh: 0.0,
          totalCost: 0.0,
          totalUsageTime: 0,
          date: new Date().toISOString().split('T')[0],
          lastUpdated: new Date().toISOString(),
        });
        
        console.log(`Monthly reset completed for user ${userId}`);
      }
      
      console.log('Monthly reset completed successfully');
      return null;
    } catch (error) {
      console.error('Error in monthly reset:', error);
      throw error;
    }
  });

/**
 * Rate update notification function
 * Triggers when admin updates the current rate
 */
exports.rateUpdateNotification = functions.firestore
  .document('admin/current_rate')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if rate actually changed
    if (before.rate_per_kwh === after.rate_per_kwh) {
      return null;
    }
    
    console.log(`Rate updated from ${before.rate_per_kwh} to ${after.rate_per_kwh}`);
    
    try {
      // Get all users
      const usersSnapshot = await db.collection('users').get();

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const tokens = await getUserFcmTokens(userId);

        if (tokens.length === 0) {
          console.log(`No FCM tokens registered for user ${userId}`);
          continue;
        }

        const message = {
          tokens,
          data: {
            type: 'rate_update',
            old_rate: before.rate_per_kwh.toString(),
            new_rate: after.rate_per_kwh.toString(),
            timestamp: new Date().toISOString(),
          },
          android: {
            priority: 'high',
            notification: {
              channel_id: 'appliance_status',
              sound: 'default',
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
          notification: {
            title: 'Rate Update',
            body: `Power rate updated to ₱${after.rate_per_kwh}/kWh`,
          },
        };

        const response = await admin
          .messaging()
          .sendEachForMulticast(message);
        console.log(
          `Rate update FCM notification for user ${userId}: success=${response.successCount}, failure=${response.failureCount}`,
        );

        // Add to recent activity
        await db.collection('users').doc(userId)
          .collection('recent_activity').add({
            type: 'rate_update',
            message: `Power rate updated to ₱${after.rate_per_kwh}/kWh`,
            meta: {
              oldRate: before.rate_per_kwh,
              newRate: after.rate_per_kwh,
              updatedBy: after.updated_by,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            userId: userId,
          });
      }

      console.log('Rate update notifications sent to all users');
      return null;
    } catch (error) {
      console.error('Error in rate update notification:', error);
      throw error;
    }
  });

/**
 * Chat notification function
 * Triggers when a new message is created in a chat
 */
exports.sendChatNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const chatId = context.params.chatId;
    const messageId = context.params.messageId;
    const messageData = snap.data();

    try {
      const senderId = messageData.senderId;
      console.log(
        `Chat message ${messageId} created in chat ${chatId} by ${senderId}. Local notifications handled on device.`,
      );
      return null;
    } catch (error) {
      console.error('Error in chat notification trigger:', error);
      throw error;
    }
  });
