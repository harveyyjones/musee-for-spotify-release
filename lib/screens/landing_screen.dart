import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_project/business/business_logic.dart';
import 'package:spotify_project/screens/login_page.dart';
import 'package:spotify_project/screens/register_page.dart';
import 'package:spotify_project/screens/steppers.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class LandingPage extends StatefulWidget {
  LandingPage({Key? key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    print("LandingPage initialized");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("First frame rendered");
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Building LandingPage");
    return Scaffold(
      backgroundColor: Colors.red,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1DB954), Color(0xFF191414)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Spacer(),
                  SizedBox(height: 80.h),
                  Text(
                    "Welcome to Musee!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 56.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ).copyWith(
                      fontFamily: 'Arial',
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Text(
                    "After creating an account, just play music in Spotify and start being matched!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 26.sp,
                      color: Colors.white.withOpacity(0.9),
                    ).copyWith(
                      fontFamily: 'Arial',
                    ),
                  ),
                  Spacer(),
                  GeneralButton(
                    "Connect to Spotify",
                    LoginPage(),
                    Color(0xFF1ED760),
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GeneralButton extends StatelessWidget {
  BusinessLogic _businessLogic = BusinessLogic();
  GeneralButton(this.text, this.route, this.color);
  Color? color;
  String? text;
  var route;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          print("Button tapped");
          await _businessLogic
              .getAccessToken('b56ad9c2cf434b748466bb6adbb511ca',
                  'https://www.rubycurehealthtourism.com/')
              .then((value) =>
                  _businessLogic.connectToSpotifyRemote().then((value) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) {
                        return RegisterPage();
                      },
                    ));
                  }));
        } catch (e) {
          print("Spotify connection failed: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("Failed to connect to Spotify. Please try again.")),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (color ?? Colors.black).withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        height: 64.h,
        child: Center(
          child: Text(
            text ?? "",
            style: GoogleFonts.poppins(
              fontSize: 22.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ).copyWith(
              fontFamily: 'Arial',
            ),
          ),
        ),
      ),
    );
  }
}

class LandingElement extends StatelessWidget {
  LandingElement({super.key, required this.uri});
  String uri;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: CircleAvatar(
        radius: 80.sp,
        // backgroundImage: AssetImage("lib/assets/arcticmonkeys.jpg"),
        foregroundImage: AssetImage("lib/assets/${uri}.jpg"),
      ),
    );
  }
}
