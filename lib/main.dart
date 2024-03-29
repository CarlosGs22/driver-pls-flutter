import 'dart:convert';

import 'package:driver_please_flutter/models/user.dart';
import 'package:driver_please_flutter/providers/agent_provider.dart';
import 'package:driver_please_flutter/providers/taxi_trip_provider.dart';
import 'package:driver_please_flutter/screens/dashboard_screen.dart';
import 'package:driver_please_flutter/screens/taximeter_screen.dart';
import 'package:driver_please_flutter/screens/login_screen.dart';
import 'package:driver_please_flutter/screens/trip_list_assigned_screen.dart';
import 'package:driver_please_flutter/utils/http_class.dart';
import 'package:driver_please_flutter/utils/shared_preference.dart';
import 'package:driver_please_flutter/utils/strings.dart';
import 'package:driver_please_flutter/utils/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';

class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  State<Main> createState() => _MainState();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const Main());
}

class _MainState extends State<Main> with ChangeNotifier {
  late SharedPreferences prefs;
  Future<User> getUserData() => UserPreferences().getUser();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
       _requestNotificationPermission();
  }

  getUserSessionData(BuildContext context) async {
    prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> params = {
      "username": prefs.getString("email"),
      "password": prefs.getString("password")
    };

    HttpClass.httpData(
            context,
            Uri.parse("https://www.driverplease.net/aplicacion/login.php"),
            params,
            {},
            "POST")
        .then((response) {
      if (response["status"] && response["code"] == 200) {
        List<dynamic> datauser = json.decode(response["data"]);

        Map<String, dynamic> dataInsert = {};
        dataInsert.addAll(datauser[0]);
        dataInsert.addAll(params);

        User authUser = User.fromJson(dataInsert);
        Provider.of<UserProvider>(context, listen: false).setUser(authUser);
        UserPreferences().saveUser(authUser);
        notifyListeners();
      } else {
        print("USUARIO NO ENCONTRADO");
      }
    });
  }

  
  Future<void> _requestNotificationPermission() async {
   final PermissionStatus status = await Permission.notification.request();
   if (status.isGranted) {
      // Notification permissions granted
   } else if (status.isDenied) {
      // Notification permissions denied
   } else if (status.isPermanentlyDenied) {
      // Notification permissions permanently denied, open app settings
      await openAppSettings();
   }
}

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaxiTripProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider())
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: Strings.labelAppNameTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: FutureBuilder<User>(
          future: getUserData(),
          builder: (context, snapshot) {
            String userId = snapshot.data?.id ?? "";

            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return buildCircularProgress(context);
              default:
                if (snapshot.hasError) {
                  return const LoginScreen();
                } else if (userId == "null" || userId == "") {
                  return const LoginScreen();
                } else if (snapshot.connectionState == ConnectionState.done) {
                  getUserSessionData(context);
                  return Dashboard();
                }
            }
            return const LoginScreen();
          },
        ),
        routes: {
          '/login-screen': (context) => const LoginScreen(),
          '/trip-listing-screen': (context) => const TripListAssignedScreen(),
          '/home-screen': (context) => const TaximeterScreen(),
          '/main': (context) => const Main(),
          '/dashboard': (context) => Dashboard(),
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'MX'),
        ],
      ),
    );
  }
}
