// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotify_project/Business_Logic/Models/message_model.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_10_track_model.dart';
import 'package:spotify_project/business/Spotify_Logic/Models/top_artists_of_the_user.dart'
    as models;
import 'package:spotify_project/business/Spotify_Logic/services/fetch_artists.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/screens/sharePostScreen.dart' as share_screen;
import 'package:spotify_project/screens/sharePostScreen.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'Models/user_model.dart';

List allClinicOwnersList = [];

class FirestoreDatabaseService {
  final _fireStore = FirebaseFirestore.instance;
  var collection = FirebaseFirestore.instance.collection('users');

  late final FirebaseFirestore _instance = FirebaseFirestore.instance;
  var currentUserUID;
  // O anki aktif kullanıcının bilgilerini alıp nesneye çeviren metod.
  Future<UserModel> getUserData() async {
    User? user = await FirebaseAuth.instance.currentUser;

    DocumentSnapshot<Map<String, dynamic>> okunanUser =
        await FirebaseFirestore.instance.doc("users/${user?.uid}").get();
    Map<String, dynamic>? okunanUserbilgileriMap = okunanUser.data();
    UserModel okunanUserBilgileriNesne =
        UserModel.fromMap(okunanUserbilgileriMap!);
    print(okunanUserBilgileriNesne.toString());
    return okunanUserBilgileriNesne;
  }

  Future<UserModel> getUserDataForDetailPage([uid]) async {
    // Başkasının profilini incelerken veri çekmeye yarıyor.
    DocumentSnapshot<Map<String, dynamic>> okunanUser =
        await FirebaseFirestore.instance.doc("users/${uid}").get();
    Map<String, dynamic>? okunanUserbilgileriMap = okunanUser.data();
    UserModel okunanUserBilgileriNesne =
        UserModel.fromMap(okunanUserbilgileriMap!);
    print(okunanUserBilgileriNesne.name.toString());
    return okunanUserBilgileriNesne;
  }

  Future<UserModel?> getUserDataForMessageBox(uid) async {
    // Mesaj kutusunda konuştuğum insanların ID'lerini alarak kişisel bilgilerini döndüren metod.
    DocumentSnapshot<Map<String, dynamic>> okunanUser =
        await FirebaseFirestore.instance.doc("users/${uid}").get();
    Map<String, dynamic>? okunanUserbilgileriMap = await okunanUser.data();
    if (okunanUserbilgileriMap != null) {
      UserModel okunanUserBilgileriNesne =
          UserModel.fromMap(okunanUserbilgileriMap);
      print(" Fotolar :${okunanUserBilgileriNesne.name.toString()}");

      return okunanUserBilgileriNesne;
    }
    return null;
  }

  Future<List<UserModel>> getAllUsersData() async {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection("users").get();

    List<UserModel> userList = querySnapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();

    return userList;
  }

// Burda stream için verileri çekiyoruz.
  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfileData() {
    var ref = _instance.collection("users").doc(currentUser!.uid).snapshots();
    return ref;
  }

// Paylaşma tuşuna basıldıktan ve foto seçildikten sonra db'ye yazdırılan fotonun bilgilerini çeker.
  Future<DocumentSnapshot<Map<String, dynamic>>>
      getBeingSharedPostData() async {
    var paylasilanPostSayisi = await getSharedPostNumber();
    final ref = await _instance
        .collection("users")
        .doc(currentUser!.uid)
        .collection("sharedPosts")
        .doc("post$paylasilanPostSayisi")
        .get();

    return ref;
  }

  getAllSharedPosts() {
    // Tüm paylaşılan postları çeker, tabi kendi paylaştıkları.
    print("Tıklandı");
    return _instance
        .collection("users")
        .doc(currentUser!.uid)
        .collection("sharedPosts")
        .orderBy("timeStamp", descending: true)
        .snapshots();
  }

