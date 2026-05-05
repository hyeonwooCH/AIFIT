import 'package:flutter/material.dart';
import '../theme/app_theme.dart'; // 필요한 경우 테마 임포트
import 'guide_squirt.dart';

class Exercise extends StatefulWidget {
  const Exercise({super.key});

  @override
  State<Exercise> createState() => _ExerciseState();
}

class _ExerciseState extends State<Exercise> {
  // 1. 전체 실내 맨몸 운동 리스트
  final List<String> _allExercises = [
    '스쿼트',
    '런지',
    '플랭크',
    '푸쉬업',
    '버피',
    '크런치'
  ];

  // 2. 화면에 보여줄 필터링된 리스트
  List<String> _filteredExercises = [];

  // 검색창 텍스트 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 처음 화면이 열릴 때는 모든 운동을 보여줍니다.
    _filteredExercises = _allExercises;
  }

  @override
  void dispose() {
    _searchController.dispose(); // 메모리 누수 방지
    super.dispose();
  }

  // 3. 검색어에 따라 리스트를 걸러내는 함수
  void _filterExercises(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredExercises = _allExercises;
      } else {
        // 입력한 검색어가 포함된 운동만 남깁니다.
        _filteredExercises = _allExercises
            .where((exercise) => exercise.contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 홈 화면과 동일한 그라데이션 배경 적용
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // --- 상단 검색창 ---
                TextField(
                  controller: _searchController,
                  onChanged: _filterExercises, // 글자가 입력/삭제될 때마다 실행
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '운동을 검색하세요 (예: 스쿼트)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10, // 반투명 배경
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // --- 3행 2열 운동 목록 그리드 ---
                Expanded(
                  child: _filteredExercises.isEmpty
                      ? const Center(
                          child: Text(
                            '해당하는 운동이 없습니다.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          itemCount: _filteredExercises.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2개의 열
                            crossAxisSpacing: 15, // 가로 간격
                            mainAxisSpacing: 15, // 세로 간격
                            childAspectRatio: 1.3, // 박스의 가로세로 비율
                          ),
                          itemBuilder: (context, index) {
                            final exercise = _filteredExercises[index]; // 현재 운동 이름
                            
                            // InkWell이나 GestureDetector로 감싸면 터치 버튼이 됩니다!
                            return InkWell(
                              onTap: () {
                                // 만약 누른 버튼이 '스쿼트'라면 가이드 화면으로 이동
                                if (exercise == '스쿼트') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GuideScreen(exerciseName: exercise),
                                    ),
                                  );
                                } else {
                                  // 다른 운동은 아직 준비 중이라는 알림창(스낵바) 띄우기
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$exercise는 아직 준비 중입니다!')),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(20), // 터치 효과(물결) 모양 맞추기
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  exercise, // 원래 _filteredExercises[index] 였던 부분
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}