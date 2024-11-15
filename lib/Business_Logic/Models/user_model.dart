import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String? userId;
  String? eMail;
  String? name;
  String? majorInfo;
  String? biography;
  String? clinicLocation;
  String? gender;
  String? clinicName;
  String? phoneNumber;
  bool? clinicOwner;
  String? profilePhotoURL; // New property for single profile photo URL
  List<String> profilePhotos; // List to store multiple profile photos
  DateTime? createdAt;
  DateTime? updatedAt;
  String? songName;
  bool? isUserListening;
  int? age;
  List<String> interestedIn;

  UserModel({
    this.userId,
    this.name,
    this.eMail,
    this.majorInfo,
    this.clinicLocation,
    this.profilePhotoURL, // Add this parameter
    this.profilePhotos = const [], // Default to an empty list
    this.biography,
    this.clinicName,
    this.gender,
    this.createdAt,
    this.updatedAt,
    this.phoneNumber,
    this.clinicOwner,
    this.songName,
    this.isUserListening,
    this.age,
    this.interestedIn = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      "biography": biography ?? "",
      "createdAt": createdAt ?? FieldValue.serverTimestamp(),
      "eMail": eMail,
      "majorInfo": majorInfo,
      "clinicLocation": clinicLocation,
      "name": name,
      "clinicName": clinicName,
      "userId": userId,
      "profilePhotoURL": profilePhotoURL, // Add this line
      "profilePhotos": profilePhotos, // Store list of photos
      "updatedAt": updatedAt ?? FieldValue.serverTimestamp(),
      "phoneNumber": phoneNumber,
      "clinicOwner": clinicOwner,
      "songName": songName,
      "isUserListening": isUserListening,
      "gender": gender,
      "age": age,
      "interestedIn": interestedIn,
    };
  }

  // Named constructor to convert map data to a UserModel instance
  UserModel.fromMap(Map<String, dynamic> map)
      : userId = map["userId"],
        eMail = map["eMail"],
        name = map["name"],
        majorInfo = map["majorInfo"],
        profilePhotoURL = map["profilePhotoURL"], // Add this line
        profilePhotos = List<String>.from(map["profilePhotos"] ?? []),
        clinicLocation = map["clinicLocation"],
        biography = map["biography"],
        createdAt = (map["createdAt"] as Timestamp).toDate(),
        updatedAt = (map["updatedAt"] as Timestamp).toDate(),
        phoneNumber = map["phoneNumber"],
        clinicName = map["clinicName"],
        clinicOwner = map["clinicOwner"],
        songName = map["songName"],
        isUserListening = map["isUserListening"],
        gender = map["gender"],
        age = map["age"],
        interestedIn = List<String>.from(map["interestedIn"] ?? []);
}
