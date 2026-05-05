import 'package:flutter/material.dart';

class SquatCounterDisplay extends StatelessWidget {
  final int count;
  final String state;

  const SquatCounterDisplay({
    super.key,
    required this.count,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 100,
              fontWeight: FontWeight.w900,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.yellowAccent,
            child: Text(
              'STATE: $state',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}