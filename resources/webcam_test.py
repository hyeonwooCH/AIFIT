"""
squat_realtime.py
=================
실시간 웹캠 스쿼트 자세 분석 + 음성 카운팅
- 캘리브레이션 단계: 전신 감지 후 영점 설정
- 위치 이탈 시 카운팅/분석 중단
- 평가 조건: 척추 중립 / 무릎-발 일치
- 게이지 시각적 리매핑 (threshold 기준으로 0~1 재매핑)
- TTS: 맥 내장 Yuna 한국어
"""

import cv2
import mediapipe as mp
import numpy as np
import tensorflow as tf
import joblib
import threading
import subprocess
import time
from collections import deque
from PIL import ImageFont, ImageDraw, Image

# ============================================================
# 한글 텍스트 출력용 헬퍼 함수 추가
# ============================================================
def put_korean_text(frame, text, position, font_size, color):
    img_pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(img_pil)
    try:
        font = ImageFont.truetype('AppleGothic.ttf', font_size)
    except IOError:
        try:
            # Mac 폰트 절대 경로 예외 처리
            font = ImageFont.truetype('/System/Library/Fonts/Supplemental/AppleGothic.ttf', font_size)
        except IOError:
            font = ImageFont.load_default()
            
    b, g, r = color
    draw.text(position, text, font=font, fill=(r, g, b))
    # 원본 frame 덮어쓰기
    frame[:] = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)

# ============================================================
# 경로 설정
# ============================================================
MODEL_DIR   = '/Users/mac/Desktop/models_keyframe'
SCALER_PATH = f'{MODEL_DIR}/scaler.pkl'
MODEL_PATHS = {
    'spine': f'{MODEL_DIR}/model_label_spine.keras',
    'knee':  f'{MODEL_DIR}/model_label_knee.keras',
}
COND_NAMES = {
    'spine': '척추 중립',
    'knee':  '무릎-발 일치',
}

FEEDBACK_MAP = {
    (True,  True ): '잘했어 박지민',
    (False, True ): '허리를 펴주세요',
    (True,  False): '무릎을 발끝 방향으로 벌려주세요',
    (False, False): '허리를 펴고, 무릎을 발끝 방향으로 벌려주세요',
}

# ============================================================
# 설정값
# ============================================================
class Config:
    HIP_Y_DOWN_THRESH   = 0.12
    HIP_Y_UP_RATIO      = 0.7
    SMOOTH_WINDOW       = 5
    SPINE_THRESHOLD     = 0.03   # ← 변경: 0.06 이상이면 정상
    SPINE_BAR_MAX       = 0.1    # ← 추가: 게이지 바 최대값 (0.1 = 풀바)
    KNEE_THRESHOLD      = 0.9
    CALIB_COUNTDOWN_SEC = 3
    FULL_BODY_TIMEOUT   = 3.0
    OUT_OF_POS_THRESH   = 0.12
    MIN_DETECT_CONF     = 0.7
    MIN_TRACK_CONF      = 0.6

# ── 색상 팔레트 ─────────────────────────────────────────────
C_GREEN  = (60,  200, 100)
C_RED    = (60,   80, 230)
C_WHITE  = (255, 255, 255)
C_LGRAY  = (200, 200, 200)
C_DGRAY  = (100, 100, 100)
C_YELLOW = (40,  210, 230)
C_TEAL   = (170, 210,  80)
C_ORANGE = (40,  140, 255)
C_BG     = (30,   30,  30)

# ============================================================
# 게이지 시각적 리매핑
# ============================================================
def remap_prob(prob, threshold):
    if threshold <= 0 or threshold >= 1:
        return prob
    if prob >= threshold:
        return 0.5 + 0.5 * (prob - threshold) / (1.0 - threshold + 1e-6)
    else:
        return 0.5 * (prob / (threshold + 1e-6))

# ============================================================
# 전신 감지 여부
# ============================================================
REQUIRED_LANDMARKS = [11, 12, 23, 24, 25, 26, 27, 28]

def is_full_body_visible(lms, vis_thresh=0.6):
    return all(lms[i].visibility > vis_thresh for i in REQUIRED_LANDMARKS)

# ============================================================
# 피처 추출
# ============================================================
def calc_angle_3d(a, b, c):
    v1 = np.array(a) - np.array(b)
    v2 = np.array(c) - np.array(b)
    cos_val = np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2) + 1e-6)
    return float(np.degrees(np.arccos(np.clip(cos_val, -1.0, 1.0))))

