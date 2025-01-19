import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/exam.dart';

class ScheduleScreen extends StatefulWidget {
  final List<Exam> exams;

  ScheduleScreen({required this.exams});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDay = DateTime.now();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('app_icon');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);

    tz.initializeTimeZones();
  }

  Future<void> _scheduleNotification(String subject, String location, DateTime dateTime) async {
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(dateTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      0,
      'Reminder for $subject',
      'Location: $location',
      scheduledTime,
      platformDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Updated parameter
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exam Schedule')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _selectedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
          ),
          Expanded(
            child: ListView(
              children: widget.exams
                  .where((exam) => isSameDay(exam.date, _selectedDay))
                  .map((exam) => ListTile(
                title: Text(exam.subject),
                subtitle: Text(
                  '${exam.date.hour}:${exam.date.minute.toString().padLeft(2, '0')} - ${exam.location}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'Edit') {
                      _editExamDialog(exam);
                    } else if (value == 'Delete') {
                      setState(() {
                        widget.exams.remove(exam);
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'Edit', child: Text('Edit')),
                    PopupMenuItem(value: 'Delete', child: Text('Delete')),
                  ],
                ),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExamDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddExamDialog() {
    TextEditingController subjectController = TextEditingController();
    TextEditingController locationController = TextEditingController();
    TextEditingController latController = TextEditingController();
    TextEditingController lngController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subjectController, decoration: InputDecoration(labelText: 'Subject')),
            TextField(controller: locationController, decoration: InputDecoration(labelText: 'Location')),
            TextField(controller: latController, decoration: InputDecoration(labelText: 'Latitude')),
            TextField(controller: lngController, decoration: InputDecoration(labelText: 'Longitude')),
            ElevatedButton(
              onPressed: () async {
                selectedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
              },
              child: Text('Select Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (selectedTime != null) {
                final DateTime dateTime = DateTime(
                  _selectedDay.year,
                  _selectedDay.month,
                  _selectedDay.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );
                final newExam = Exam(
                  subject: subjectController.text,
                  date: dateTime,
                  location: locationController.text,
                  latitude: double.parse(latController.text),
                  longitude: double.parse(lngController.text),
                );
                setState(() {
                  widget.exams.add(newExam);
                });
                _scheduleNotification(
                  subjectController.text,
                  locationController.text,
                  dateTime,
                );
              }
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editExamDialog(Exam exam) {
    TextEditingController subjectController = TextEditingController(text: exam.subject);
    TextEditingController locationController = TextEditingController(text: exam.location);
    TextEditingController latController = TextEditingController(text: exam.latitude.toString());
    TextEditingController lngController = TextEditingController(text: exam.longitude.toString());
    TimeOfDay initialTime = TimeOfDay.fromDateTime(exam.date);
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subjectController, decoration: InputDecoration(labelText: 'Subject')),
            TextField(controller: locationController, decoration: InputDecoration(labelText: 'Location')),
            TextField(controller: latController, decoration: InputDecoration(labelText: 'Latitude')),
            TextField(controller: lngController, decoration: InputDecoration(labelText: 'Longitude')),
            ElevatedButton(
              onPressed: () async {
                selectedTime = await showTimePicker(
                  context: context,
                  initialTime: initialTime,
                );
              },
              child: Text('Select Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (selectedTime != null) {
                setState(() {
                  exam.subject = subjectController.text;
                  exam.location = locationController.text;
                  exam.latitude = double.parse(latController.text);
                  exam.longitude = double.parse(lngController.text);
                  exam.date = DateTime(
                    _selectedDay.year,
                    _selectedDay.month,
                    _selectedDay.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                });
              }
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
