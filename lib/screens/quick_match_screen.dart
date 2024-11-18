import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:spotify_project/Business_Logic/Models/user_model.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/screens/chat_screen.dart';
import 'package:spotify_project/widgets/swipe_cards_for_quick_match.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class QuickMatchesScreen extends StatefulWidget {
  const QuickMatchesScreen({Key? key}) : super(key: key);

  @override
  State<QuickMatchesScreen> createState() => _QuickMatchesScreenState();
}

class _QuickMatchesScreenState extends State<QuickMatchesScreen> {
  final FirestoreDatabaseService _firestoreDatabaseService =
      FirestoreDatabaseService();
  Future<List<UserModel>>? _dataFuture;
  late String _filterType;

  @override
  void initState() {
    _filterType = "show the swiped again later";
    super.initState();
    print("QuickMatchesScreen initState called");
    _firestoreDatabaseService.updateActiveStatus();
    _dataFuture = _loadData(_filterType);
  }

  Future<List<UserModel>> _loadData(String filterType) async {
    print("_loadData started");
    try {
      // String currentlyListeningMusicName =
      //     await _firestoreDatabaseService.returnCurrentlyListeningMusicName();
      // print("Current music: $currentlyListeningMusicName");

      // bool isSpotifyActive = await SpotifySdk.isSpotifyAppActive;
      // print("Spotify active: $isSpotifyActive");

      // await _firestoreDatabaseService.getUserDatasToMatch(
      //   currentlyListeningMusicName,
      //   isSpotifyActive,
      // );
      // print("getUserDatasToMatch completed");

      List<UserModel> users = await _firestoreDatabaseService.getAllUsersData(
          filterType: filterType);
      print("getAllUsersData completed. User count: ${users.length}");
      return users;
    } catch (e) {
      print('Error in _loadData: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    print("QuickMatchesScreen build method called");
    return Scaffold(
      backgroundColor: const Color.fromARGB(
          251, 0, 0, 0), // Add this line to set a dark background
      body: FutureBuilder<List<UserModel>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          print("FutureBuilder state: ${snapshot.connectionState}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print("FutureBuilder error: ${snapshot.error}");
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            print("No data available");
            return const Center(child: Text('No data available'));
          } else {
            final users = snapshot.data!;
            print("Data available. User count: ${users.length}");
            return Container(
              child: users.isEmpty
                  ? const Center(
                      child: Text('No users found',
                          style: TextStyle(
                              color: Color.fromARGB(
                                  255, 24, 24, 24)))) // Add text style
                  : SwipeCardWidgetForQuickMatch(
                      snapshotData: users,
                    ),
            );
          }
        },
      ),
    );
  }
}
