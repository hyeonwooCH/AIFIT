import joblib

# 🔥 아까 복사한 경로를 아래 따옴표 안에 붙여넣으세요
path = '/Applications/AIFIT/ai_fit/lib/ml/scaler.pkl'

try:
    scaler = joblib.load(path)
    print("\n✅ 아래 숫자들을 복사해서 PostureInferrer에 넣으세요!")
    print("-" * 40)
    print("Means:", scaler.mean_.tolist())
    print("\nScales:", scaler.scale_.tolist())
    print("-" * 40)
except Exception as e:
    print(f"❌ 에러 발생: {e}")