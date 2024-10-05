import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/Business_Logic/Models/message_model.dart';
import 'package:spotify_project/Business_Logic/chat_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/business/active_status_updater.dart';
import 'package:spotify_project/screens/message_box.dart';
import 'package:spotify_project/screens/profile_screen.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String userIDOfOtherUser;
  final String profileURL;
  final String name;

  ChatScreen(this.userIDOfOtherUser, this.profileURL, this.name);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with ActiveStatusUpdater {
  final ScrollController _scrollController = ScrollController();
  final ChatDatabaseService _chatDBService = ChatDatabaseService();
  final TextEditingController _textController = TextEditingController();
  String? messageText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF191414),
      appBar: AppBar(
        backgroundColor: Color(0xFF1DB954),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.push(context,
              CupertinoPageRoute(builder: (context) => MessageScreen())),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(CupertinoPageRoute(
              builder: (context) =>
                  ProfileScreen(uid: widget.userIDOfOtherUser),
            ));
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20.sp,
                backgroundImage: NetworkImage(widget.profileURL),
              ),
              SizedBox(width: 12.w),
              Text(
                widget.name,
                style:
                    GoogleFonts.poppins(fontSize: 18.sp, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chatDBService.getMessagesFromStream(
                    currentUser!.uid, widget.userIDOfOtherUser),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1DB954)));
                  List<Message> allMessages = snapshot.data!;
                  return ListView.builder(
                    controller: _scrollController,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) =>
                        _messageBubble(allMessages[index]),
                  );
                },
              ),
            ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Color(0xFF404040),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
              onChanged: (value) {
                setState(() {
                  messageText = value;
                });
              },
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1DB954),
              ),
              child: Icon(Icons.send, color: Colors.white, size: 24.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_textController.text.trim().isNotEmpty) {
      Message messageToSaveAndSend = Message(
        fromWhom: currentUser!.uid,
        date: FieldValue.serverTimestamp(),
        isSentByMe: true,
        message: _textController.text,
        toWhom: widget.userIDOfOtherUser,
      );
      _chatDBService.sendMessage(messageToSaveAndSend);
      _textController.clear();
      setState(() {
        messageText = null;
      });
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _messageBubble(Message message) {
    final isSentByMe = message.isSentByMe!;
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSentByMe) SizedBox(width: 0.02.sw),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 0.9.sw),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: isSentByMe ? Color(0xFF1DB954) : Color(0xFF404040),
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.message!,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 18.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _formatTime(message.date),
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isSentByMe) SizedBox(width: 0.02.sw),
        ],
      ),
    );
  }

  String _formatTime(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      return DateFormat.Hm().format(date.toDate());
    }
    return '';
  }
}
