import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            backgroundColor: const Color(0xFF121212),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildErrorScreen('No data available');
        }

        final data = snapshot.data!;
        final userData = data['userData'];
        final topArtists = data['topArtists'] as List<dynamic>?;
        final topTracks = data['topTracks'] as List<dynamic>?;
        final genres = _prepareGenres(topArtists);

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(0),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
          ),
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1A1A),
                      Colors.black,
                      const Color(0xFF1A1A1A),
                    ],
                  ),
                ),
              ),
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: _buildSliverSections(
                    userData, genres, topArtists, topTracks),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSliverSections(
    dynamic userData,
    List<String> genres,
    List<dynamic>? topArtists,
    List<dynamic>? topTracks,
  ) {
    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Stack(
            children: [
              _buildProfileImages(userData),
              _buildGradientOverlay(),
              _buildProfileInfo(userData),
              _buildBackButton(),
              _buildImageIndicators(userData.profilePhotos?.length ?? 1),
            ],
          ),
        ),
      ),
      if (genres.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: _buildGenresWidget(genres),
          ),
        ),
      if (topArtists != null && topArtists.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: _buildTopArtists(topArtists),
          ),
        ),
      if (topTracks != null && topTracks.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 24.h),
            child: _buildTopTracks(topTracks),
          ),
        ),
      SliverPadding(padding: EdgeInsets.only(bottom: 24.h)),
    ];
  }

  Widget _buildGenresWidget(List<String> genres) {
    if (genres.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: _buildGradientTitle('Music Interests'),
        ),
        SizedBox(height: 16.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: genres.map((genre) => _buildGenreChip(genre)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        foreground: Paint()
          ..shader = LinearGradient(
            colors: const [
              Color(0xFF6366F1),
              Color(0xFF9333EA),
            ],
          ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
      ),
    );
  }

  Widget _buildTopArtists(List<dynamic> artists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: _buildGradientTitle('Top Artists'),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 180.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            itemCount: min(artists.length, 5),
            itemBuilder: (context, index) => _buildArtistItem(artists[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTracks(List<dynamic> tracks) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Color(0xFF6366F1).withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: _buildGradientTitle('Top Tracks'),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: min(tracks.length, 5),
            itemBuilder: (context, index) =>
                _buildTrackItem(tracks[index], index),
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
                  fontSize: 28.sp,
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

  Widget _buildProfileImages(dynamic userData) {
    List<String> profilePhotos = userData?.profilePhotos ?? [];
    String defaultImage =
        "https://static.vecteezy.com/system/resources/previews/009/734/564/non_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg";

    if (profilePhotos.isEmpty) {
      profilePhotos = [defaultImage];
    }

    return Stack(
      children: [
        // Main Image
        Container(
          height: MediaQuery.of(context).size.height *
              0.55, // Changed from 0.75 to 0.55
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            itemCount: profilePhotos.length,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) => Image.network(
              profilePhotos[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A1A),
                child: Icon(Icons.error, color: Color(0xFF6366F1), size: 40.sp),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: const Color(0xFF1A1A1A),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
            ),
          ),
        ),

        // Image Indicators
        if (profilePhotos.length > 1)
          Positioned(
            top: 40.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                profilePhotos.length,
                (index) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Color(0xFF6366F1)
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenreChip(String genre) {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 8.h,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1).withOpacity(0.1),
            Color(0xFF9333EA).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Color(0xFF6366F1).withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
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
  }

  Widget _buildArtistItem(Map<String, dynamic> artist) {
    return Container(
      width: 140.w,
      margin: EdgeInsets.only(right: 16.w),
      child: Column(
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1).withOpacity(0.2),
                  Color(0xFF9333EA).withOpacity(0.2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF6366F1).withOpacity(0.2),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                artist['imageUrl'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.person,
                    size: 40.sp,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            artist['name'] ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem(Map<String, dynamic> track, int index) {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 8.h,
        horizontal: 20.w,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1).withOpacity(0.1),
            Color(0xFF9333EA).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Color(0xFF6366F1).withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Image.network(
                  track['album']?['images']?[0]?['url'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Color(0xFF6366F1).withOpacity(0.2),
                    child: Icon(
                      Icons.music_note,
                      color: Color(0xFF6366F1),
                      size: 24.sp,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track['name'] ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    (track['artists'] as List<dynamic>?)
                            ?.map((artist) => artist['name'])
                            .join(', ') ??
                        '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6366F1).withOpacity(0.1),
              ),
              child: Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF6366F1),
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.2),
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(dynamic userData) {
    return Positioned(
      bottom: 20.h,
      left: 20.w,
      right: 20.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                userData?.name ?? 'No Name',
                style: GoogleFonts.poppins(
                  fontSize: 55.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              Text(
                userData?.age != null ? ' ${userData.age}' : '',
                style: GoogleFonts.poppins(
                  fontSize: 45.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (userData?.songName?.isNotEmpty == true) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF6366F1).withOpacity(0.2),
                    Color(0xFF9333EA).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Color(0xFF6366F1).withOpacity(0.5)),
              ),
              child: Text(
                userData.songName,
                style: TextStyle(
                  fontSize: 25.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
          if (userData?.biography?.isNotEmpty == true) ...[
            Text(
              userData.biography,
              style: TextStyle(
                fontSize: 33.sp,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20.h),
          ],
          _buildMessageButton(userData),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 40.h,
      left: 20.w,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20.sp),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildImageIndicators(int count) {
    return Positioned(
      top: 40.h,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentImageIndex == index
                  ? Color(0xFF6366F1)
                  : Colors.white.withOpacity(0.5),
              boxShadow: _currentImageIndex == index
                  ? [
                      BoxShadow(
                        color: Color(0xFF6366F1).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageButton(dynamic userData) {
    String defaultImage =
        "https://static.vecteezy.com/system/resources/previews/009/734/564/non_2x/default-avatar-profile-icon-of-social-media-user-vector.jpg";

    return Container(
      width: double.infinity,
      height: 50.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1),
            Color(0xFF9333EA),
          ],
        ),
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  widget.uid,
                  userData.profilePhotos?.isNotEmpty == true
                      ? userData.profilePhotos[0]
                      : defaultImage,
                  userData.name,
                ),
              ),
            );
          },
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.message_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Message',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64.sp,
              color: Color(0xFF6366F1),
            ),
            SizedBox(height: 16.h),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _combinedFuture = _loadAllData();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 12.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