  getAllSharedPostsOfSomeone(uid) {
    // Tüm paylaşılan postları çeker, ancak başka bir kullanıcının.
    print("Tıklandı");
    return _instance
        .collection("users")
        .doc(uid)
        .collection("sharedPosts")
        .orderBy("timeStamp", descending: true)
        .snapshots();
  }

  getAllSharedPostsForCardDetails(uid) {
    print("Tıklandı");
    return _instance
        .collection("users")
        .doc(uid)
        .collection("sharedPosts")
        .orderBy("timeStamp", descending: true)
        .snapshots();
  }

// Burada ilk kez register sayfasından aldığımız verileri veritabanına yolluyoruz. Öncesinde modelden geçirip map'e dönüştürüyoruz.
  Future<List<String>> uploadProfileImages(List<File> images) async {
    List<String> imageUrls = [];
    for (var i = 0; i < images.length; i++) {
      String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(
          'users/${FirebaseAuth.instance.currentUser!.uid}/profile_images/$fileName');
      UploadTask uploadTask = ref.putFile(images[i]);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }
    return imageUrls;
  }

  Future saveUser({
    String? biography,
    List<String>? profilePhotos,
    String? name,
    String? majorInfo,
    String? clinicLocation,
    String? clinicName,
    String? phoneNumber,
    bool? clinicOwner,
    String? uid,
    int? age,
    String? gender,
    List<String>? interestedIn,
  }) async {
    UserModel eklenecekUser = UserModel(
      biography: biography ?? "",
      eMail: FirebaseAuth.instance.currentUser?.email ?? "",
      majorInfo: majorInfo ?? "",
      profilePhotoURL:
          profilePhotos?.isNotEmpty == true ? profilePhotos!.first : null,
      profilePhotos: profilePhotos ?? [],
      name: name ?? "",
      clinicLocation: clinicLocation ?? "",
      userId: uid ?? FirebaseAuth.instance.currentUser?.uid,
      clinicName: clinicName ?? "",
      clinicOwner: clinicOwner ?? false,
      phoneNumber: phoneNumber,
      age: age,
      gender: gender,
      interestedIn: interestedIn ?? [],
    );

    await FirebaseFirestore.instance
        .collection("users")
        .doc(eklenecekUser.userId)
        .set(eklenecekUser.toMap());

    return eklenecekUser;
  }

  updateProfilePhoto(String imageURL) async {
    DocumentReference userRef =
        _instance.collection("users").doc(currentUser!.uid);

    // First, get the current profilePhotos array
    DocumentSnapshot userDoc = await userRef.get();
    List<String> profilePhotos =
        List<String>.from(userDoc['profilePhotos'] ?? []);

    // Update the first item if it exists, otherwise add the new URL
    if (profilePhotos.isNotEmpty) {
      profilePhotos[0] = imageURL;
    } else {
      profilePhotos.add(imageURL);
    }

    // Update both profilePhotos and profilePhotoURL
    await userRef
        .update({"profilePhotos": profilePhotos, "profilePhotoURL": imageURL});

    print("Profile photo updated successfully");
  }

