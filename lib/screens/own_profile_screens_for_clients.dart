import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_10_track_model.dart';
import 'package:spotify_project/business/Spotify_Logic/constants.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_artists.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_top_10_tracks_of_the_user.dart';
import 'package:spotify_project/screens/profile_settings.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/widgets/bottom_bar.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class OwnProfileScreenForClients extends StatefulWidget {
  OwnProfileScreenForClients({Key? key}) : super(key: key);

  @override
  State<OwnProfileScreenForClients> createState() =>
      _OwnProfileScreenForClientsState();
}

class _OwnProfileScreenForClientsState extends State<OwnProfileScreenForClients>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FirestoreDatabaseService _serviceForSnapshot =
      FirestoreDatabaseService();
  late Future<Map<String, dynamic>> _combinedFuture;
  static Map<String, dynamic>? _cachedData;
  DateTime? _lastFetchTime;
  int _currentImageIndex = 0;
  bool _showAllGenres = false; // Add this line

  late AnimationController _animationController;
  late Animation<double> _expansionAnimation;

  @override
  void initState() {
    super.initState();
    _combinedFuture = _loadAllData();
    _pageController = PageController();

    // Add animation controller initialization
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _expansionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  PageController _pageController = PageController();

  Future<Map<String, dynamic>> _loadAllData() async {
    // Check if cached data exists and is less than 5 minutes old
    if (_cachedData != null && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference.inMinutes < 5) {
        return _cachedData!;
      }
    }

    final userData = await _serviceForSnapshot.getUserData();
    final artistsData = await _serviceForSnapshot
        .getTopArtistsFromFirebase(userData.userId ?? '');
    final tracks = await SpotifyServiceForTracks(accessToken).fetchTracks();

    print("Fetched ${artistsData!.length} artists from Firebase");

    // Convert the Firebase data back to a SpotifyArtistsResponse
    final artists = SpotifyArtistsResponse(
      href: '',
      limit: artistsData.length,
      offset: 0,
      total: artistsData.length,
      items: artistsData.map((artist) {
        print(
            "Processing artist: ${artist['name']}, Genres: ${artist['genres']}");
        return Artist(
          externalUrls: ExternalUrls(spotify: ''),
          followers: Followers(total: 0),
          genres: List<String>.from(artist['genres'] ?? []),
          href: '',
          id: artist['id'] ?? '',
          images: [
            if (artist['imageUrl'] != null)
              ImageOftheArtist(url: artist['imageUrl'], height: 0, width: 0)
          ],
          name: artist['name'] ?? '',
          popularity: artist['popularity'] ?? 0,
          type: '',
          uri: '',
        );
      }).toList(),
    );

    // Update the top tracks in Firebase
    await _serviceForSnapshot.updateTopTracks(tracks);

    _cachedData = {
      'userData': userData,
      'artists': artists,
      'tracks': tracks,
    };
    _lastFetchTime = DateTime.now();

    return _cachedData!;
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
          return Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)));
        }
        if (snapshot.hasError) {
          print("Error in FutureBuilder: ${snapshot.error}");
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData) {
          print("No data available in FutureBuilder");
          return Center(
              child: Text('No data available',
                  style: TextStyle(color: Colors.white)));
        }

        final data = snapshot.data!;
        final userData = data['userData'];
        final artists = data['artists'] as SpotifyArtistsResponse;
        final tracks = data['tracks'] as List<SpotifyTrack>;
        final genres = _prepareGenres(artists);

        print("Building profile with ${genres.length} genres");

        return Scaffold(
          backgroundColor: Colors.black,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildUserProfile(userData)),
              SliverToBoxAdapter(child: _buildGenresWidget(genres)),
              SliverToBoxAdapter(child: _buildTopArtists(artists)),
              SliverToBoxAdapter(
                  child: Divider(
                      thickness: 1,
                      color:
                          Color.fromARGB(0, 255, 255, 255).withOpacity(0.5))),
              SliverToBoxAdapter(child: _buildTopTracks(tracks)),
            ],
          ),
          bottomNavigationBar: BottomBar(
            selectedIndex: userData.clinicOwner ?? true ? 2 : 2,
          ),
        );
      },
    );
  }

  Widget _buildUserProfile(dynamic userData) {
    List<String> profilePhotos = userData.profilePhotos ?? [];
    String defaultImage =
        "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png";

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
            ],
          ),
        ),
        Positioned(
          top: 40,
          right: 20,
          child: InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ProfileSettings()));
            },
            child: Hero(
              tag: "Profile Screen",
              child: Icon(Icons.settings, size: 30.sp, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTrack() {
    return StreamBuilder<PlayerState>(
      stream: SpotifySdk.subscribePlayerState(),
      builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data?.track == null) {
          return SizedBox.shrink();
        }

        final track = snapshot.data!.track!;
        return Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: Color(0xFF1DB954).withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.music_note, color: Color(0xFF1DB954)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${track.artist.name} - ${track.name}',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
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
            itemCount: 5,
            itemBuilder: (context, index) {
              final artist = artists.items[index];
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
                          artist.images.isNotEmpty ? artist.images[0].url : '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      artist.name,
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

  Widget _buildTopTracks(List<SpotifyTrack> tracks) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 0, 0, 0),
            Color.fromARGB(255, 17, 188, 119).withOpacity(0.1),
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
            itemCount: 5,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1DB954).withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      track.album.images.isNotEmpty
                          ? track.album.images[0].url
                          : '',
                      width: 100.w,
                      height: 100.w,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 60.w,
                          height: 60.w,
                          color: Color(0xFF1DB954).withOpacity(0.2),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Color(0xFF1DB954),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60.w,
                        height: 60.w,
                        color: Color(0xFF1DB954).withOpacity(0.2),
                        child: Icon(Icons.error, color: Color(0xFF1DB954)),
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
                  ),
                  subtitle: Text(
                    track.artists.map((artist) => artist.name).join(', '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14.sp,
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
    print("Building genres widget with ${genres.length} genres");
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
        AnimatedBuilder(
          animation: _expansionAnimation,
          builder: (context, child) {
            final displayedGenres =
                _showAllGenres ? genres : genres.take(4).toList();
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: displayedGenres.map((genre) {
                  return AnimatedOpacity(
                    opacity: _showAllGenres || genres.indexOf(genre) < 4
                        ? 1.0
                        : _expansionAnimation.value,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
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
                      color: Color(0xFF1DB954),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showAllGenres ? 0.5 : 0,
                    duration: Duration(milliseconds: 300),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF1DB954),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<String> _prepareGenres(SpotifyArtistsResponse artists) {
    // Implement the logic to extract and process genres from the artists data
    // For example, you can use a Set to remove duplicates and then convert it back to a List
    Set<String> genresSet = Set<String>();
    for (var artist in artists.items) {
      genresSet.addAll(artist.genres);
    }
    return genresSet.toList();
  }
}
