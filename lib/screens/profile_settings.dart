import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/screens/login_page.dart';
import 'package:spotify_project/screens/own_profile_screens_for_clients.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spotify_project/screens/register_page.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({Key? key}) : super(key: key);

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  final FirestoreDatabaseService _databaseService = FirestoreDatabaseService();
  final FirebaseFirestore _instance = FirebaseFirestore.instance;
  List<String> _profilePhotos = [];
  int _currentPhotoIndex = 0;

  Future<void> uploadImageToDatabase(File image, int index) async {
    try {
      String fileName = "profile_$index.jpg";
      Reference ref = FirebaseStorage.instance
          .ref()
          .child("users")
          .child(currentUser!.uid)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(image);
      await uploadTask.whenComplete(() async {
        String url = await ref.getDownloadURL();
        if (mounted) {
          setState(() {
            if (index >= _profilePhotos.length) {
              _profilePhotos.add(url);
            } else {
              _profilePhotos[index] = url;
            }
          });
          await _databaseService.updateUserProfileImages(
            profilePhotos: _profilePhotos,
          );
        }
      });
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  Future<File?> cropImage(File imageFile) async {
    CroppedFile? croppedImage = await ImageCropper().cropImage(
      aspectRatioPresets: [CropAspectRatioPreset.square],
      sourcePath: imageFile.path,
    );
    return croppedImage != null ? File(croppedImage.path) : null;
  }

  Future<void> pickImage(ImageSource source, int index) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      File? img = File(image.path);
      img = await cropImage(img);
      if (img != null && mounted) {
        await uploadImageToDatabase(img, index);
      }
    } on PlatformException catch (e) {
      print("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => OwnProfileScreenForClients()),
          ),
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 50.sp),
        ),
        backgroundColor: Color(0xFF121212), // Dark background color
      ),
      body: StreamBuilder(
        stream: _databaseService.getProfileData(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _profilePhotos =
                List<String>.from(snapshot.data!["profilePhotos"] ?? []);

            return SingleChildScrollView(
              child: Container(
                width: screenWidth,
                decoration: const BoxDecoration(
                    color: Color(0xFF121212)), // Dark background color
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPhotoGrid(),
                    SizedBox(height: screenHeight / 55),
                    _buildTextField("Name", snapshot.data!["name"],
                        _databaseService.updateName),
                    _buildTextField("Status", snapshot.data!["biography"],
                        _databaseService.updateBiography),
                    SizedBox(
                        height: screenHeight /
                            10), // Add some space instead of Spacer
                    _buildLogoutButton(),
                    SizedBox(height: 20.h),
                    _buildDeleteAccountButton(),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPhotoTile(0),
              _buildPhotoTile(1),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPhotoTile(2),
              _buildPhotoTile(3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(int index) {
    bool hasPhoto = index < _profilePhotos.length;
    return GestureDetector(
      onTap: () => pickImage(ImageSource.gallery, index),
      child: Container(
        width: screenWidth / 2.5,
        height: screenWidth / 2.5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(13),
          image: hasPhoto
              ? DecorationImage(
                  image: NetworkImage(_profilePhotos[index]),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: !hasPhoto
            ? Icon(Icons.add_a_photo,
                size: screenWidth / 8, color: Colors.grey[600])
            : null,
      ),
    );
  }

  Widget _buildTextField(
      String label, String initialValue, Function(String) onChanged) {
    return Container(
      width: MediaQuery.of(context).size.width - 160.w,
      margin: EdgeInsets.only(bottom: screenHeight / 66),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: TextFormField(
            initialValue: initialValue,
            style: TextStyle(
                fontSize: 33.sp,
                fontFamily: "Calisto",
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: label,
              labelStyle: TextStyle(
                  fontSize: 27.sp,
                  fontFamily: "Calisto",
                  color: Color.fromARGB(129, 42, 41, 41)),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () async {
        try {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
          );
        } catch (e) {
          print("Error signing out: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to log out. Please try again.")),
          );
        }
      },
      child: Text('Logout'),
    );
  }

  Widget _buildDeleteAccountButton() {
    return ElevatedButton(
      onPressed: () => showDeleteAccountConfirmationDialog(context),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      child: Text('Delete Account'),
    );
  }

  void showDeleteAccountConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Account"),
          content: Text(
              "Are you sure you want to delete your account? This action cannot be undone."),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () {
                // TODO: Implement account deletion logic
                // For example: AuthService.deleteAccount();
                // Then navigate to login or registration screen
              },
            ),
          ],
        );
      },
    );
  }
}
