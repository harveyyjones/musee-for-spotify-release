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

class SteppersForClients extends StatelessWidget {
  const SteppersForClients({super.key});

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
              if (_index < 1) setState(() => _index += 1);
            },
            onStepTapped: (int index) {
              setState(() => _index = index);
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: EdgeInsets.only(top: 20.h),
                child: Row(
                  children: <Widget>[
                    if (_index < 1)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child:
                            Text('Next', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1DB954), // Spotify green
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    if (_index > 0)
                      ElevatedButton(
                        onPressed: details.onStepCancel,
                        child:
                            Text('Back', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    if (_index == 1)
                      ElevatedButton(
                        onPressed: () async {
                          await uploadImagesToDatabase();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => Home()),
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: Text('Finish',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1DB954), // Spotify green
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                title: Text('Info', style: TextStyle(color: Colors.white)),
                content: _buildInfoStep(),
              ),
              Step(
                isActive: _index >= 1,
                state: _index > 1 ? StepState.complete : StepState.indexed,
                title: Text('Photos', style: TextStyle(color: Colors.white)),
                content: _buildPhotoStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStep() {
    return Column(
      children: [
        Text(
          "Complete your profile",
          style: TextStyle(
              fontSize: 24.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 20.h),
        PersonalInfoNameBar(
          controller: _controllerForName,
          methodToRun: _firestoreDatabaseService.updateName,
          label: "What's your name?",
          lineCount: 1,
        ),
        SizedBox(height: 10.h),
        Text(
          "This will be seen by everyone.",
          style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]),
        ),
      ],
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
}
