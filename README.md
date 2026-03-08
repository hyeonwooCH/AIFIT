# AIFIT

**1. 프로젝트 개요**

아이핏은 혼자 운동하는 사용자들이 올바른 자세로 운동할 수 있도록 **실시간 피드백**을 제공하고, 
운동 데이터를 분석하여 보호자나 사용자에게 **인공지능 기반의 통찰력 있는 리포트**를 전달하는 스마트 헬스케어 플랫폼이다.

# Directory Hierarchy
📂 unzipped_data
  ├── 📂 원천데이터 (Source Images)
  │     ├── 📂 {ID}-{Type}-{Z-Angle}_A  # 시점 A (예: 033-1-1-21-Z17_A)
  │     ├── 📂 {ID}-{Type}-{Z-Angle}_B  # 시점 B
  │     ├── 📂 {ID}-{Type}-{Z-Angle}_C  # 시점 C
  │     ├── 📂 {ID}-{Type}-{Z-Angle}_D  # 시점 D
  │     └── 📂 {ID}-{Type}-{Z-Angle}_E  # 시점 E
  └── 📂 라벨링데이터 (Labels)
        └── 📄 {ID}-{Type}-{Z-Angle}.json  # 각 시퀀스별 통합 라벨링 데이터 (총 120개)

# Dataset Statistics
총 이미지 수: "19,195장", 원천 데이터(JPEG/PNG)
총 라벨링 수: 120개, 동작/시퀀스별 JSON 파일
시점 구성: 5개 (A~E), 각 동작당 5가지 각도 동시 촬영
시퀀스당 이미지: 약 32장, 동작의 흐름을 파악하는 연속 프레임
