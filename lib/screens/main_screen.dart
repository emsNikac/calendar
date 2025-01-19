import 'package:flutter/material.dart';
import 'schedule_screen.dart';
import 'map_screen.dart';
import '../models/exam.dart';

class MainScreen extends StatelessWidget {
  final List<Exam> exams = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exam Scheduler')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduleScreen(exams: exams),
                ),
              ),
              child: Text('View Schedule'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapScreen(exams: exams),
                ),
              ),
              child: Text('View Map'),
            ),
          ],
        ),
      ),
    );
  }
}
