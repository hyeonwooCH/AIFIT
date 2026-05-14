import 'package:flutter/material.dart';
import 'screens/home.dart'; // 기존에 만든 홈 화면
import 'screens/exercise.dart'; // 운동 페이지 화면
import 'screens/calendar.dart';

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  // 현재 선택된 탭의 인덱스 (기본값 2: 홈)
  int _selectedIndex = 2;

  // 이동할 화면들 리스트
  final List<Widget> _screens = [
    const Exercise(),
    const Calendar(),
    const Home(), // 민지님이 만든 화려한 홈 대시보드!
    const Center(child: Text('식단 관리 페이지', style: TextStyle(color: Colors.white, fontSize: 20))),
    const Center(child: Text('게임 모드 페이지', style: TextStyle(color: Colors.white, fontSize: 20))),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // 탭을 누를 때마다 화면 번호를 바꿔줌
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 현재 번호에 맞는 화면을 본체(body)에 보여줍니다.
      body: _screens[_selectedIndex],

      // 하단 네비게이션 바
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141E30), // 앱 테마 배경색과 통일
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 필요한 높이만큼만 차지
          children: [
            const Divider(color: Colors.white10, thickness: 1, height: 1), // 하단 구분선
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.transparent, // 컨테이너 색상을 따라감
                iconSize: 30,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.lightBlueAccent,
                unselectedItemColor: Colors.white54,
                selectedLabelStyle: const TextStyle(fontSize: 14, height: 2),
                unselectedLabelStyle: const TextStyle(fontSize: 14, height: 2),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: '운동'),
                  BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: '기록'),
                  BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
                  BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: '식단'),
                  BottomNavigationBarItem(icon: Icon(Icons.videogame_asset_outlined), label: '게임'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}