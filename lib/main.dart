import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/ui/utils/stream_subscriber_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/Business_Logic/Models/user_model.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/business/Spotify_Logic/constants.dart';
import 'package:spotify_project/business/business_logic.dart';
import 'package:spotify_project/business/payment_service/call_payment.dart';
import 'package:spotify_project/business/payment_service/payment_screen.dart';
import 'package:spotify_project/business/payment_service/payment_service.dart';
import 'package:spotify_project/screens/landing_screen.dart';
import 'package:spotify_project/screens/own_profile_screens_for_clients.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/screens/steppers.dart';
import 'package:spotify_project/widgets/bottom_bar.dart';
import 'package:spotify_project/widgets/match_loading_widget.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_playlists.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_playlists.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/quick_match_screen.dart';

import 'package:spotify_project/Business_Logic/firestore_database_service.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'getUserDatasToMatch':
        final firestoreService = FirestoreDatabaseService();
        // You'll need to implement a way to get the current song name

        String? currentSongName =
            await firestoreService.returnCurrentlyListeningMusicName();
        // await firestoreService.getUserDatasToMatch(currentSongName, true);
        firestoreService.updateActiveStatus();
        break;
    }
    return Future.value(true);
  });
}

void main() async {
  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();
  await PaymentService().initialize();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAeu7KYeIdCUZ8DZ0oCjjzK15rVdilwKO8",
      appId: "1:985372741706:android:c92c014fe473d59aff96b3",
      messagingSenderId: "985372741706",
      projectId: "musee-285eb",
      storageBucket: "gs://musee-285eb.appspot.com",
    ),
  );

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  await Workmanager().registerPeriodicTask(
    "updateActiveStatus",
    "updateActiveStatus",
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(minutes: 1),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 1),
  );

  // Initialize Spotify connection
  final businessLogic = BusinessLogic();
  try {
    await businessLogic.getAccessToken('b56ad9c2cf434b748466bb6adbb511ca',
        'https://www.rubycurehealthtourism.com/');
    await businessLogic.connectToSpotifyRemote();
  } catch (e) {
    print('Error connecting to Spotify: $e');
    // You might want to show an error dialog or handle the error in some way
  }

  runApp(MyApp(businessLogic: businessLogic));
}

// ... [Keep all the existing imports and main function]

class MyApp extends StatelessWidget {
  final BusinessLogic businessLogic;
  const MyApp({Key? key, required this.businessLogic}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(720, 1080),
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Musee',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFFE57373),
          scaffoldBackgroundColor: const Color(0xFF121212),
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
              .apply(bodyColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE57373),
            secondary: Color(0xFFFFD54F),
          ),
        ),
        home: FutureBuilder<User?>(
          future: FirebaseAuth.instance.authStateChanges().first,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              // return Home(businessLogic: businessLogic);
              return const PaymentButton();
              // return const PaymentScreen(
              //   amount: 1,
              // );
            } else {
              return LandingPage();
            }
          },
        ),
      ),
    );
  }
}

class Home extends StatelessWidget {
  final businessLogic;
  Home({Key? key, this.businessLogic}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: SpotifySdk.subscribeConnectionStatus(),
      builder: (context, snapshot) {
        bool connected = snapshot.data?.connected ?? false;
        return Scaffold(
          bottomNavigationBar: BottomBar(selectedIndex: 0),
          body: Everything(connected: connected),
        );
      },
    );
  }
}

class Everything extends StatefulWidget {
  final bool connected;
  const Everything({Key? key, required this.connected}) : super(key: key);

  @override
  State<Everything> createState() => _EverythingState();
}

