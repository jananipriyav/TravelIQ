import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://imjdulwscolpgoxtjtgo.supabase.co',
    anonKey: 'sb_publishable_X4xbfasxjsehsMmESOimKA_MQeVAAAt',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    const seedColor = Color(0xFF3B5BDB); // indigo-blue, travel/trust feel
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor);
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    return MaterialApp(
      title: 'Smart Travel Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FC),
        textTheme: baseTextTheme,
        splashColor: colorScheme.primary.withOpacity(0.08),
        highlightColor: colorScheme.primary.withOpacity(0.04),

        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 2,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          shadowColor: Colors.black.withOpacity(0.08),
          surfaceTintColor: Colors.white,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: colorScheme.primary, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),

        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),

        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.primary.withOpacity(0.08),
          labelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),

        // Every AlertDialog / confirmation popup in the app picks this up
        // automatically — rounded corners instead of the default sharp
        // Material look.
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B1F3B),
          ),
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            color: Colors.black87,
          ),
        ),

        // Every SnackBar (errors, confirmations) picks this up too —
        // floating, rounded, consistent with the rest of the app.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B1F3B),
          contentTextStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actionTextColor: colorScheme.primary.computeLuminance() > 0.5
              ? colorScheme.primary
              : Colors.white,
        ),

        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colorScheme.primary,
        ),

        dividerTheme: DividerThemeData(
          color: Colors.grey.shade200,
          thickness: 1,
        ),

        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F3B).withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 11.5),
        ),

        navigationBarTheme: NavigationBarThemeData(
          height: 66,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.15),
          surfaceTintColor: Colors.white,
          indicatorColor: colorScheme.primary.withOpacity(0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colorScheme.primary : Colors.grey.shade600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? colorScheme.primary : Colors.grey.shade500,
            );
          }),
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          extendedTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      initialRoute: session != null ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}