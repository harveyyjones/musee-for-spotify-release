// // lib/services/notification_service.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:rxdart/subjects.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   final BehaviorSubject<String?> selectNotificationSubject =
//       BehaviorSubject<String?>();

//   Future<void> initialize() async {
//     const androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     final initializationSettings = const InitializationSettings(
//       android: androidSettings,
//     );

//     await flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse details) async {
//         selectNotificationSubject.add(details.payload);
//       },
//     );
//   }

//   Future<void> showNotification({
//     required String title,
//     required String body,
//     String? payload,
//   }) async {
//     AndroidNotificationDetails androidPlatformChannelSpecifics =
//         const AndroidNotificationDetails(
//       'chat_messages', // Channel ID
//       'Chat Messages', // Channel name
//       channelDescription: 'Notifications for new chat messages',
//       importance: Importance.max,
//       priority: Priority.high,
//       showWhen: true,
//     );

//     NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);

//     await flutterLocalNotificationsPlugin.show(
//       DateTime.now().millisecond,
//       title,
//       body,
//       platformChannelSpecifics,
//       payload: payload,
//     );
//   }

//   void dispose() {
//     selectNotificationSubject.close();
//   }

//   Future<void> sendTestNotification() async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser != null) {
//       await FirebaseFirestore.instance.collection('message_notifications').add({
//         'senderId': currentUser.uid,
//         'recipientId': currentUser.uid, // Sending to self for testing
//         'message': 'Test notification',
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//       print('Test notification document created');
//     }
//   }
// }