  updateName(newName) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"name": newName});
  }

  updateBiography(newBiography) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"biography": newBiography});
  }

  getName() async {
    String? name = "deafult";
    await getProfileData().forEach((element) {
      name = element.data()!["name"];
    });
    return name.toString();
  }

  void updateMajorInfo(String newMajorInfo) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"majorInfo": newMajorInfo});
  }

  void updateClinicLocation(String newLocation) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"clinicLocation": newLocation});
  }

  void updatePhoneNumber(String phoneNumber) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"phoneNumber": phoneNumber});
  }

  void updateClinicName(String clinicName) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"clinicName": clinicName});
  }

  void updateClinicOwnerStatus(bool status) {
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"clinicOwner": status});
  }

  void updateCaption(
    String newCaption,
  ) async {
    // Burada önce kaçıncı postu güncelleyeceiğini anlamak için toplam kaç post atılıdığını çekiyoruz.
    //Sonrasında (Son postu aldığımız için) güncelleme işlemi realtime olarak gerçekleşiyor.
    var postNumber = await getSharedPostNumber();
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .collection("sharedPosts")
        .doc("post$postNumber")
        .update(
      {"caption": newCaption, "uid": currentUser!.uid},
    );
  }

  Future<File?> cropImage(File imageFile) async {
    // TODO: Fotoyu kırpmadan çıkınca null hatası veriyor. Onu bir ara düzelt.
    CroppedFile? croppedImage = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatioPresets: [CropAspectRatioPreset.square],
    );
    return File(croppedImage!.path);
  }

  getSharedPostNumber() async {
    final QuerySnapshot docs = await _instance
        .collection("users")
        .doc(currentUser!.uid)
        .collection("sharedPosts")
        .get();

    final int docs0 = docs.docs.length;
    print("Paylaşılan foto sayısı: $docs0");

    return docs0;
  }

// Post paylaşma.
  Future sharePost(ImageSource source, context) async {
    String? downloadImageURL;
    File? _image;
    try {
      uploadImageToDatabase() async {
        UploadTask? uploadTask;
        Reference ref = await FirebaseStorage.instance
            .ref()
            .child("users")
            .child(currentUser!.uid)
            .child("post${await getSharedPostNumber()}.jpg");

        uploadTask = ref.putFile(_image!);
        await (uploadTask.whenComplete(() => ref.getDownloadURL().then((value) {
              downloadImageURL = value;
            })));
        print("Paylaşılan post URL'i : $downloadImageURL");

        await _instance
            .collection("users")
            .doc(currentUser!.uid)
            .collection("sharedPosts")
            .doc("post${await getSharedPostNumber() + 1}")
            .set({
          "sharedPost": downloadImageURL,
          "caption": "caption this",
          "timeStamp": Timestamp.now()
        }).then((value) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SharePostScreen(),
                )));
      }

      final image = await ImagePicker().pickImage(source: source);
      if (image == null) {
        return;
      } else {
        File? img = File(image.path);
        img = (await cropImage(img));

        _image = img;

        uploadImageToDatabase();
      }
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

// Çıkış yaparken
  signOut(context) async {
    await FirebaseAuth.instance.signOut();
    share_screen.callSnackbar("Signed Out", Colors.green, context);
  }

// Ana sayfadaki selamlama mesajlarında kullanmak için.
  String greeting() {
    var hour = DateTime.now().hour;
    if (hour < 12 && hour > 5) {
      return 'Morning';
    }
    if (hour < 17 && hour > 12) {
      return 'Afternoon';
    }
    return 'Evening';
  }

// Mesajları stream veri tipinde çekerken.
  Stream<List<Message>> getMessagesFromStream(
      String currentUserID, String userIDOfOtherUser) {
    var snapshot = _fireStore
        .collection("conversations")
        .doc("$currentUserID--$userIDOfOtherUser")
        .collection("messages")
        .orderBy("date")
        .snapshots();
    // Önce dökümanları sırayla ele almak için 1. map() metodunu çağırdık, sonra her bir dökümanı fromMap() metoduna yollamak için ikinci map metodunu çağırdık.
    return snapshot.map((event) =>
        event.docs.map((message) => Message.fromMap(message.data())).toList());
  }

