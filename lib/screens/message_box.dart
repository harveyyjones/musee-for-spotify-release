import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:spotify_project/Business_Logic/Models/conversations_in_message_box.dart';
import 'package:spotify_project/Business_Logic/Models/user_model.dart';
import 'package:spotify_project/Business_Logic/chat_services/chat_database_service.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/screens/chat_screen.dart';
import 'package:spotify_project/screens/profile_screen.dart';
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
      backgroundColor:
          const Color(0xFF121212), // Spotify's dark background color
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
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
          Container(
            height: 110.h,
            child: FutureBuilder<List<UserModel>>(
              future: firestoreDatabaseService.getLikedPeople(),
              builder: (context, snapshot) {
                var data = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1DB954)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No liked users yet',
                      style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                    ),
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    UserModel user = snapshot.data!.elementAt(index);
                    return Padding(
                      padding: EdgeInsets.only(right: 16.w),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(CupertinoPageRoute(
                                  builder: (context) => ChatScreen(user.userId!,
                                      user.profilePhotos.first, user.name!)));
                            },
                            child: CircleAvatar(
                              radius: 30.r,
                              backgroundImage: user.profilePhotos.isNotEmpty
                                  ? NetworkImage(user.profilePhotos[0])
                                  : null,
                              backgroundColor: const Color(0xFF1DB954),
                              child: user.profilePhotos.isEmpty
                                  ? const Icon(Icons.person,
                                      color: Colors.white)
                                  : null,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            user.name ?? 'Unknown',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Conversations>>(
              future: _chatDatabaseService.getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
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
                        return const SizedBox.shrink();
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
              ? const Color(0xFF121212)
              : const Color(0xFF282828),
          border: const Border(
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
              backgroundColor: const Color(0xFF1DB954),
              child: user.profilePhotos.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
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
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}
