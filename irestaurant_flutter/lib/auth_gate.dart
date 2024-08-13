import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reviews.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    FirebaseAuth.instance
    .authStateChanges()
    .listen((User? user) {
      // Remove all reviews and reload from database when switching users
      ref.read(reviewsProvider.notifier).clear();
      if (user != null) {
        ref.read(reviewsProvider.notifier).loadFromDatabase();
      }
    });
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
            ],
            actions: [
              AuthStateChangeAction<UserCreated>((context, state) {
                // Create a database entry for the user
                FirebaseFirestore.instance.collection("users").add({"uid": FirebaseAuth.instance.currentUser!.uid});
              })
            ],
            headerMaxExtent: 170,
            headerBuilder: (context, constraints, shrinkOffset) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset('assets/images/silverware_640.png', width: 110, height: 110)
                  ),
                  Text(
                    'iRestaurant',
                    style: Theme.of(context).textTheme.headlineMedium,
                  )
                ],
              );
            },
            footerBuilder: (context, action) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'By signing in, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
          );
        }
        else {
          return FutureBuilder(
            future: FirebaseFirestore.instance.collection("users")
            .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
            .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              else {
                return const ReviewsScreen();
              }
            }
          );          
        }
      },
    );
  }
}
