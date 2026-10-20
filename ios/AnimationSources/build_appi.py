#!/usr/bin/env python3
"""Builds ios/Apprch/Animations/appi.json from the Figma export of Appi's splash.

    python3 ios/AnimationSources/build_appi.py

Re-run after replacing Appi-Anim.json with a new export. The script removes the
export's status bar and background layers (the app draws its own), then adds
two clips after the splash. Markers name each clip so the app plays them by name:

    intro   0–140    Appi rises and beams; onboarding takes over as the waves pull back
    settle  140–210  the waves tuck back behind Appi
    idle    210–450  looping: Appi glances left and right and blinks
    cheer   450–500  Appi looks up, squinting happily

The NFC waves only appear in the intro; the later clips keep them hidden behind Appi.
"""
import copy
import json
import pathlib

HERE = pathlib.Path(__file__).parent
SOURCE = HERE / "Appi-Anim.json"
OUTPUT = HERE.parent / "Apprch" / "Animations" / "appi.json"

INTRO_END = 140
SPLASH_END = 210
IDLE_END = 450
CHEER_END = 500

EXPORT_ONLY_LAYERS = {"Levels", "Time", "Splash Screen"}

EASE = {"o": {"x": 0.42, "y": 0}, "i": {"x": 0.58, "y": 1}}
EASE_OUT = {"o": {"x": 0.2, "y": 0.8}, "i": {"x": 0.3, "y": 1}}
FACE_REST = [159.30255, 118.319336]
EYES_OPEN = [100, 100]
EYES_SHUT = [100, 10]
EYES_SQUINT = [100, 60]


def append(prop, keyframes):
    """Appends (frame, value, easing) keyframes to an animated or static property."""
    if prop.get("a") != 1:
        prop["a"] = 1
        prop["k"] = [{"t": 0, "s": copy.deepcopy(prop["k"])}]
    existing = prop["k"]
    existing[-1].update(copy.deepcopy(EASE))
    for frame, value, easing in keyframes:
        existing.append({"t": frame, "s": value, **copy.deepcopy(easing)})
    for key in ("i", "o"):
        existing[-1].pop(key, None)


def main():
    anim = json.loads(SOURCE.read_text())
    anim["layers"] = [l for l in anim["layers"] if l["nm"] not in EXPORT_ONLY_LAYERS]
    by_name = {}
    for layer in anim["layers"]:
        by_name.setdefault(layer["nm"], []).append(layer)

    face = by_name["Group 2"][0]
    eyes = [l for l in by_name["Vector"] if l.get("parent") == face["ind"] and l.get("refId") == "asset_3"]

    # Center the eye anchors so blinks close toward the middle of each eye.
    for eye in eyes:
        eye["ks"]["a"]["k"] = [15, 15]
        x, y = eye["ks"]["p"]["k"]
        eye["ks"]["p"]["k"] = [x + 15, y + 15]

    look_left = [FACE_REST[0] - 6, FACE_REST[1] - 1.5]
    look_right = [FACE_REST[0] + 6, FACE_REST[1] - 1.5]
    look_up = [FACE_REST[0], FACE_REST[1] - 6]

    append(face["ks"]["p"], [
        (SPLASH_END, FACE_REST, EASE),
        (250, look_left, EASE),
        (300, look_left, EASE),
        (318, FACE_REST, EASE),
        (360, look_right, EASE),
        (405, look_right, EASE),
        (425, FACE_REST, EASE),
        (IDLE_END, FACE_REST, EASE_OUT),
        (460, look_up, EASE),
        (480, look_up, EASE),
        (492, FACE_REST, EASE),
        (CHEER_END, FACE_REST, EASE),
    ])

    for eye in eyes:
        append(eye["ks"]["s"], [
            (330, EYES_OPEN, EASE),
            (334, EYES_SHUT, EASE),
            (338, EYES_OPEN, EASE),
            (432, EYES_OPEN, EASE),
            (435, EYES_SHUT, EASE),
            (438, EYES_OPEN, EASE),
            (441, EYES_SHUT, EASE),
            (444, EYES_OPEN, EASE),
            (IDLE_END, EYES_OPEN, EASE),
            (460, EYES_SQUINT, EASE),
            (480, EYES_SQUINT, EASE),
            (490, EYES_OPEN, EASE),
            (CHEER_END, EYES_OPEN, EASE),
        ])

    for layer in anim["layers"]:
        layer["op"] = CHEER_END
    anim["op"] = CHEER_END
    anim["nm"] = "Appi"
    anim["markers"] = [
        {"tm": 0, "cm": "intro", "dr": INTRO_END},
        {"tm": INTRO_END, "cm": "settle", "dr": SPLASH_END - INTRO_END},
        {"tm": SPLASH_END, "cm": "idle", "dr": IDLE_END - SPLASH_END},
        {"tm": IDLE_END, "cm": "cheer", "dr": CHEER_END - IDLE_END},
    ]

    OUTPUT.write_text(json.dumps(anim, separators=(",", ":")))
    print(f"Wrote {OUTPUT.relative_to(HERE.parent.parent)}")


if __name__ == "__main__":
    main()
