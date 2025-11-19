import 'package:flutter/material.dart';

class CreateRentalScreen extends StatelessWidget {
  final String assetId;

  const CreateRentalScreen({
    Key? key,
    required this.assetId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Rental'),
      ),
      body: Center(
        child: Text('Create Rental Screen - Asset ID: $assetId - TODO'),
      ),
    );
  }
}
