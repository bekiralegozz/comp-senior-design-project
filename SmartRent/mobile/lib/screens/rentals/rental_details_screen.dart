import 'package:flutter/material.dart';

class RentalDetailsScreen extends StatelessWidget {
  final int rentalId;

  const RentalDetailsScreen({
    Key? key,
    required this.rentalId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Details'),
      ),
      body: Center(
        child: Text('Rental Details Screen - ID: $rentalId - TODO'),
      ),
    );
  }
}
