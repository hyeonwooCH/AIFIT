import 'package:flutter/material.dart';
import '../widgets/info_card.dart';
import '../widgets/stat_circle.dart';
import '../widgets/today_workout.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  // [중요] build 메서드 '밖'으로 꺼냈습니다!
  // 상단바 (알림 / 로고 / 마이페이지)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.notifications_none, size: 30),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'AI',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent,),
                ),
                TextSpan(
                  text: 'FIT',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white,),
                ),
              ],
            ),
          ),
          const Icon(Icons.person_outline, size: 30),
        ],
      ),
    );
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(), // 상단 로고 (아래 정의된 메서드 호출)

                // 구분선 추가
                const SizedBox(height: 0),
                const Divider(
                  color: Colors.white,
                  thickness: 1,
                  indent: 0,
                  endIndent: 0,
                ),
                const SizedBox(height: 5),
                
                // 1. 인사말 카드
                InfoCard(
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5, bottom: 5, left: 15),
                        child: CircleAvatar(
                          radius: 35, 
                          backgroundColor: Colors.white24, 
                          child: Icon(Icons.person, size: 40, color: Colors.white)
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text('아이핏님, 안녕하세요!', 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),

                // 2. 오늘의 성취도 카드 (제목 추가 버전)
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // [핵심] 제목 왼쪽 정렬
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 15),
                        child: Text(
                          '오늘의 성취도',
                          style: TextStyle(
                            fontSize: 23, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10), // 제목과 원 사이 간격
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          StatCircle(label: "섭취 칼로리", value: "1500", subValue: "/ 2200kcal", color: Colors.blue),
                          StatCircle(label: "소모 칼로리", value: "550", subValue: "/ 800kcal", color: Colors.orange),
                          StatCircle(label: "운동 시간", value: "1시간 20분", subValue: "/ 2시간", color: Colors.green),
                        ],
                      ),
                    ],             
                  ),
                ),

                // 3. 연속달성, 오늘의 포즈횟수
                Row(
                  children: [
                    Expanded(
                      child: InfoCard(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('연속 달성', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              SizedBox(height: 5),
                              Text('🔥 7일째', style: TextStyle(fontSize: 20, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),

                    Expanded(
                      child: InfoCard(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('오늘의 Perfect 포즈', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              SizedBox(height: 5),
                              Text('스쿼트 42회', style: TextStyle(fontSize: 20, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 4. 오늘의 운동 카드
                InfoCard(
                  child: Row(
                    children: [
                      // 왼쪽 구역 (제목 + 구분선 + 4개 박스)
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Text(
                                '오늘의 운동',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Divider(color: Colors.white70, thickness: 1),
                            const SizedBox(height: 5),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const TodayWorkout(text: '스쿼트'),
                                const TodayWorkout(text: '런지'),
                                const TodayWorkout(text: '플랭크'),
                                const TodayWorkout(text: '푸쉬업'),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double circleSize = constraints.maxWidth;
                            return Center(
                              child: StatCircle(
                                label: "",
                                value: "75%",
                                subValue: "진행중",
                                color: Colors.lightBlueAccent,
                                size: circleSize * 0.9,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(), // 남는 아래 공간을 채워줌
              ],
            ),
          ),
        ),
      ),
    );
  }
} // Home 클래스 끝