def extract_features(wlms):
    def p2(i): return [wlms[i].x, wlms[i].y]
    def p3(i): return [wlms[i].x, wlms[i].y, wlms[i].z]

    nose   = p2(0)
    ear_l  = p3(7);  ear_r  = p3(8)
    sho_l  = p3(11); sho_r  = p3(12)
    hip_l  = p3(23); hip_r  = p3(24)
    knee_l = p3(25); knee_r = p3(26)
    ank_l  = p3(27); ank_r  = p3(28)
    heel_l = p3(29); heel_r = p3(30)
    foot_l = p3(31); foot_r = p3(32)

    sho_c2 = [(sho_l[0]+sho_r[0])/2, (sho_l[1]+sho_r[1])/2]
    sho_c3 = [(sho_l[0]+sho_r[0])/2, (sho_l[1]+sho_r[1])/2, (sho_l[2]+sho_r[2])/2]
    hip_c3 = [(hip_l[0]+hip_r[0])/2, (hip_l[1]+hip_r[1])/2, (hip_l[2]+hip_r[2])/2]
    kne_c3 = [(knee_l[0]+knee_r[0])/2,(knee_l[1]+knee_r[1])/2,(knee_l[2]+knee_r[2])/2]

    f = []
    f.append(calc_angle_3d(sho_c3, hip_c3, kne_c3) / 180.0)
    f.append(calc_angle_3d(sho_l,  hip_l,  knee_l) / 180.0)
    f.append(calc_angle_3d(sho_r,  hip_r,  knee_r) / 180.0)
    f.append(calc_angle_3d(ear_l, sho_l, hip_l) / 180.0)
    f.append(calc_angle_3d(ear_r, sho_r, hip_r) / 180.0)
    f.append(float(nose[0] - sho_c2[0]))
    f.append(calc_angle_3d(hip_l, knee_l, ank_l) / 180.0)
    f.append(calc_angle_3d(hip_r, knee_r, ank_r) / 180.0)
    knee_w = abs(knee_l[0] - knee_r[0]) + 1e-6
    ank_w  = abs(ank_l[0]  - ank_r[0])  + 1e-6
    f.append(float(np.clip(knee_w / ank_w, 0.0, 3.0)))
    f.append(float(heel_l[1] - foot_l[1]))
    f.append(float(heel_r[1] - foot_r[1]))
    f.append(float(sho_c3[2] - hip_c3[2]))
    kz = ((knee_l[2]-ank_l[2]) + (knee_r[2]-ank_r[2])) / 2
    f.append(float(kz))
    return f

