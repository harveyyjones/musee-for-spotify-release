const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

exports.sendChatNotification = onDocumentCreated(
  "message_notifications/{notificationId}",
  async (event) => {
    try {
      const notification = event.data.data();
      logger.info("Processing notification", notification);

      const recipientDoc = await db
        .collection("users")
        .doc(notification.recipientId)
        .get();
      
      const recipientToken = recipientDoc.data()?.fcmToken;
      if (!recipientToken) {
        logger.warn("No FCM token found for recipient");
        return null;
      }

      const senderDoc = await db
        .collection("users")
        .doc(notification.senderId)
        .get();
      
      const senderName = senderDoc.data()?.name || "Someone";

      const message = {
        token: recipientToken,
        notification: {
          title: `New message from ${senderName}`,
          body: notification.message || "New message received"
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            priority: "high"
          }
        }
      };

      await getMessaging().send(message);
      await event.data.ref.delete();
      return null;
    } catch (error) {
      logger.error("Error sending notification", error);
      return null;
    }
  }
);