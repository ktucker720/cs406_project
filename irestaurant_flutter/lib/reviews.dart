import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Reviews', style: Theme.of(context).textTheme.headlineLarge),
        backgroundColor: Color.fromARGB(255, 230, 230, 255),
        actions: [
          IconButton(
            iconSize: 50,
            color: Colors.lightGreen,
            icon: const Icon(Icons.add),
            onPressed: () {
            },
          ),
          IconButton(
            iconSize: 50,
            color: Colors.lightBlue,
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    appBar: AppBar(
                      title: Text('My Profile', style: Theme.of(context).textTheme.displaySmall),
                      backgroundColor: Color.fromARGB(255, 230, 230, 255),
                    ),
                    actions: [
                      SignedOutAction((context) {
                        Navigator.of(context).pop();
                      })
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          children: [
            Text(
              'TODO - Review List',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}
