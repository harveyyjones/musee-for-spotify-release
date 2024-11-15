import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spotify_project/Business_Logic/firestore_database_service.dart';
import 'package:spotify_project/Helpers/helpers.dart';
import 'package:spotify_project/business/Spotify_Logic/constants.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_artists.dart';
import 'package:spotify_project/business/Spotify_Logic/services/fetch_top_10_tracks_of_the_user.dart';
import 'package:spotify_project/main.dart';
import 'package:spotify_project/screens/quick_match_screen.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/widgets/personal_info_bar.dart';

TextEditingController _controllerForName = TextEditingController();
TextEditingController _controllerForMajorInfo = TextEditingController();
TextEditingController _controllerForClinicLocation = TextEditingController();
TextEditingController _controllerForBiography = TextEditingController();
TextEditingController _controllerForClinicName = TextEditingController();
var profilePhoto;

class Steppers extends StatelessWidget {
  const Steppers({super.key});

  static const String _title = '';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: _title,
      home: Scaffold(
        body: Center(
          child: SteppersForClientsWidget(),
        ),
      ),
    );
  }
}

class SteppersForClientsWidget extends StatefulWidget {
  const SteppersForClientsWidget({Key? key}) : super(key: key);

  @override
  State<SteppersForClientsWidget> createState() =>
      SteppersForClientsWidgetState();
}

class SteppersForClientsWidgetState extends State<SteppersForClientsWidget> {
  int _index = 0;
  List<File> _images = [];
  final FirestoreDatabaseService _firestoreDatabaseService =
      FirestoreDatabaseService();

  // Add new controllers and state variables
  final TextEditingController _ageController = TextEditingController();
  String _selectedGender = '';
  List<String> _interestedIn = [];

