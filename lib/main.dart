import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/business/Spotify_Logic/constants.dart';
import 'package:spotify_project/business/business_logic.dart';
import 'package:spotify_project/screens/landing_screen.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/screens/steppers.dart';
import 'package:spotify_project/widgets/bottom_bar.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_playlists.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_playlists.dart';

import 'screens/quick_match_screen.dart';

import 'package:pay/pay.dart'; // Added import for ApplePayButton and GooglePayButton

import 'package:workmanager/workmanager.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'getUserDatasToMatch':
        final firestoreService = FirestoreDatabaseService();
        // You'll need to implement a way to get the current song name
        String? currentSongName =
            await firestoreService.returnCurrentlyListeningMusicName();
        await firestoreService.getUserDatasToMatch(currentSongName, true);
        break;
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    "getUserDatasToMatch",
    "getUserDatasToMatch",
    frequency: Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
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
          primaryColor: Color(0xFFE57373),
          scaffoldBackgroundColor: Color(0xFF121212),
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
              .apply(bodyColor: Colors.white),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFFE57373),
            secondary: Color(0xFFFFD54F),
          ),
        ),
        home: FutureBuilder<User?>(
          future: FirebaseAuth.instance.authStateChanges().first,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Home();
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

class _EverythingState extends State<Everything> {
  late Future<List<Playlist>> futurePlaylists;
  bool _isPaymentComplete = false;
  bool _loading = false;
  final FirestoreDatabaseService firestoreDatabaseService =
      FirestoreDatabaseService();

  final _paymentItems = [
    PaymentItem(
      label: 'Total',
      amount: '1.00',
      status: PaymentItemStatus.final_price,
    )
  ];

  @override
  void initState() {
    super.initState();
    futurePlaylists = fetchPlaylists();
    firestoreDatabaseService.updateActiveStatus();
  }

  Future<List<Playlist>> fetchPlaylists() async {
    SpotifyServiceForPlaylists spotifyService =
        SpotifyServiceForPlaylists(accessToken);
    return await spotifyService.fetchPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Darker background color
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          children: [
            SizedBox(height: 16.h),
            _buildQuickMatchButton(),
            if (widget.connected) _buildCurrentTrackInfo(),
            SizedBox(height: 24.h),
            _buildPlaylistsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMatchButton() {
    return GestureDetector(
      onTap: _navigateToQuickMatch,
      child: Container(
        width: 220.w,
        height: 70.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: true
                ? [Color(0xFF1DB954), Color(0xFF1ED760)] // Spotify green
                : [Color(0xFF282828), Color(0xFF181818)], // Spotify dark grey
          ),
          boxShadow: [
            BoxShadow(
              color: _isPaymentComplete
                  ? Color(0xFF1DB954).withOpacity(0.3)
                  : Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isPaymentComplete)
              Positioned(
                left: 15.w,
                child: Icon(
                  Icons.music_note,
                  color: Colors.white.withOpacity(0.7),
                  size: 24.sp,
                ),
              ),
            Text(
              "Quick Match",
              style: GoogleFonts.montserrat(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (_isPaymentComplete)
              Positioned(
                right: 15.w,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 18.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToQuickMatch() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const QuickMatchesScreen()));
  }

  Widget _buildCurrentTrackInfo() {
    return StreamBuilder<PlayerState>(
      stream: SpotifySdk.subscribePlayerState(),
      builder: (context, snapshot) {
        final track = snapshot.data?.track;
        if (track == null) {
          return SizedBox.shrink();
        }

        firestoreDatabaseService.updateActiveStatus();

        return Container(
          margin: EdgeInsets.symmetric(vertical: 24.h),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.music_note,
                  color: Theme.of(context).colorScheme.secondary),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: TextStyle(
                          fontSize: 18.sp, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      track.artist?.name ?? '',
                      style: TextStyle(fontSize: 14.sp, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
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
          return Center(
              child: Text('No playlists found',
                  style: TextStyle(color: Colors.white70)));
        } else {
          return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
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
          BoxShadow(
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
                    child:
                        Icon(Icons.music_note, color: Colors.white, size: 50),
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
                    offset: Offset(0, 1),
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

