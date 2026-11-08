"""Cut a piece out of a video and save it at 25 frames per second, at most 1280 pixels on the long side.

LiveTalking plays avatar frames at 25 fps, so a 30 fps phone video would otherwise play in slow motion.

usage: cut_video.py <video> <out.mp4> <start_seconds> <end_seconds>      (end 0 = to the end of the video)
"""
import sys

import cv2

src, dst = sys.argv[1], sys.argv[2]
start, end = float(sys.argv[3]), float(sys.argv[4])
OUT_FPS, MAX_SIDE, MAX_SECONDS = 25, 1280, 30

cap = cv2.VideoCapture(src)
if not cap.isOpened():
    raise SystemExit(f"cannot open video: {src}")
fps = cap.get(cv2.CAP_PROP_FPS) or 30.0

frames = []
i = 0
while True:
    ok, f = cap.read()
    if not ok:
        break
    t = i / fps
    i += 1
    if t < start:
        continue
    if end > 0 and t > end:
        break
    if t - start > MAX_SECONDS:
        print(f"note: only the first {MAX_SECONDS} seconds are used (longer avatars need a lot of memory)")
        break
    h, w = f.shape[:2]
    scale = MAX_SIDE / max(h, w)
    if scale < 1:
        f = cv2.resize(f, (int(w * scale) // 2 * 2, int(h * scale) // 2 * 2), interpolation=cv2.INTER_AREA)
    frames.append(f)
cap.release()
if len(frames) < 25:
    raise SystemExit(f"only {len(frames)} frames between {start}s and {end or 'the end'}: pick a longer piece (5-20 seconds)")

n_out = max(2, round(len(frames) * OUT_FPS / fps))
h, w = frames[0].shape[:2]
out = cv2.VideoWriter(dst, cv2.VideoWriter_fourcc(*"mp4v"), OUT_FPS, (w, h))
for k in range(n_out):
    out.write(frames[round(k * (len(frames) - 1) / (n_out - 1))])
out.release()
print(f"wrote {dst}: {n_out} frames, {n_out / OUT_FPS:.1f} s at {OUT_FPS} fps, {w}x{h} (source was {fps:.2f} fps)")
