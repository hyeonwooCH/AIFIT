import tensorflow as tf
import joblib
import numpy as np

# 1. Keras 모델을 모바일용 TFLite 모델로 변환
model_names = ['model_label_spine', 'model_label_knee']

for name in model_names:
    # 기존 케라스 모델 불러오기 (.keras 파일이 있는 폴더에서 실행하세요)
    model = tf.keras.models.load_model(f'{name}.keras')
    
    # TFLite 형식으로 변환 설정
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    # 변환된 파일(.tflite) 저장
    with open(f'{name}.tflite', 'wb') as f:
        f.write(tflite_model)
    print(f"✅ {name}.tflite 변환 완료!")

# 2. Scaler 데이터 추출 (StandardScaler 기준)
# scaler.pkl 파일이 있는 폴더에서 실행하세요
scaler = joblib.load('scaler.pkl')

print("\n🎯 [Dart 코드의 _mean에 복사하세요]")
print(scaler.mean_.tolist())

print("\n🎯 [Dart 코드의 _var에 복사하세요]")
print(scaler.var_.tolist())