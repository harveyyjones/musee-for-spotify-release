import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Business_Logic/profile_service.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_10_track_model.dart';
import 'package:spotify_project/business/Spotify_Logic/constants.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_artists.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_top_10_tracks_of_the_user.dart';
import 'package:spotify_project/screens/profile_settings.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/widgets/bottom_bar.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_project/constants/app_colors.dart';

class OwnProfileScreenForClients extends StatefulWidget {
  OwnProfileScreenForClients({Key? key}) : super(key: key);

  @override
  State<OwnProfileScreenForClients> createState() =>
      _OwnProfileScreenForClientsState();
}

String defaultImage =
    "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png";

class _OwnProfileScreenForClientsState extends State<OwnProfileScreenForClients>
    with SingleTickerProviderStateMixin {
  late final ProfileDataService _profileDataService;
  final ScrollController _scrollController = ScrollController();
  late Future<Map<String, dynamic>> _combinedFuture;
  static Map<String, dynamic>? _cachedData;
  DateTime? _lastFetchTime;
  int _currentImageIndex = 0;
  bool _showAllGenres = false;
  late AnimationController _animationController;
  late Animation<double> _expansionAnimation;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _profileDataService = ProfileDataService(
      firestoreDatabaseService: FirestoreDatabaseService(),
    );
    _combinedFuture = _loadData();
    _pageController = PageController();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _expansionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  Future<Map<String, dynamic>> _loadData() async {
    // Check cache validity
    if (_cachedData != null && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference.inMinutes < 5) return _cachedData!;
    }

    // Load fresh data
    final data = await _profileDataService.loadProfileData();

    // Update cache
    _cachedData = data;
    _lastFetchTime = DateTime.now();

    return data;
  }

  List<String> _prepareGenres(SpotifyArtistsResponse artists) {
    return _profileDataService.prepareGenres(artists);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _animationController.dispose(); // Add this line
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _combinedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading profile data. Please try again.',
              style: TextStyle(color: AppColors.white),
            ),
          );
        }

        final data = snapshot.data ??
            {
              'userData': null,
              'artists': SpotifyArtistsResponse(
                href: '',
                limit: 0,
                offset: 0,
                total: 0,
                items: [],
              ),
              'tracks': <SpotifyTrack>[],
            };

        final userData = data['userData'];
        final artists = data['artists'] as SpotifyArtistsResponse;
        final tracks = data['tracks'] as List<SpotifyTrack>;
        final genres = _prepareGenres(artists);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.background,
                      Colors.black,
                      AppColors.background,
                    ],
                  ),
                ),
              ),

              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Profile Header
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.55,
                      child: Stack(
                        children: [
                          _buildProfileImages(userData),
                          _buildProfileGradientOverlay(),
                          _buildProfileInfo(userData),
                          _buildSettingsButton(),
                        ],
                      ),
                    ),
                  ),

                  // Content Sections
                  if (genres.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      sliver:
                          SliverToBoxAdapter(child: _buildGenresWidget(genres)),
                    ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          EdgeInsets.only(top: 24.h, right: 20.w, left: 20.w),
                      child: _buildCurrentTrack(),
                    ),
                  ),

                  if (artists != null && artists.items.isNotEmpty)
                    SliverToBoxAdapter(child: _buildTopArtists(artists)),
                  SliverToBoxAdapter(
                      child: Divider(
                          thickness: 1,
                          color: AppColors.white.withOpacity(0.5))),
                  if (tracks.isNotEmpty)
                    SliverToBoxAdapter(child: _buildTopTracks(tracks)),
                ],
              ),

              // Bottom navigation bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BottomBar(
                  selectedIndex: userData?.clinicOwner ?? true ? 2 : 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileImages(dynamic userData) {
    List<String> profilePhotos = userData?.profilePhotos ?? [defaultImage];

    return Stack(
      children: [
        // Main Image
        Container(
          height: MediaQuery.of(context).size.height * 0.55,
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
                color: AppColors.background,
                child: Icon(Icons.error, color: AppColors.primary, size: 40.sp),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: AppColors.background,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
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
                (index) => _buildImageIndicator(index),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageIndicator(int index) {
    final isActive = _currentImageIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : AppColors.white.withOpacity(0.5),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
    );
  }

  Widget _buildProfileGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppColors.black.withOpacity(0.2),
              AppColors.black.withOpacity(0.8),
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
                  fontSize: 45.sp,
                  color: AppColors.white,
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
                userData?.age != null ? '${userData.age}' : '',
                style: GoogleFonts.poppins(
                  fontSize: 45.sp,
                  color: AppColors.white,
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
          _buildBiography(userData),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Positioned(
      top: 40.h,
      right: 20.w,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 8,
            )
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.settings, size: 24.sp),
          color: AppColors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileSettings()),
          ),
        ),
      ),
    );
  }

  Widget _buildBiography(dynamic userData) {
    return Text(
      userData.biography ?? "No biography available.",
      style: TextStyle(
        fontSize: 25.sp,
        color: AppColors.white.withOpacity(0.7),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCurrentTrack() {
    return StreamBuilder<PlayerState>(
      stream: SpotifySdk.subscribePlayerState(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.track == null) {
          return SizedBox.shrink();
        }

        final track = snapshot.data!.track!;
        final isPlaying = !snapshot.data!.isPaused;

        return Container(
          margin: EdgeInsets.only(bottom: 24.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.secondary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.music_note, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${track.artist.name} - ${track.name}',
                  style: TextStyle(color: AppColors.white, fontSize: 16.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopArtists(SpotifyArtistsResponse artists) {
    if (artists.items.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'Top Artists',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: min(artists.items.length, 5), // Show max 5 artists
            itemBuilder: (context, index) {
              final artist = artists.items[index];
              final imageUrl = artist.images.isNotEmpty
                  ? artist.images[0].url
                  : defaultImage; // Use default image if none available

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
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          artist.images.isNotEmpty ? artist.images[0].url : '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      artist.name,
                      style: TextStyle(
                        color: AppColors.white,
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

  Widget _buildTopTracks(List<SpotifyTrack> tracks) {
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
            child: Text(
              'Top Tracks',
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
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: min(tracks.length, 5),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return Container(
                margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
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
                child: ListTile(
                  contentPadding: EdgeInsets.all(12.w),
                  leading: Container(
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
                        track.album.images.isNotEmpty
                            ? track.album.images[0].url
                            : '',
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
                  title: Text(
                    track.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artists.map((artist) => artist.name).join(', '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenresWidget(List<String> genres) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Text(
            'Music Interests',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _expansionAnimation,
          builder: (context, child) {
            final displayedGenres =
                _showAllGenres ? genres : genres.take(4).toList();
            print("Displaying ${displayedGenres.length} genres");

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayedGenres.map((genre) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        // Only show expand/collapse if we have more than 4 genres
        if (genres.length > 4)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showAllGenres = !_showAllGenres;
                  if (_showAllGenres) {
                    _animationController.forward();
                  } else {
                    _animationController.reverse();
                  }
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showAllGenres ? 'Show Less' : 'Show More',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showAllGenres ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage(String imageUrl) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1A1A1A),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1A1A1A),
          child: Icon(Icons.person, color: Color(0xFF6366F1), size: 48.sp),
        ),
      ),
    );
  }
}