# ============================================================
# TTS
# ============================================================
class Voice:
    def __init__(self, voice_name='Yuna'):
        self.voice_name = voice_name
        self._proc      = None
        self._lock      = threading.Lock()

    def speak(self, text: str, interrupt: bool = False):
        with self._lock:
            if interrupt:
                if self._proc and self._proc.poll() is None:
                    self._proc.terminate()
            else:
                if self._proc and self._proc.poll() is None:
                    return
            self._proc = subprocess.Popen(
                ['say', '-v', self.voice_name, '-r', '175', text],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

    def stop(self):
        with self._lock:
            if self._proc and self._proc.poll() is None:
                self._proc.terminate()

# ============================================================
# 캘리브레이션
# ============================================================
class Calibrator:
    def __init__(self, cfg: Config, voice: Voice):
        self.cfg             = cfg
        self.voice           = voice
        self.state           = 'WAITING'
        self.countdown_start = None
        self.body_visible_t  = None
        self.calib_hip_x     = None
        self.calib_hip_y     = None
        self.last_count_said = -1
        self.warned_no_body  = False

    def update(self, lms) -> bool:
        now       = time.time()
        full_body = is_full_body_visible(lms)

        if self.state == 'WAITING':
            if not full_body:
                if self.body_visible_t is None:
                    self.body_visible_t = now
                elif now - self.body_visible_t > self.cfg.FULL_BODY_TIMEOUT:
                    if not self.warned_no_body:
                        self.voice.speak('전신이 보이게 서주세요', interrupt=True)
                        self.warned_no_body = True
                        self.body_visible_t = now
            else:
                self.state           = 'COUNTDOWN'
                self.countdown_start = now
                self.last_count_said = -1
                self.warned_no_body  = False
                self.voice.speak('세 후 시작합니다', interrupt=True)

        elif self.state == 'COUNTDOWN':
            elapsed   = now - self.countdown_start
            remaining = int(self.cfg.CALIB_COUNTDOWN_SEC - elapsed)

            if not full_body:
                self.state          = 'WAITING'
                self.body_visible_t = None
                self.voice.speak('전신이 보이게 서주세요', interrupt=True)
                return False

            if remaining >= 1 and remaining != self.last_count_said:
                self.voice.speak(str(remaining), interrupt=False)
                self.last_count_said = remaining

            if elapsed >= self.cfg.CALIB_COUNTDOWN_SEC:
                self.calib_hip_x = (lms[23].x + lms[24].x) / 2
                self.calib_hip_y = (lms[23].y + lms[24].y) / 2
                self.state       = 'DONE'
                self.voice.speak('시작하세요', interrupt=True)

        return self.state == 'DONE'

    def is_in_position(self, lms) -> bool:
        if self.calib_hip_x is None:
            return False
        cur_hip_x = (lms[23].x + lms[24].x) / 2
        return abs(cur_hip_x - self.calib_hip_x) < self.cfg.OUT_OF_POS_THRESH

    def reset(self):
        self.state           = 'WAITING'
        self.countdown_start = None
        self.body_visible_t  = None
        self.calib_hip_x     = None
        self.calib_hip_y     = None
        self.last_count_said = -1
        self.warned_no_body  = False

# ============================================================
# 스쿼트 카운터
# ============================================================
class SquatCounter:
    def __init__(self, cfg: Config):
        self.cfg            = cfg
        self.count          = 0
        self.state          = 'UP'
        self.base_y         = None
        self.hip_buf        = deque(maxlen=cfg.SMOOTH_WINDOW)
        self.bottom_wlms    = None
        self.min_y_this_rep = None

    def update(self, lms, wlms):
        hip_y    = (lms[23].y + lms[24].y) / 2
        self.hip_buf.append(hip_y)
        smooth_y = float(np.mean(self.hip_buf))

        if self.base_y is None:
            self.base_y = smooth_y
            return self.count, self.state, False, None

        if self.state == 'UP' and smooth_y < self.base_y - 0.01:
            self.base_y = smooth_y

        counted     = False
        bottom_wlms = None
        down_thresh = self.base_y + self.cfg.HIP_Y_DOWN_THRESH

        if self.state == 'UP':
            if smooth_y > down_thresh:
                self.state          = 'DOWN'
                self.min_y_this_rep = smooth_y
                self.bottom_wlms    = wlms
        elif self.state == 'DOWN':
            if smooth_y > self.min_y_this_rep:
                self.min_y_this_rep = smooth_y
                self.bottom_wlms    = wlms
            up_thresh = self.base_y + (self.min_y_this_rep - self.base_y) * (1 - self.cfg.HIP_Y_UP_RATIO)
            if smooth_y < up_thresh:
                self.state   = 'UP'
                self.count  += 1
                counted      = True
                bottom_wlms  = self.bottom_wlms
                self.base_y  = 0.9 * self.base_y + 0.1 * smooth_y

        return self.count, self.state, counted, bottom_wlms

    def reset(self):
        self.count          = 0
        self.state          = 'UP'
        self.base_y         = None
        self.bottom_wlms    = None
        self.min_y_this_rep = None
        self.hip_buf.clear()

# ============================================================
# 추론기
# ============================================================
class PostureInferrer:
    def __init__(self, model_paths, scaler_path, cfg: Config):
        self.cfg    = cfg
        self.scaler = joblib.load(scaler_path)
        self.models = {k: tf.keras.models.load_model(v) for k, v in model_paths.items()}
        self.thresholds = {
            'spine': cfg.SPINE_THRESHOLD,
            'knee':  cfg.KNEE_THRESHOLD,
        }
        print('모델 로드 완료')
        print(f'  척추 threshold: {cfg.SPINE_THRESHOLD}')
        print(f'  무릎 threshold: {cfg.KNEE_THRESHOLD}')

    def infer(self, wlms):
        feats  = extract_features(wlms)
        scaled = self.scaler.transform([feats])
        result = {}
        for key, model in self.models.items():
            prob        = float(model.predict(scaled, verbose=0)[0][0])
            result[key] = {'prob': prob, 'ok': prob >= self.thresholds[key]}
        return result

# ============================================================
# UI 렌더러
# ============================================================
def fill_rect(frame, x1, y1, x2, y2, color, alpha=0.75):
    ov = frame.copy()
    cv2.rectangle(ov, (x1, y1), (x2, y2), color, -1)
    cv2.addWeighted(ov, alpha, frame, 1 - alpha, 0, frame)

def draw_calibration(frame, calib_state, countdown_start, cfg):
    h, w = frame.shape[:2]
    fill_rect(frame, 0, 0, w, h, C_BG, alpha=0.45)

    if calib_state == 'WAITING':
        put_korean_text(frame, '전신이 보이게 서주세요', (w//2 - 260, h//2 - 60), 40, C_WHITE)
        put_korean_text(frame, '어깨부터 발목까지 화면에 들어와야 합니다', (w//2 - 310, h//2 + 10), 20, C_LGRAY)

    elif calib_state == 'COUNTDOWN':
        elapsed   = time.time() - countdown_start
        remaining = max(0, cfg.CALIB_COUNTDOWN_SEC - elapsed)
        put_korean_text(frame, '영점 설정 중', (w//2 - 120, h//2 - 90), 30, C_TEAL)
        cv2.putText(frame, f'{remaining:.1f}',
                    (w//2 - 60, h//2 + 40),
                    cv2.FONT_HERSHEY_DUPLEX, 3.0, C_TEAL, 4)
        put_korean_text(frame, '움직이지 마세요', (w//2 - 130, h//2 + 75), 25, C_LGRAY)

def draw_ui(frame, count, squat_state, result, feedback_msg, out_of_pos, cfg):
    h, w = frame.shape[:2]

    # 상단 패널
    fill_rect(frame, 0, 0, w, 90, C_BG, alpha=0.80)
    cv2.putText(frame, str(count),
                (22, 75), cv2.FONT_HERSHEY_DUPLEX, 2.8, C_TEAL, 4)
    cv2.putText(frame, 'reps',
                (118, 70), cv2.FONT_HERSHEY_SIMPLEX, 1.1, C_WHITE, 2)
    s_color = C_GREEN if squat_state == 'UP' else C_YELLOW
    cv2.putText(frame, squat_state,
                (230, 70), cv2.FONT_HERSHEY_SIMPLEX, 1.3, s_color, 2)

    # 위치 이탈 경고
    if out_of_pos:
        fill_rect(frame, 0, 90, w, 140, (0, 0, 180), alpha=0.85)
        put_korean_text(frame, '처음 위치로 돌아오세요', (w//2 - 220, 98), 30, C_WHITE)

    # 우측 조건 패널
    PW     = 300
    PH     = 120
    px     = w - PW - 16
    py     = 105
    ITEM_H = 55

    fill_rect(frame, px-10, py-10, px+PW+10, py+PH+10, C_BG, alpha=0.80)

    keys       = ['spine', 'knee']
    labels     = ['척추 중립', '무릎-발 일치']
    thresholds = [cfg.SPINE_THRESHOLD, cfg.KNEE_THRESHOLD]

    for i, (key, label, thresh) in enumerate(zip(keys, labels, thresholds)):
        iy = py + i * ITEM_H

        if result and key in result:
            ok       = result[key]['ok']
            prob_raw = result[key]['prob']

            # ── 척추: 바 맥스 = SPINE_BAR_MAX(0.1), 판단은 SPINE_THRESHOLD(0.06) ──
            # ── 무릎: 기존 remap_prob 그대로 ──────────────────────────────────────
            if key == 'spine':
                prob_vis = min(prob_raw / cfg.SPINE_BAR_MAX, 1.0)
            else:
                prob_vis = remap_prob(prob_raw, thresh)

            bar_color  = C_GREEN if ok else C_RED
            icon       = 'O' if ok else 'X'
            icon_color = C_GREEN if ok else C_RED
        else:
            ok         = None
            prob_raw   = 0.0
            prob_vis   = 0.0
            bar_color  = C_DGRAY
            icon       = '-'
            icon_color = C_DGRAY

        cv2.putText(frame, icon,
                    (px, iy+28), cv2.FONT_HERSHEY_DUPLEX, 1.0, icon_color, 2)
        put_korean_text(frame, label, (px+36, iy+4), 20, C_WHITE)

        bar_x = px;  bar_y = iy+32
        bar_w = PW - 40;  bar_h = 13

        cv2.rectangle(frame, (bar_x, bar_y), (bar_x+bar_w, bar_y+bar_h), (70,70,70), -1)
        cv2.rectangle(frame, (bar_x, bar_y), (bar_x+bar_w, bar_y+bar_h), (110,110,110), 1)

        mid_x = bar_x + bar_w // 2
        cv2.line(frame, (mid_x, bar_y-2), (mid_x, bar_y+bar_h+2), (180,180,180), 1)

        filled = int(bar_w * prob_vis)
        if filled > 0:
            cv2.rectangle(frame, (bar_x, bar_y), (bar_x+filled, bar_y+bar_h), bar_color, -1)

        cv2.putText(frame, f'{prob_raw:.0%}',
                    (bar_x+bar_w+6, bar_y+bar_h),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.58, C_LGRAY, 1)

    # 하단 피드백
    if feedback_msg:
        msg_color = C_GREEN if '완벽' in feedback_msg else C_RED
        fill_rect(frame, 0, h-65, w, h, C_BG, alpha=0.80)
        put_korean_text(frame, feedback_msg, (18, h-47), 25, msg_color)

    put_korean_text(frame, 'Q: 종료   R: 재캘리브레이션', (18, h-90), 18, C_DGRAY)

# ============================================================
# 메인
# ============================================================
def main():
    cfg        = Config()
    voice      = Voice(voice_name='Yuna')
    calibrator = Calibrator(cfg, voice)
    counter    = SquatCounter(cfg)
    inferrer   = PostureInferrer(MODEL_PATHS, SCALER_PATH, cfg)

    mp_pose = mp.solutions.pose
    mp_draw = mp.solutions.drawing_utils
    pose    = mp_pose.Pose(
        min_detection_confidence=cfg.MIN_DETECT_CONF,
        min_tracking_confidence=cfg.MIN_TRACK_CONF,
    )

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print('웹캠을 열 수 없습니다.')
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    last_result       = None
    feedback_msg      = ''
    out_of_pos_warned = False

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.flip(frame, 1)
        rgb   = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        res   = pose.process(rgb)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == ord('Q'):
            break
        elif key == ord('r') or key == ord('R'):
            calibrator.reset()
            counter.reset()
            last_result       = None
            feedback_msg      = ''
            out_of_pos_warned = False
            voice.speak('다시 시작합니다. 전신이 보이게 서주세요', interrupt=True)

        if not res.pose_landmarks:
            put_korean_text(frame, '사람을 감지할 수 없습니다', (30, 20), 40, C_RED)
            cv2.imshow('Squat Analyzer', frame)
            continue

        lms  = res.pose_landmarks.landmark
        wlms = res.pose_world_landmarks.landmark if res.pose_world_landmarks else None

        calib_done = calibrator.update(lms)

        if not calib_done:
            mp_draw.draw_landmarks(
                frame, res.pose_landmarks, mp_pose.POSE_CONNECTIONS,
                mp_draw.DrawingSpec(color=(180,180,180), thickness=2, circle_radius=3),
                mp_draw.DrawingSpec(color=(100,220,100), thickness=3)
            )
            draw_calibration(frame, calibrator.state,
                             calibrator.countdown_start, cfg)
            cv2.imshow('Squat Analyzer', frame)
            continue

        in_position = calibrator.is_in_position(lms)
        out_of_pos  = not in_position

        if out_of_pos:
            if not out_of_pos_warned:
                voice.speak('처음 위치로 돌아오세요', interrupt=False)
                out_of_pos_warned = True
        else:
            out_of_pos_warned = False

        if in_position and wlms is not None:
            count, squat_state, counted, bot_wlms = counter.update(lms, wlms)
            if counted and bot_wlms is not None:
                last_result  = inferrer.infer(bot_wlms)
                spine_ok     = last_result['spine']['ok']
                knee_ok      = last_result['knee']['ok']
                fb_text      = FEEDBACK_MAP[(spine_ok, knee_ok)]
                feedback_msg = fb_text
                voice.speak(f'{count}. {fb_text}')
        else:
            squat_state = counter.state
            count       = counter.count

        mp_draw.draw_landmarks(
            frame, res.pose_landmarks, mp_pose.POSE_CONNECTIONS,
            mp_draw.DrawingSpec(color=(180,180,180), thickness=2, circle_radius=3),
            mp_draw.DrawingSpec(color=(100,220,100), thickness=3)
        )
        draw_ui(frame, count, squat_state, last_result, feedback_msg, out_of_pos, cfg)
        cv2.imshow('Squat Analyzer', frame)

    voice.stop()
    cap.release()
    cv2.destroyAllWindows()
    pose.close()

if __name__ == '__main__':
    main()
