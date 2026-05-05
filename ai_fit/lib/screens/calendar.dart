import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

// 우리가 만든 커스텀 위젯들 불러오기!
import '../widgets/workout_record_card.dart';
import '../widgets/custom_input_field.dart';

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime _focusedDay = DateTime(2026, 4, 5);
  DateTime? _selectedDay = DateTime(2026, 4, 5);
  bool _isAdding = false;

  final Map<DateTime, List<Map<String, dynamic>>> _dummyWorkouts = {
    DateTime.utc(2026, 4, 5): [
      {'title': '스쿼트', 'time': '18:30 - 19:10', 'reps': 15, 'sets': 4}
    ]
  };

  List<Map<String, dynamic>> _getWorkoutsForDay(DateTime day) {
    DateTime normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _dummyWorkouts[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: _isAdding ? _buildAddWorkoutForm() : _buildCalendarView(),
          ),
        ),
      ),
    );
  }

  // --- 1. 달력 & 리스트 뷰 ---
  Widget _buildCalendarView() {
    final workouts = _selectedDay != null ? _getWorkoutsForDay(_selectedDay!) : [];

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.white70),
            weekendStyle: TextStyle(color: Colors.redAccent),
          ),
          calendarStyle: CalendarStyle(
            defaultTextStyle: const TextStyle(color: Colors.white),
            weekendTextStyle: const TextStyle(color: Colors.redAccent),
            outsideTextStyle: const TextStyle(color: Colors.white30),
            selectedDecoration: const BoxDecoration(color: Colors.lightBlueAccent, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            markerDecoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
          ),
          eventLoader: _getWorkoutsForDay,
        ),
        
        const SizedBox(height: 20),

        if (_selectedDay != null)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay!),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Divider(color: Colors.white30, height: 30),
                      
                      Expanded(
                        child: workouts.isEmpty
                            ? const Center(child: Text('기록된 운동이 없습니다.', style: TextStyle(color: Colors.white54)))
                            : ListView.builder(
                                itemCount: workouts.length,
                                itemBuilder: (context, index) {
                                  final w = workouts[index];
                                  // 분리한 위젯 사용!
                                  return WorkoutRecordCard(
                                    title: w['title'],
                                    time: w['time'],
                                    sets: w['sets'],
                                    reps: w['reps'],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () {
                        setState(() => _isAdding = true);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.lightBlueAccent,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.add, color: Colors.black, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- 2. 일정 추가 폼 뷰 ---
  Widget _buildAddWorkoutForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => setState(() => _isAdding = false),
            ),
            const Text(
              '새 운동 기록',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 분리한 입력창 위젯 사용!
                  const CustomInputField(label: '운동 이름', hint: '예: 푸쉬업'),
                  const SizedBox(height: 20),
                  
                  const Text('운동 시간', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Expanded(child: CustomInputField(label: '', hint: '시작 (예: 18:00)')),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('~', style: TextStyle(color: Colors.white))),
                      Expanded(child: CustomInputField(label: '', hint: '종료 (예: 18:30)')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: const [
                      Expanded(child: CustomInputField(label: '세트 수', hint: '예: 3', isNumber: true)),
                      SizedBox(width: 20),
                      Expanded(child: CustomInputField(label: '반복 횟수 (1세트당)', hint: '예: 15', isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        setState(() => _isAdding = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('운동이 기록되었습니다!')),
                        );
                      },
                      child: const Text('기록 저장하기', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}