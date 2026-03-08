# 🏋️‍♂️ AIFIT (아이핏)

## 💡 프로젝트 개요 (Project Overview)
**AIFIT(아이핏)**은 혼자 운동하는 사용자들이 올바른 자세로 운동할 수 있도록 **실시간 피드백**을 제공하는 스마트 헬스케어 플랫폼입니다. 
수집된 운동 데이터를 정밀하게 분석하여 사용자 본인 또는 보호자에게 **인공지능 기반의 통찰력 있는 리포트**를 전달합니다.

---

## 📁 데이터셋 구조 (Directory Hierarchy)
데이터셋은 원천 데이터(다시점 이미지)와 라벨링 데이터(통합 JSON)로 분리되어 관리됩니다.

```text
📂 unzipped_data
 ├── 📂 원천데이터 (Source Images)
 │    ├── 📂 {ID}-{Type}-{Z-Angle}_A  # 시점 A (예: 033-1-1-21-Z17_A)
 │    ├── 📂 {ID}-{Type}-{Z-Angle}_B  # 시점 B
 │    ├── 📂 {ID}-{Type}-{Z-Angle}_C  # 시점 C
 │    ├── 📂 {ID}-{Type}-{Z-Angle}_D  # 시점 D
 │    └── 📂 {ID}-{Type}-{Z-Angle}_E  # 시점 E
 └── 📂 라벨링데이터 (Labels)
      └── 📄 {ID}-{Type}-{Z-Angle}.json  # 각 시퀀스별 통합 라벨링 데이터 (총 120개)
