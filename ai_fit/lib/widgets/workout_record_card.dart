import 'package:flutter/material.dart';

class WorkoutRecordCard extends StatelessWidget {
  final String title;
  final String time;
  final int sets;
  final int reps;

  const WorkoutRecordCard({
    super.key,
    required this.title,
    required this.time,
    required this.sets,
    required this.reps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white54, size: 16),
              const SizedBox(width: 5),
              Text(time, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              Text(
                '$sets세트 / $reps회',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}