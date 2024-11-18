import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_10_track_model.dart';
import 'package:spotify_project/business/Spotify_Logic/constants.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_artists.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_top_10_tracks_of_the_user.dart';
import 'package:spotify_project/Business_Logic/Models/user_model.dart';

class ProfileDataService {
  final FirestoreDatabaseService _firestoreDatabaseService;

  ProfileDataService({
    required FirestoreDatabaseService firestoreDatabaseService,
  }) : _firestoreDatabaseService = firestoreDatabaseService;

  Future<Map<String, dynamic>> loadProfileData() async {
    try {
      // 1. Get user data
      final userData = await _firestoreDatabaseService.getUserData();
      if (userData == null) throw Exception("Failed to fetch user data");

      // 2. Fetch artists directly from Spotify
      final SpotifyServiceForTopArtists artistsService =
          SpotifyServiceForTopArtists(accessToken);
      final artists = await artistsService.fetchArtists(accessToken);

      // 3. Update artists in Firebase for persistence
      await _firestoreDatabaseService.updateTopArtists(artists.items);

      // 4. Fetch tracks from Spotify
      final tracks = await SpotifyServiceForTracks(accessToken).fetchTracks();
      await _firestoreDatabaseService.updateTopTracks(tracks);

      return {
        'userData': userData,
        'artists': artists,
        'tracks': tracks,
      };
    } catch (e, stackTrace) {
      print("Error in loadProfileData: $e");
      print("Stack trace: $stackTrace");

      // Return empty data with valid user data
      return {
        'userData': await _firestoreDatabaseService.getUserData(),
        'artists': SpotifyArtistsResponse(
          href: '',
          limit: 0,
          offset: 0,
          total: 0,
          items: [],
        ),
        'tracks': <SpotifyTrack>[],
      };
    }
  }

  List<String> prepareGenres(SpotifyArtistsResponse artists) {
    if (artists.items.isEmpty) return [];

    Set<String> uniqueGenres = Set<String>();

    // Take first 4 artists and get their genres
    for (var artist in artists.items.take(4)) {
      uniqueGenres.addAll(artist.genres);
    }

    // Sort and limit to 8 genres
    return uniqueGenres.toList()
      ..sort()
      ..take(8);
  }
}