class _EverythingState extends State<Everything>
    with SingleTickerProviderStateMixin {
  late Future<List<Playlist>> futurePlaylists;
  bool _isPaymentComplete = false;
  bool _loading = false;
  final FirestoreDatabaseService firestoreDatabaseService =
      FirestoreDatabaseService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Add MediaQuery variables
  late double screenWidth;
  late double screenHeight;
  late double blockSizeHorizontal;
  late double blockSizeVertical;

  @override
  void initState() {
    super.initState();
    // futurePlaylists = fetchPlaylists();
    firestoreDatabaseService.updateActiveStatus();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<List<Playlist>> fetchPlaylists() async {
    SpotifyServiceForPlaylists spotifyService =
        SpotifyServiceForPlaylists(accessToken);
    return await spotifyService.fetchPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize MediaQuery dimensions
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[900]!,
                Colors.black,
                Colors.grey[900]!,
              ],
            ),
          ),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: blockSizeHorizontal * 5, // 5% of screen width
              vertical: blockSizeVertical * 3, // 3% of screen height
            ),
            children: [
              _buildStatusBar(),
              SizedBox(height: blockSizeVertical * 4),
              _buildQuickMatchButton(),
              SizedBox(height: blockSizeVertical * 5),
              _buildCurrentTrackInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: blockSizeHorizontal * 4,
        vertical: blockSizeVertical * 1.5,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(blockSizeHorizontal * 3),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: blockSizeVertical * 1.5,
                width: blockSizeHorizontal * 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      widget.connected ? const Color(0xFF1DB954) : Colors.grey,
                  boxShadow: widget.connected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1DB954).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              SizedBox(width: blockSizeHorizontal * 2),
              Text(
                true ? 'Active - Ready to Match' : 'Inactive',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: blockSizeHorizontal * 3.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.people_outline,
                  size: blockSizeHorizontal * 4.5, color: Colors.grey[400]),
              SizedBox(width: blockSizeHorizontal * 1.5),
              StreamBuilder<int>(
                stream:
                    Stream.periodic(Duration(seconds: Random().nextInt(2) + 10))
                        .asyncMap((_) async {
                  setState(() {});
                  int _lastActiveUsers =
                      Random().nextInt(51) + 50; // Initialize with 50-100

                  // 10% chance to change the number
                  if (Random().nextDouble() < 0.1) {
                    // Calculate max change allowed (10% of current number)
                    int maxChange = (_lastActiveUsers * 0.1).round();

                    // Randomly increase or decrease by up to maxChange
                    int change =
                        Random().nextInt(maxChange * 2 + 1) - maxChange;

                    // Update the number
                    _lastActiveUsers = _lastActiveUsers + change;
                  }

                  return _lastActiveUsers;
                }),
                initialData: Random().nextInt(51) + 50, // Initial random 50-100
                builder: (context, snapshot) {
                  return Text(
                    '${snapshot.data} Active',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: blockSizeHorizontal * 3.5,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMatchButton() {
    return GestureDetector(
      onTap: _navigateToQuickMatch,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 1, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: blockSizeVertical * 3,
                horizontal: blockSizeHorizontal * 5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(blockSizeHorizontal * 4),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF9333EA),
                    Color(0xFFEC4899),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Colors.white70],
                        ).createShader(bounds),
                        child: Text(
                          'Quick Match',
                          style: GoogleFonts.poppins(
                            fontSize: blockSizeHorizontal * 6,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: blockSizeVertical * 0.5),
                      Text(
                        'Find others listening to your music',
                        style: TextStyle(
                          fontSize: blockSizeHorizontal * 3.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: EdgeInsets.all(blockSizeHorizontal * 4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF9333EA),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: blockSizeHorizontal * 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToQuickMatch() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const QuickMatchesScreen()));
  }

  Widget _buildCurrentTrackInfo() {
    Duration duration = const Duration(seconds: 5);

    return StreamBuilder<PlayerState>(
      stream: SpotifySdk.subscribePlayerState(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in Spotify stream: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data?.track == null) {
          return const SizedBox.shrink();
        }

        final track = snapshot.data!.track!;
        firestoreDatabaseService.updateIsUserListening(
          snapshot.data!.isPaused == false,
          track.name,
        );
        return Container(
          margin: EdgeInsets.symmetric(vertical: 24.h),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.imageUri != null
                            ? FutureBuilder<Uint8List?>(
                                future: SpotifySdk.getImage(
                                  imageUri: track.imageUri,
                                ),
                                builder: (context, imageSnapshot) {
                                  if (imageSnapshot.hasData) {
                                    return Image.memory(
                                      imageSnapshot.data!,
                                      width: MediaQuery.of(context).size.width *
                                          0.6,
                                      height:
                                          MediaQuery.of(context).size.width *
                                              0.6,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(
                                    width: 60.w,
                                    height: 60.w,
                                    color: Colors.grey[800],
                                    child: Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                      size: 30.sp,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                width: 60.w,
                                height: 60.w,
                                color: Colors.grey[800],
                                child: Icon(
                                  Icons.music_note,
                                  color: Colors.white54,
                                  size: 30.sp,
                                ),
                              ),
                      ),
                      SizedBox(height: 14.h),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        alignment: Alignment.center,
                        child: Text(
                          track.name,
                          style: TextStyle(
                            fontSize: 33.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        alignment: Alignment.center,
                        child: Text(
                          track.artist?.name ?? '',
                          style: TextStyle(
                            fontSize: 25.sp,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsGrid() {
    return FutureBuilder<List<Playlist>>(
      future: futurePlaylists,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.secondary)));
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('No playlists found',
                  style: TextStyle(color: Colors.white70)));
        } else {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 53.sp,
              mainAxisSpacing: 53.sp,
            ),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final playlist = snapshot.data![index];
              return _buildPlaylistItem(playlist);
            },
          );
        }
      },
    );
  }

  Widget _buildPlaylistItem(Playlist playlist) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          const BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: playlist.images.isNotEmpty
                ? Image.network(
                    playlist.images.first.url,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Theme.of(context).colorScheme.secondary,
                    child: const Icon(Icons.music_note,
                        color: Colors.white, size: 50),
                  ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(0, 0, 0, 0),
                  const Color.fromARGB(255, 0, 0, 0).withOpacity(1),
                ],
                stops: [0.5, 1.0],
              ),
            ),
          ),
          // Text
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Text(
              playlist.name,
              style: GoogleFonts.poppins(
                fontSize: 25.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
} // Close _EverythingState class

// Close Everything class

Widget _buildCurrentMatchesInTheListeningSong(String currentTrackName) {
  return FutureBuilder<UserModel?>(
      future: firestoreDatabaseService
          .getTheCurrentMatchesInTheListeningSong(currentTrackName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MatchLoadingWidget();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!;

        return SizedBox(
          width: 430.w,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: userData.profilePhotos.isNotEmpty &&
                              userData.profilePhotos.first != null
                          ? NetworkImage(userData.profilePhotos.first)
                          : null,
                      child: (userData.profilePhotos.isEmpty ||
                              userData.profilePhotos.first == null)
                          ? const Icon(Icons.person,
                              size: 25, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData.name ?? 'Anonymous',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Listening to the same song!',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
}