// Kalıcı olarak hesap silme. Hesap silinir ama bilgiler kalır. Bilgileri de silmek için ayrı bir fonksiyon daha kullanılması gerekli.

  deleteAccount() async {
    User? user = await FirebaseAuth.instance.currentUser;
    print("Şu hesap siliniyor.. ${user!.uid}");

    try {
      user != null
          ? await user.delete().whenComplete(() {
              print("Account has been deleted.");

              // Use a different method or import the correct one
              // For example, you could use a local method or pass the context
              // Here's a placeholder comment:
              // TODO: Implement proper snackbar call or error handling

              print(
                  "User with the uid of: ${currentUser?.uid} deleted. *************************");
            })
          : print("User is null");
    } catch (e) {
      print("***********************************");
      print(e.toString());
    }
  }

  Future<void> updateIsUserListening(bool isPlaying, String songName) async {
    if (currentUser == null) return;

    try {
      await _instance.collection("users").doc(currentUser!.uid).update({
        "isUserListening": isPlaying,
        "songName": songName,
        "lastUpdated": FieldValue.serverTimestamp()
      });
    } catch (e) {
      print('Error updating user listening status: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserListeningStream() {
    // Returns the stream of the currently listening music, or last listened music.
    return _instance
        .collection("users")
        .doc(currentUser!.uid)
        .snapshots()
        .map((snapshot) => {
              'isListening': snapshot.data()?['isUserListening'] ?? false,
              'songName': snapshot.data()?['songName'] ?? '',
            });
  }

  getUserDatasToMatch(songName, amIListeningNow) async {
    print("Şu method tetiklendi: ${getUserDatasToMatch}");
    // Anlık olarak sürekli olarak o anda eşleşilen kişinin bilgilerini kullanıma hazır tutuyor.
    try {
      QuerySnapshot<Map<String, dynamic>> _okunanUser =
          await FirebaseFirestore.instance.collection("users").get();

      for (var item in _okunanUser.docs) {
        // Check if the document contains the 'songName' field
        if (item.data().containsKey('songName') &&
            songName == item["songName"]) {
          sendMatchesToDatabase(item["userId"], songName, songName);
          print("Eşleşilen kişi: ${item["name"]}");
          print("Eşleşilen kişinin uid: ${item["userId"]}");
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  sendMatchesToDatabase(uid, musicUrl, title) async {
    final previousMatchesRef = _instance.doc("matches/${currentUser!.uid}");
    final matchDoc =
        previousMatchesRef.collection("previousMatchesList").doc(uid);

    // Check if we matched the user before
    final likes = await getLikedPeople();
    final hasMatchedBefore = likes.any((like) => like.userId == uid);

    if (hasMatchedBefore) {
      // Update existing match
      await matchDoc.update({
        "timeStamp": DateTime.now(),
        "url": musicUrl,
        "titleOfTheSong": title,
      });
      print("Existing match updated successfully");
    } else {
      // Create new match
      await matchDoc.set({
        "uid": uid,
        "timeStamp": DateTime.now(),
        "url": musicUrl,
        "titleOfTheSong": title,
        "isLiked": null
      });
      print("New match added successfully");
    }
  }

  updateIsLiked(value, uidOfTheMatch) async {
    // Updates if liked to use later in the notification screen. (Or to not to show the swipe cards.)
    await _instance
        .collection("matches")
        .doc(currentUser!.uid)
        .collection("previousMatchesList")
        .doc(uidOfTheMatch)
        .update({"isLiked": value}).then(
            (value) => print("Update isLiked succesfull."));
  }

  updateIsLikedAsQuickMatch(value, uidOfTheMatch) async {
    // Updates if liked to use later in the notification screen. (Or to not to show the swipe cards.)
    final previousMatchesRef = _instance.doc("matches/${currentUser!.uid}");
    previousMatchesRef.collection("quickMatchesList").doc(uidOfTheMatch).set({
      "uid": uidOfTheMatch,
      "timeStamp": DateTime.now(),
      "isLiked": value
    }).then((value) => print("İşlem başarılı"));
  }

  getMatchesIds() async {
    print("Şu method tetiklendi getMatchesIds().");
    // Tüm eşleşmelerin Id'lerini döndürür. Daha sonra bilgileri çekmek için kullanılacak.
    List tumEslesmelerinIdsi = [];
    var previousMatchesRef = await _instance
        .collection("matches")
        .doc(currentUser!.uid)
        .collection("previousMatchesList")
        .get();
    for (var item in previousMatchesRef.docs) {
      print(item["uid"]);
      tumEslesmelerinIdsi.add(item["uid"]);
      print("Tüm eşleşmelerin olduğu kişilerin idleri: ${tumEslesmelerinIdsi}");
      return tumEslesmelerinIdsi;
    }
  }

  Future<UserModel?> getTheCurrentMatchesInTheListeningSong(
      String currentTrackName) async {
    // when user is listening actively and match at that time with someone or in the past in the same song. They will be returned here.
    try {
      final currentMatch = await _instance
          .collection("matches")
          .doc(currentUser!.uid)
          .collection("previousMatchesList")
          .doc(currentUser!.uid)
          .get();

      if (currentTrackName != null &&
          currentTrackName == await getTheMutualSongViaUId(currentUser!.uid)) {
        var userData = await getUserDataForDetailPage(
            currentMatch.data()?["uid"].toString());
        print("*****************************************************");
        print(userData.toMap());
        return userData;
      }
      return null;
    } catch (e) {
      print('Error getting current matches: $e');
      return null;
    }
  }

  Future<List> getUserDataViaUId() async {
    List usersList = [];

    var previousMatchesRef = await _instance
        .collection("matches")
        .doc(currentUser!.uid)
        .collection("previousMatchesList")
        .get();
    for (var item in previousMatchesRef.docs) {
      DocumentSnapshot<Map<String, dynamic>> okunanUser =
          await FirebaseFirestore.instance.doc("users/${item["uid"]}").get();
      Map<String, dynamic>? okunanUserbilgileriMap = okunanUser.data();
      UserModel okunanUserBilgileriNesne =
          UserModel.fromMap(okunanUserbilgileriMap!);
      print(okunanUserBilgileriNesne.toString());
      usersList.add(okunanUserBilgileriNesne);
    }
    return usersList;
  }

  getTheMutualSongViaUId(uid) async {
    // Ortak bir şey dinlediğimiz kişilerle hangi şarkıda eşleştiğimizi döndüren metod.

    List tumEslesmelerinParcalari = [];
    final previousMatchesRef = await _instance
        .collection("matches")
        .doc(currentUser!.uid)
        .collection("previousMatchesList")
        .orderBy("timeStamp", descending: false)
        .get();
    for (var item in previousMatchesRef.docs) {
      if (uid == item["uid"]) {
        return item["titleOfTheSong"];
      }
      print(
          "Tüm eşleşmelerin olduğu kişilerin Şarkıları: ${tumEslesmelerinParcalari}");
    }
  }

  returnCurrentlyListeningMusicName() async {
    try {
      var isActive = false;
      var songName;
      isActive = await SpotifySdk.isSpotifyAppActive;

      var _name = SpotifySdk.subscribePlayerState();

      _name.listen((event) async {
        print("*****************************************************");
        songName = event.track!.name;
      });
      return songName.toString();
    } catch (e) {
      print("Spotify is not active or disconnected: $e");
    }
  }

  Future<Set<UserModel>> getLikedPeople() async {
    Set<UserModel> likedPeople = {};

    // Get liked people from quickMatchesList
    final quickMatchesRef = await _instance
        .collection("matches")
        .doc(currentUser!.uid)
        .collection("quickMatchesList")
        .where("isLiked", isEqualTo: true)
        .get();

    // Get liked people from previousMatchesList
    final previousMatchesRef = await _instance
        .collection("matches")
        .doc(currentUser!.uid)
        .collection("previousMatchesList")
        .where("isLiked", isEqualTo: true)
        .get();

    // Process quickMatchesList
    for (var item in quickMatchesRef.docs) {
      UserModel userModel = await getUserDataForDetailPage(item["uid"]);
      // Check if user with this ID already exists in the set
      if (!likedPeople
          .any((existingUser) => existingUser.userId == userModel.userId)) {
        likedPeople.add(userModel);
      }
    }

    // Process previousMatchesList
    for (var item in previousMatchesRef.docs) {
      UserModel userModel = await getUserDataForDetailPage(item["uid"]);
      // Check if user with this ID already exists in the set
      if (!likedPeople
          .any((existingUser) => existingUser.userId == userModel.userId)) {
        likedPeople.add(userModel);
      }
    }

    return likedPeople;
  }

  Future<List<UserModel>> getPeopleWhoLikedMe() async {
    List<UserModel> peopleWhoLikedMe = [];

    // Get all users
    QuerySnapshot usersSnapshot = await _instance.collection("users").get();

    for (var userDoc in usersSnapshot.docs) {
      String userId = userDoc.id;

      // Check if this user has liked the current user in quickMatchesList
      DocumentSnapshot quickMatchDoc = await _instance
          .collection("matches")
          .doc(userId)
          .collection("quickMatchesList")
          .doc(currentUser!.uid)
          .get();

      // Check if this user has liked the current user in previousMatchesList
      DocumentSnapshot previousMatchDoc = await _instance
          .collection("matches")
          .doc(userId)
          .collection("previousMatchesList")
          .doc(currentUser!.uid)
          .get();

      if ((quickMatchDoc.exists && quickMatchDoc.get('isLiked') == true) ||
          (previousMatchDoc.exists &&
              previousMatchDoc.get('isLiked') == true)) {
        UserModel userModel = await getUserDataForDetailPage(userId);
        peopleWhoLikedMe.add(userModel);
      }
    }

    return peopleWhoLikedMe;
  }

  void updateActiveStatus() async {
    try {
      var isActive = await SpotifySdk.isSpotifyAppActive;

      if (isActive) {
        SpotifySdk.subscribePlayerState().listen(
          (playerState) {
            if (playerState?.track != null) {
              final isPlaying = playerState?.isPaused == false;
              final songName = playerState?.track?.name;
              print("*****************************************************");
              print(songName);
              print(isPlaying);

              if (songName != null) {
                updateIsUserListening(isPlaying, songName);
                getUserDatasToMatch(songName, isPlaying);
              }
            }
          },
          onError: (e) => print('Error in Spotify subscription: $e'),
        );
      }
    } catch (e) {
      print('Error checking Spotify status: $e');
    }
  }

  Future<void> updateUserProfileImages({
    required List<String> profilePhotos,
  }) async {
    await _fireStore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .update({
      'profilePhotos': profilePhotos,
    });
  }

  Future<void> updateUserInfo({
    required String name,
    required String biography,
    required String majorInfo,
    required String clinicLocation,
  }) async {
    await _fireStore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .update({
      'name': name,
      'biography': biography,
      'majorInfo': majorInfo,
      'clinicLocation': clinicLocation,
    });
  }

  Future<void> updateTopArtists(List<Artist> artists) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    List<Map<String, dynamic>> topArtists = artists.map((artist) {
      return {
        'name': artist.name,
        'id': artist.id,
        'popularity': artist.popularity,
        'genres': artist.genres,
        'imageUrl': artist.images.isNotEmpty ? artist.images[0].url : null,
      };
    }).toList();

    await _fireStore.collection('users').doc(currentUser.uid).set({
      'topArtists': topArtists,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTopTracks(List<SpotifyTrack> tracks) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    List<Map<String, dynamic>> topTracks = tracks.map((track) {
      return {
        'id': track.id,
        'name': track.name,
        'artists': track.artists
            .map((artist) => {
                  'id': artist.id,
                  'name': artist.name,
                  'href': artist.href,
                })
            .toList(),
        'album': {
          'id': track.album.id,
          'name': track.album.name,
          'images': track.album.images
              .map((image) => {
                    'height': image.height,
                    'url': image.url,
                    'width': image.width,
                  })
              .toList(),
        },
        'previewUrl': track.previewUrl,
      };
    }).toList();

    await _fireStore.collection('users').doc(currentUser.uid).update({
      'topTracks': topTracks,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>?> getTopArtistsFromFirebase(
      String uid) async {
    try {
      print("Fetching top artists for user: $uid");
      DocumentSnapshot docSnapshot =
          await _fireStore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('topArtists')) {
          // Filter out null values and ensure correct type casting
          var topArtists = List<Map<String, dynamic>>.from(
              (data['topArtists'] as List)
                  .where((item) => item != null)
                  .map((item) => item as Map<String, dynamic>));
          print("Top artists found: ${topArtists.length}");
          return topArtists;
        }
      }
      print("No top artists found for user: $uid");
      return null;
    } catch (e) {
      print('Error fetching top artists: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getTopTracksFromFirebase(
      String uid) async {
    try {
      DocumentSnapshot docSnapshot =
          await _fireStore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('topTracks')) {
          return List<Map<String, dynamic>>.from(data['topTracks']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching top tracks: $e');
      return null;
    }
  }

  List<String> prepareGenres(List<Map<String, dynamic>> artists) {
    // Print the number of artists being processed
    print("Preparing genres from ${artists.length} artists");

    Set<String> uniqueGenres = {};

    // Process only the first 4 artists
    for (var artist in artists.take(4)) {
      if (artist['genres'] != null && artist['genres'] is List) {
        // Print debug information for each artist
        print("Artist: ${artist['name']}, Genres: ${artist['genres']}");

        // Add all genres from this artist to the set
        uniqueGenres.addAll((artist['genres'] as List).cast<String>());
      }
    }

    // Take only the first 8 unique genres
    var result = uniqueGenres.take(8).toList();

    // Print the final list of prepared genres
    print("Prepared genres: $result");

    return result;
  }

  // New methods for user preferences
  void updateAge(int age) {
    if (age < 18 || age > 100) {
      throw Exception('Age must be between 18 and 100');
    }
    _instance.collection("users").doc(currentUser!.uid).update({"age": age});
  }

  void updateGender(String gender) {
    if (!['male', 'female'].contains(gender.toLowerCase())) {
      throw Exception('Gender must be either male or female');
    }
    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"gender": gender.toLowerCase()});
  }

  void updateInterestedIn(List<String> interestedIn) {
    // Validate that all values are either 'male' or 'female'
    if (!interestedIn
        .every((gender) => ['male', 'female'].contains(gender.toLowerCase()))) {
      throw Exception('Invalid gender preference');
    }

    // Remove duplicates and convert to lowercase
    final cleanedList =
        interestedIn.map((e) => e.toLowerCase()).toSet().toList();

    _instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"interestedIn": cleanedList});
  }

  Future<void> updateUserPreferences({
    required int age,
    required String gender,
    required List<String> interestedIn,
  }) async {
    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    // Input validation
    if (age < 18 || age > 100) {
      throw Exception('Age must be between 18 and 100');
    }

    if (!['male', 'female'].contains(gender.toLowerCase())) {
      throw Exception('Gender must be either male or female');
    }

    // Validate and clean interested_in list
    final cleanedInterests = interestedIn
        .map((e) => e.toLowerCase())
        .where((e) => ['male', 'female'].contains(e))
        .toSet()
        .toList();

    if (cleanedInterests.isEmpty) {
      throw Exception('Must select at least one gender preference');
    }

    try {
      await _instance.collection("users").doc(currentUser!.uid).update({
        "age": age,
        "gender": gender.toLowerCase(),
        "interestedIn": cleanedInterests,
        "preferencesCompleted": true,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user preferences: $e');
      throw Exception('Failed to update preferences');
    }
  }

  Future<bool> hasCompletedPreferences() async {
    try {
      final doc =
          await _instance.collection("users").doc(currentUser!.uid).get();
      return doc.data()?['preferencesCompleted'] ?? false;
    } catch (e) {
      print('Error checking preferences status: $e');
      return false;
    }
  }
}
