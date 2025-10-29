import 'package:flutter/material.dart';

class MyAssetsScreen extends StatelessWidget {
  const MyAssetsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assets'),
      ),
      body: const Center(
        child: Text('My Assets Screen - TODO'),
      ),
    );
  }
}
