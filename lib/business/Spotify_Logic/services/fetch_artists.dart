import 'dart:convert';
import 'package:http/http.dart' as http;

class SpotifyServiceForTopArtists {
  final String accessToken;

  SpotifyServiceForTopArtists(this.accessToken);

  Future<SpotifyArtistsResponse> fetchArtists(String _accessToken) async {
    String url = 'https://api.spotify.com/v1/me/top/artists?limit=10&offset=0';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return SpotifyArtistsResponse.fromJson(data);
    } else {
      throw Exception('Failed to fetch artists');
    }
  }
}

class SpotifyArtistsResponse {
  final String href;
  final int limit;
  final String? next;
  final int offset;
  final String? previous;
  final int total;
  final List<Artist> items;

  SpotifyArtistsResponse({
    required this.href,
    required this.limit,
    this.next,
    required this.offset,
    this.previous,
    required this.total,
    required this.items,
  });

  factory SpotifyArtistsResponse.fromJson(Map<String, dynamic> json) {
    print("Parsing SpotifyArtistsResponse: $json");
    return SpotifyArtistsResponse(
      href: json['href'] ?? 'default_href',
      limit: json['limit'] ?? 0,
      next: json['next'] ?? 'default_next',
      offset: json['offset'] ?? 0,
      previous: json['previous'] ?? 'default_previous',
      total: json['total'] ?? 0,
      items: List<Artist>.from(
          json['items']?.map((item) => Artist.fromJson(item)) ?? []),
    );
  }
}

class Artist {
  final ExternalUrls externalUrls;
  final Followers followers;
  final List<String> genres;
  final String href;
  final String id;
  final List<ImageOftheArtist> images;
  final String name;
  final int popularity;
  final String type;
  final String uri;

  Artist({
    required this.externalUrls,
    required this.followers,
    required this.genres,
    required this.href,
    required this.id,
    required this.images,
    required this.name,
    required this.popularity,
    required this.type,
    required this.uri,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    try {
      print("Parsing artist: ${json['name'] ?? 'Unknown Artist'}");
      return Artist(
        externalUrls: ExternalUrls.fromJson(
            json['external_urls'] as Map<String, dynamic>? ?? {}),
        followers: Followers.fromJson(
            json['followers'] as Map<String, dynamic>? ?? {}),
        genres: (json['genres'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        href: json['href']?.toString() ?? 'default_href',
        id: json['id']?.toString() ?? 'default_id',
        images: (json['images'] as List<dynamic>?)
                ?.map((image) =>
                    ImageOftheArtist.fromJson(image as Map<String, dynamic>))
                .toList() ??
            [],
        name: json['name']?.toString() ?? 'Unknown Artist',
        popularity: json['popularity'] as int? ?? 0,
        type: json['type']?.toString() ?? 'default_type',
        uri: json['uri']?.toString() ?? 'default_uri',
      );
    } catch (e) {
      print("Error parsing artist JSON: $e");
      print("Problematic JSON: $json");
      return Artist(
        externalUrls: ExternalUrls(spotify: 'default_spotify'),
        followers: Followers(total: 0),
        genres: [],
        href: 'default_href',
        id: 'default_id',
        images: [],
        name: 'Unknown Artist',
        popularity: 0,
        type: 'default_type',
        uri: 'default_uri',
      );
    }
  }
}

class ExternalUrls {
  final String spotify;

  ExternalUrls({required this.spotify});

  factory ExternalUrls.fromJson(Map<String, dynamic> json) {
    print("Parsing ExternalUrls: $json");
    return ExternalUrls(spotify: json['spotify'] ?? 'default_spotify');
  }
}

class Followers {
  final String? href;
  final int total;

  Followers({this.href, required this.total});

  factory Followers.fromJson(Map<String, dynamic> json) {
    print("Parsing Followers: $json");
    return Followers(
      href: json['href'] ?? 'default_href',
      total: json['total'] ?? 0,
    );
  }
}

class ImageOftheArtist {
  final String url;
  final int height;
  final int width;

  ImageOftheArtist(
      {required this.url, required this.height, required this.width});

  factory ImageOftheArtist.fromJson(Map<String, dynamic> json) {
    print("Parsing ImageOftheArtist: $json");
    return ImageOftheArtist(
      url: json['url'] ?? 'default_url',
      height: json['height'] ?? 0,
      width: json['width'] ?? 0,
    );
  }
}
