import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_10_track_model.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_artists_of_the_user.dart';
import 'package:spotify_project/business/active_status_updater.dart';
import 'package:spotify_project/screens/chat_screen.dart';
import 'package:spotify_project/screens/profile_settings.dart';
import 'package:spotify_project/screens/register_page.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;

  ProfileScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with ActiveStatusUpdater {
  ScrollController _scrollController = ScrollController();

  String get text => "Message";
  FirestoreDatabaseService _serviceForSnapshot = FirestoreDatabaseService();

  late Future<Map<String, dynamic>> _combinedFuture;
  int _currentImageIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _combinedFuture = _loadAllData();
    _pageController = PageController();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final userData =
          await _serviceForSnapshot.getUserDataForDetailPage(widget.uid);
      final topArtists =
          await _serviceForSnapshot.getTopArtistsFromFirebase(widget.uid);
      final topTracks =
          await _serviceForSnapshot.getTopTracksFromFirebase(widget.uid);

      return {
        'userData': userData,
        'topArtists': topArtists ?? [], // Use an empty list if null
        'topTracks': topTracks ?? [], // Use an empty list if null
      };
    } catch (e) {
      print('Error loading data: $e');
      return {}; // Return an empty map in case of error
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _combinedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1DB954))),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.white))),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: Text('No data available',
                    style: TextStyle(color: Colors.white))),
          );
        }

        final data = snapshot.data!;
        final userData = data['userData'];
        final topArtists = data['topArtists'] as List<dynamic>?;
        final topTracks = data['topTracks'] as List<dynamic>?;
        final genres = _prepareGenres(topArtists);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildUserProfile(userData)),
                  SliverToBoxAdapter(child: _buildGenresWidget(genres)),
                  if (topArtists != null && topArtists.isNotEmpty)
                    SliverToBoxAdapter(child: _buildTopArtists(topArtists)),
                  SliverToBoxAdapter(
                      child: Divider(
                          thickness: 1, color: Colors.white.withOpacity(0.5))),
                  if (topTracks != null && topTracks.isNotEmpty)
                    SliverToBoxAdapter(child: _buildTopTracks(topTracks)),
                ],
              ),
              Positioned(
                top: 40,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopArtists(List<dynamic> artists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Top Artists',
            style: TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: artists.length > 5 ? 5 : artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index] as Map<String, dynamic>;
              return Container(
                width: 120,
                margin: EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFF1DB954), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1DB954).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          artist['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.person, color: Color(0xFF1DB954)),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      artist['name'] ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenresWidget(List<String> genres) {
    if (genres.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Music Interests',
            style: TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genres.map((genre) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF1DB954).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF1DB954)),
                ),
                child: Text(
                  genre,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTracks(List<dynamic> tracks) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Color(0xFF1DB954).withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              'Top Tracks',
              style: TextStyle(
                color: Color(0xFF1DB954),
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: tracks.length > 5 ? 5 : tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index] as Map<String, dynamic>;
              return ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.network(
                    track['album']?['images']?[0]?['url'] ?? '',
                    width: 60.w,
                    height: 60.w,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60.w,
                      height: 60.w,
                      color: Color(0xFF1DB954).withOpacity(0.2),
                      child: Icon(Icons.music_note, color: Color(0xFF1DB954)),
                    ),
                  ),
                ),
                title: Text(
                  track['name'] ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  (track['artists'] as List<dynamic>?)
                          ?.map((artist) => artist['name'])
                          .join(', ') ??
                      '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14.sp,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(dynamic userData) {
    List<String> profilePhotos = userData.profilePhotos ?? [];
    String defaultImage =
        "https://static.vecteezy.com/system/resources/previews/009/734/564/non_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg";

    if (profilePhotos.isEmpty) {
      profilePhotos = [defaultImage];
    }

    void _nextImage() {
      print("Next image tapped");
      if (_currentImageIndex < profilePhotos.length - 1) {
        setState(() {
          _currentImageIndex++;
          _pageController.animateToPage(
            _currentImageIndex,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    }

    void _previousImage() {
      print("Previous image tapped");
      if (_currentImageIndex > 0) {
        setState(() {
          _currentImageIndex--;
          _pageController.animateToPage(
            _currentImageIndex,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    }

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.8,
          child: PageView.builder(
            controller: _pageController,
            itemCount: profilePhotos.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                profilePhotos[index],
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.yellow,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.error, color: Colors.yellow),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _previousImage,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _nextImage,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 40,
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
                  color: _currentImageIndex == index
                      ? Color(0xFF1ED760)
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userData.name ?? currentUser?.displayName ?? 'No Name',
                style: GoogleFonts.poppins(
                  fontSize: 45.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                userData.majorInfo ?? "No major info",
                style: TextStyle(
                  fontSize: 18.sp,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              SizedBox(height: 8),
              Text(
                userData.biography ?? "No biography available.",
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChatScreen(
                                widget.uid,
                                userData.profilePhotos.isNotEmpty
                                    ? userData.profilePhotos[0]
                                    : defaultImage,
                                userData.name,
                              )));
                  print("Message button tapped");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1DB954),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _prepareGenres(List<dynamic>? topArtists) {
    if (topArtists == null) return [];

    Set<String> uniqueGenres = {};
    for (var artist in topArtists) {
      if (artist['genres'] != null) {
        uniqueGenres.addAll((artist['genres'] as List).cast<String>());
      }
    }

    return uniqueGenres.toList()..sort();
  }
}
