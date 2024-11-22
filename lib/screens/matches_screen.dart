import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/business/active_status_updater.dart';
import 'package:spotify_project/main.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/widgets/bottom_bar.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:spotify_project/screens/chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({Key? key}) : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen>
    with ActiveStatusUpdater {
  final FirestoreDatabaseService _firestoreDatabaseService =
      FirestoreDatabaseService();
  String? _errorMessage;
  bool _isLoading = true;
  List<dynamic>? _matchData;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    try {
      String currentlyListeningMusicName = await _getCurrentlyListeningMusic();
      bool isSpotifyActive = await _checkSpotifyStatus();

      await _firestoreDatabaseService.getUserDatasToMatch(
        currentlyListeningMusicName,
        isSpotifyActive,
      );

      _matchData = await _firestoreDatabaseService.getUserDataViaUId();

      // Add this line to update the active status
      _firestoreDatabaseService.updateActiveStatus();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error initializing user data: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getCurrentlyListeningMusic() async {
    try {
      bool isSpotifyActive = await SpotifySdk.isSpotifyAppActive;
      if (!isSpotifyActive) {
        return '';
      }

      String? musicName =
          await _firestoreDatabaseService.returnCurrentlyListeningMusicName();
      return musicName ?? '';
    } catch (e) {
      print("Error getting currently listening music: $e");
      return '';
    }
  }

  Future<bool> _checkSpotifyStatus() async {
    try {
      return await SpotifySdk.isSpotifyAppActive;
    } catch (e) {
      print("Error checking Spotify active status: $e");
      return false;
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Text(
        _errorMessage ?? "An unknown error occurred",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.red),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.black),
    );
  }

  Widget _buildNoDataWidget(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMatchesWidget() {
    if (_matchData == null || _matchData!.isEmpty) {
      return _buildNoDataWidget(
          "No matches found. Try listening to some music!");
    }

    if (_matchData!.length == 1 && _matchData![0].userId == currentUser?.uid) {
      return _buildNoDataWidget(
          "There is no match yet, listen to some music or use quick match!");
    }

    return Container(
      color: Color(0xFF2A2A2A), // Slightly lighter dark color for contrast
      child: SwipeCardWidget(snapshotData: _matchData!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E), // Dark background color
      bottomNavigationBar: BottomBar(selectedIndex: 1),
      body: _isLoading
          ? _buildLoadingWidget()
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildMatchesWidget(),
    );
  }
}

class SwipeCardWidget extends StatefulWidget {
  final List<dynamic> snapshotData;

  const SwipeCardWidget({Key? key, required this.snapshotData})
      : super(key: key);

  @override
  _SwipeCardWidgetState createState() => _SwipeCardWidgetState();
}

class _SwipeCardWidgetState extends State<SwipeCardWidget> {
  List<SwipeItem> _swipeItems = <SwipeItem>[];
  MatchEngine? _matchEngine;
  final FirestoreDatabaseService _firestoreDatabaseService =
      FirestoreDatabaseService();

  @override
  void initState() {
    super.initState();
    _swipeItems = widget.snapshotData.map((userData) {
      return SwipeItem(
        content: userData,
        likeAction: () {
          _firestoreDatabaseService.updateIsLiked(true, userData.userId);
          Navigator.of(context).push(CupertinoPageRoute(
            builder: (context) => ChatScreen(
              userData.userId,
              userData.profilePhotos.isNotEmpty
                  ? userData.profilePhotos[0]
                  : "",
              userData.name,
            ),
          ));
        },
        nopeAction: () {
          _firestoreDatabaseService.updateIsLiked(false, userData.userId);
        },
      );
    }).toList();

    _matchEngine = MatchEngine(swipeItems: _swipeItems);
  }

  @override
  Widget build(BuildContext context) {
    return SwipeCards(
      matchEngine: _matchEngine!,
      itemBuilder: (BuildContext context, int index) {
        return UserProfileCard(
          userData: widget.snapshotData[index],
          onLike: () => _matchEngine!.currentItem?.like(),
          onNope: () => _matchEngine!.currentItem?.nope(),
        );
      },
      onStackFinished: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No more matches!")),
        );
      },
      itemChanged: (SwipeItem item, int index) {},
      upSwipeAllowed: false,
      fillSpace: true,
    );
  }
}

class UserProfileCard extends StatefulWidget {
  final dynamic userData;
  final VoidCallback onLike;
  final VoidCallback onNope;

  const UserProfileCard({
    Key? key,
    required this.userData,
    required this.onLike,
    required this.onNope,
  }) : super(key: key);

  @override
  _UserProfileCardState createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextImage() {
    if (_currentPage < widget.userData.profilePhotos.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> profilePhotos = widget.userData.profilePhotos;

    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: profilePhotos.isEmpty ? 1 : profilePhotos.length,
              itemBuilder: (context, index) {
                return profilePhotos.isEmpty
                    ? Container(
                        color: Colors.black,
                        child: const Icon(Icons.person,
                            size: 100, color: Colors.grey),
                      )
                    : Image.network(
                        profilePhotos[index],
                        fit: BoxFit.cover,
                      );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _previousImage,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: const Color.fromARGB(0, 0, 0, 0)),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _nextImage,
                  behavior: HitTestBehavior.translucent,
                  child: Container(color: const Color.fromARGB(0, 0, 0, 0)),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 50.w),
                    child: Text(
                      widget.userData.name ?? 'No Name',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 110.h),
                  SizedBox(height: 8),
                  Text(
                    widget.userData.biography ?? 'No biography available',
                    style: TextStyle(fontSize: 14, color: Colors.white60),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (profilePhotos.length > 1)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  profilePhotos.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.grey.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 35.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(Icons.close, Colors.red, widget.onNope),
                SizedBox(width: 100.w), // Added space between buttons
                _buildActionButton(Icons.favorite, Colors.green, widget.onLike),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130.w, // Increased button size
        height: 130.w, // Increased button size
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromARGB(255, 219, 219, 219),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 60.sp, // Increased icon size
        ),
      ),
    );
  }
}