  Future<File?> cropImage(File imageFile) async {
    CroppedFile? croppedImage = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
    );
    return croppedImage != null ? File(croppedImage.path) : null;
  }

  Future pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      File? img = File(image.path);
      img = await cropImage(img);
      if (img != null && _images.length < 4) {
        setState(() {
          _images.add(img!);
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future uploadImagesToDatabase() async {
    if (_images.isEmpty) return;

    List<String> profilePhotos = [];

    for (var i = 0; i < _images.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child("users")
          .child(currentUser!.uid)
          .child("profile_$i.jpg");

      UploadTask uploadTask = ref.putFile(_images[i]);
      await uploadTask.whenComplete(() async {
        String url = await ref.getDownloadURL();
        profilePhotos.add(url);
      });
    }

    // Update user data with profilePhotos
    await _firestoreDatabaseService.updateUserProfileImages(
      profilePhotos: profilePhotos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SafeArea(
        child: Theme(
          data: ThemeData(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF1DB954), // Spotify green
              secondary: Color(0xFF1DB954), // Spotify green
              surface: Color(0xFF121212),
              background: Color(0xFF121212),
            ),
            canvasColor: Color(0xFF121212),
          ),
          child: Stepper(
            type: StepperType.horizontal,
            currentStep: _index,
            onStepCancel: () {
              if (_index > 0) setState(() => _index -= 1);
            },
            onStepContinue: () {
              if (_validateCurrentStep()) {
                if (_index < 4) {
                  setState(() => _index += 1);
                }
              }
            },
            onStepTapped: (int index) {
              setState(() => _index = index);
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: EdgeInsets.only(top: 20.h),
                child: Row(
                  children: <Widget>[
                    if (_index > 0)
                      Padding(
                        padding: EdgeInsets.only(right: 16.w),
                        child: ElevatedButton(
                          onPressed: details.onStepCancel,
                          child: Text('Back',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    if (_index < 4)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child:
                            Text('Next', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1DB954),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (_index == 4)
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _firestoreDatabaseService.saveUser(
                              name: _controllerForName.text,
                              age: int.parse(_ageController.text),
                              gender: _selectedGender,
                              interestedIn: _interestedIn,
                            );
                            await uploadImagesToDatabase();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => Home()),
                              (Route<dynamic> route) => false,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error saving profile: ${e.toString()}')),
                            );
                          }
                        },
                        child: Text('Finish',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1DB954),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                isActive: _index >= 0,
                state: _index > 0 ? StepState.complete : StepState.indexed,
                title: Text('Name', style: TextStyle(color: Colors.white)),
                content: _buildNameStep(),
              ),
              Step(
                isActive: _index >= 1,
                state: _index > 1 ? StepState.complete : StepState.indexed,
                title: Text('Age', style: TextStyle(color: Colors.white)),
                content: _buildAgeStep(),
              ),
              Step(
                isActive: _index >= 2,
                state: _index > 2 ? StepState.complete : StepState.indexed,
                title: Text('Gender', style: TextStyle(color: Colors.white)),
                content: _buildGenderStep(),
              ),
              Step(
                isActive: _index >= 3,
                state: _index > 3 ? StepState.complete : StepState.indexed,
                title: Text('Interest', style: TextStyle(color: Colors.white)),
                content: _buildInterestsStep(),
              ),
              Step(
                isActive: _index >= 4,
                title: Text('Photos', style: TextStyle(color: Colors.white)),
                content: _buildPhotoStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Column(
      children: [
        Text(
          "What's your name?",
          style: TextStyle(
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        PersonalInfoNameBar(
          controller: _controllerForName,
          methodToRun: _firestoreDatabaseService.updateName,
          label: "Your name",
          lineCount: 1,
        ),
        SizedBox(height: 10.h),
        Text(
          "This will be shown to others",
          style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildAgeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "How old are you?",
          style: TextStyle(
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF282828),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(16),
          child: TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white, fontSize: 24.sp),
            decoration: InputDecoration(
              labelText: 'Enter your age',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your gender?",
          style: TextStyle(
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        Row(
          children: [
            Radio<String>(
              value: 'male',
              groupValue: _selectedGender,
              onChanged: (value) => setState(() => _selectedGender = value!),
            ),
            Text('Male', style: TextStyle(color: Colors.white)),
            Radio<String>(
              value: 'female',
              groupValue: _selectedGender,
              onChanged: (value) => setState(() => _selectedGender = value!),
            ),
            Text('Female', style: TextStyle(color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Who are you interested in?",
          style: TextStyle(
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF282828),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInterestOption('male', 'Men'),
              Divider(color: Colors.white12),
              _buildInterestOption('female', 'Women'),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          "Select all that apply",
          style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildInterestOption(String value, String label) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 18.sp),
      ),
      leading: Checkbox(
        value: _interestedIn.contains(value),
        onChanged: (checked) {
          setState(() {
            if (checked!) {
              _interestedIn.add(value);
            } else {
              _interestedIn.remove(value);
            }
          });
        },
        activeColor: Color(0xFF1DB954),
      ),
      onTap: () {
        setState(() {
          if (_interestedIn.contains(value)) {
            _interestedIn.remove(value);
          } else {
            _interestedIn.add(value);
          }
        });
      },
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      children: [
        Text(
          "Add your best photos",
          style: TextStyle(
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _images.length > index
                  ? null
                  : pickImage(ImageSource.gallery),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _images.length > index
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                Image.file(_images[index], fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _images.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Icon(Icons.add_photo_alternate,
                        color: Colors.grey, size: 50),
              ),
            );
          },
        ),
        SizedBox(height: 20.h),
        Text(
          "Add up to 4 photos to your profile",
          style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]),
        ),
      ],
    );
  }

  List<Step> get stepList => <Step>[
        Step(
          isActive: true,
          state: _index > 0 ? StepState.complete : StepState.indexed,
          title: const Text(''),
          content: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.all(35),
                  child: Text(
                    "To help you complete your profile you should answer some quick questions.",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400),
                  ),
                ),
                SizedBox(
                  height: screenHeight / 33,
                ),
                PersonalInfoNameBar(
                  controller: _controllerForName,
                  methodToRun: _firestoreDatabaseService.updateName,
                  label: "What's your name?",
                  lineCount: 1,
                ),
                const Text(
                  "This will be seen by everyone.",
                  style: TextStyle(fontSize: 22),
                ),
              ],
            ),
          ),
        ),
      ];

  void callSnackbar(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 30.h),
      backgroundColor: Color.fromARGB(255, 65, 221, 4),
      duration: Duration(milliseconds: 500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: SizedBox(
        width: 40.w,
        height: 40.h,
        child: Center(
          child: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      ),
    ));
  }

  bool _validateCurrentStep() {
    switch (_index) {
      case 0: // Name step
        if (_controllerForName.text.isEmpty) {
          _showError('Please enter your name');
          return false;
        }
        return true;

      case 1: // Age step
        if (_ageController.text.isEmpty ||
            int.tryParse(_ageController.text) == null) {
          _showError('Please enter a valid age');
          return false;
        }
        int age = int.parse(_ageController.text);
        if (age < 18 || age > 100) {
          _showError('Age must be between 18 and 100');
          return false;
        }
        return true;

      case 2: // Gender step
        if (_selectedGender.isEmpty) {
          _showError('Please select your gender');
          return false;
        }
        return true;

      case 3: // Interests step
        if (_interestedIn.isEmpty) {
          _showError('Please select at least one interest');
          return false;
        }
        return true;

      case 4: // Photos step
        if (_images.isEmpty) {
          _showError('Please add at least one photo');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  // Add initialization and disposal of controllers
  @override
  void initState() {
    super.initState();
    // Pre-fill data if user is editing profile
    _loadExistingUserData();
  }

  @override
  void dispose() {
    _controllerForName.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingUserData() async {
    try {
      final userData = await _firestoreDatabaseService.getUserData();
      if (userData != null) {
        setState(() {
          _controllerForName.text = userData.name ?? '';
          _ageController.text = userData.age?.toString() ?? '';
          _selectedGender = userData.gender ?? '';
          _interestedIn = List<String>.from(userData.interestedIn ?? []);
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Add methods for image handling
  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;

      File? img = File(image.path);
      img = await _cropImage(img);

      if (img != null && _images.length < 4) {
        setState(() => _images.add(img!));
      }
    } catch (e) {
      _showError('Error picking image: ${e.toString()}');
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      CroppedFile? croppedImage = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      return croppedImage != null ? File(croppedImage.path) : null;
    } catch (e) {
      _showError('Error cropping image: ${e.toString()}');
      return null;
    }
  }

  Future<void> _uploadImages() async {
    if (_images.isEmpty) return;

    try {
      List<String> photoUrls = [];
      for (var i = 0; i < _images.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("users")
            .child(currentUser!.uid)
            .child("profile_$i.jpg");

        final uploadTask = ref.putFile(_images[i]);
        final snapshot = await uploadTask.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();
        photoUrls.add(url);
      }

      await _firestoreDatabaseService.updateUserProfileImages(
        profilePhotos: photoUrls,
      );
    } catch (e) {
      _showError('Error uploading images: ${e.toString()}');
    }
  }

  // Add final submission method
  Future<void> _finishProfileSetup() async {
    await _handleAsyncOperation(
      () async {
        // Upload images first
        await _uploadImages();

        // Fetch and save top artists
        try {
          final spotifyService = SpotifyServiceForTopArtists(accessToken);
          final artists = await spotifyService.fetchArtists(accessToken);
          await _firestoreDatabaseService.updateTopArtists(artists.items);
          print('Artists saved successfully');
          print(artists.items);
          print('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
        } catch (e) {
          print('Error fetching/saving artists: $e');
        }

        // Fetch and save top tracks
        try {
          final tracks =
              await SpotifyServiceForTracks(accessToken).fetchTracks();

          await _firestoreDatabaseService.updateTopTracks(tracks);
          print('Tracks saved successfully');
          print(tracks);
          print('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
        } catch (e) {
          print('Error fetching/saving tracks: $e');
        }

        // Save user data
        await _firestoreDatabaseService.saveUser(
          name: _controllerForName.text,
          age: int.parse(_ageController.text),
          gender: _selectedGender,
          interestedIn: _interestedIn,
        );

        // Navigate after successful completion
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Home()),
          (Route<dynamic> route) => false,
        );
      },
      'Profile setup completed successfully!',
    );
  }

  // Add custom button builder
  Widget _buildStepperControls() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        children: [
          if (_index > 0)
            ElevatedButton(
              onPressed: () => setState(() => _index -= 1),
              child: Text('Back', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          SizedBox(width: 16.w),
          ElevatedButton(
            onPressed: _index == 4
                ? _finishProfileSetup
                : () {
                    if (_validateCurrentStep()) {
                      setState(() => _index += 1);
                    }
                  },
            child: Text(
              _index == 4 ? 'Finish' : 'Next',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1DB954),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Error handling methods
  void _showError(String message) {
    _showSnackBar(
      message: message,
      backgroundColor: Colors.red[700]!,
      icon: Icons.error_outline,
    );
  }

  void _showSuccess(String message) {
    _showSnackBar(
      message: message,
      backgroundColor: Color(0xFF1DB954),
      icon: Icons.check_circle_outline,
    );
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Loading indicator
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF282828),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                ),
                SizedBox(height: 16),
                Text(
                  'Please wait...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to handle async operations with loading state
  Future<void> _handleAsyncOperation(
    Future<void> Function() operation,
    String successMessage,
  ) async {
    try {
      _showLoadingDialog();
      await operation();
      Navigator.of(context).pop(); // Dismiss loading dialog
      _showSuccess(successMessage);
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loading dialog
      _showError(e.toString());
    }
  }
}
