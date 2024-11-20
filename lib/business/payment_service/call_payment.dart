import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:spotify_project/business/payment_service/payment_screen.dart';

class PaymentButton extends StatefulWidget {
  const PaymentButton({super.key});

  @override
  State<PaymentButton> createState() => _PaymentButtonState();
}

class _PaymentButtonState extends State<PaymentButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const PaymentScreen(
                      amount: 1.00, // This will be converted to 100 groszy
                      currency: 'PLN',
                      merchantName: 'Musee',
                    ),
                  ),
                );
              },
              child: const Text('One-time Payment (1 PLN)'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const PaymentScreen(
                      amount: 2.00, // This will be converted to 200 groszy
                      currency: 'PLN',
                      merchantName: 'Musee Premium',
                    ),
                  ),
                );
              },
              child: const Text('Subscribe (2 PLN)'),
            ),
          ),
        ],
      ),
    );
  }
}
