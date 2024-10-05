import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:spotify_project/Business_Logic/Models/conversations_in_message_box.dart';
import 'package:spotify_project/Business_Logic/Models/user_model.dart';
import 'package:spotify_project/Business_Logic/chat_database_service.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/screens/chat_screen.dart';
import 'package:spotify_project/widgets/bottom_bar.dart';

class MessageScreen extends StatefulWidget {
  MessageScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  FirestoreDatabaseService firestoreDatabaseService =
      FirestoreDatabaseService();
  ChatDatabaseService _chatDatabaseService = ChatDatabaseService();
  ScaffoldMessengerState snackBar = ScaffoldMessengerState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Spotify's dark background color
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        automaticallyImplyLeading:
            false, // Add this line to remove the back arrow
        title: Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBar: BottomBar(selectedIndex: 3),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Conversations>>(
              future: _chatDatabaseService.getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1DB954)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) => FutureBuilder<UserModel?>(
                    future: _chatDatabaseService.getUserDataForMessageBox(
                        snapshot.data![index].receiverID),
                    builder: (context, snapshotForUserInfo) {
                      if (!snapshotForUserInfo.hasData) {
                        return SizedBox.shrink();
                      }
                      var data = snapshotForUserInfo.data!;
                      return _buildConversationTile(
                          data, snapshot.data![index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(UserModel user, Conversations conversation) {
    return InkWell(
      onTap: () {
        _chatDatabaseService.changeIsSeenStatus(conversation.receiverID);
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (context) => ChatScreen(
            user.userId.toString(),
            user.profilePhotos.isNotEmpty
                ? user.profilePhotos[0].toString()
                : '',
            user.name.toString(),
          ),
        ));
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: conversation.isSeen != null && conversation.isSeen
              ? Color(0xFF121212)
              : Color(0xFF282828),
          border: Border(
            bottom: BorderSide(color: Colors.white10, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30.r,
              backgroundImage: user.profilePhotos.isNotEmpty
                  ? NetworkImage(user.profilePhotos[0])
                  : null,
              backgroundColor: Color(0xFF1DB954),
              child: user.profilePhotos.isEmpty
                  ? Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    conversation.lastMessageSent ?? '',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}
