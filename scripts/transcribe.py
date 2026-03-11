#!/usr/bin/env python3

import sys
from pathlib import Path
from typing import Optional

from faster_whisper import WhisperModel


AUDIO_EXTENSIONS = [".mp3", ".m4a", ".webm", ".mp4"]


def find_audio_file(output_dir: Path, video_id: Optional[str]) -> Path:
    """按扩展名优先级查找可转写文件。"""
    if video_id:
        for extension in AUDIO_EXTENSIONS:
            matched_files = sorted(output_dir.glob(f"{video_id}*{extension}"))
            if matched_files:
                return matched_files[0]

    for extension in AUDIO_EXTENSIONS:
        matched_files = sorted(output_dir.glob(f"*{extension}"))
        if matched_files:
            return matched_files[0]

    raise FileNotFoundError("未找到可转写的音频或视频文件。")


def build_output_path(audio_path: Path) -> Path:
    """根据输入文件名生成 txt 输出文件路径。"""
    return audio_path.with_suffix(".txt")


def transcribe_audio(audio_path: Path, output_path: Path) -> None:
    """执行中文转写并写入文本文件。"""
    print(f"开始加载模型：small")
    model = WhisperModel("small", compute_type="int8")

    print(f"开始转写文件：{audio_path.name}")
    segments, info = model.transcribe(str(audio_path), language="zh")

    lines = []
    for segment in segments:
        text = segment.text.strip()
        if text:
            lines.append(text)

    output_text = "\n".join(lines).strip()
    output_path.write_text(output_text, encoding="utf-8")

    print(f"识别语言：{info.language}")
    print(f"输出文件：{output_path.name}")


def main() -> int:
    """处理命令行参数并执行转写。"""
    if len(sys.argv) < 2:
        print("错误：缺少输出目录参数。")
        print("使用方式：python3 scripts/transcribe.py 输出目录 [视频ID]")
        return 1

    output_dir = Path(sys.argv[1]).expanduser().resolve()
    video_id = sys.argv[2] if len(sys.argv) > 2 else None

    if not output_dir.exists():
        print(f"错误：输出目录不存在：{output_dir}")
        return 1

    try:
        audio_path = find_audio_file(output_dir, video_id)
        output_path = build_output_path(audio_path)
        transcribe_audio(audio_path, output_path)
        return 0
    except FileNotFoundError as exc:
        print(f"错误：{exc}")
        return 1
    except Exception as exc:
        print(f"错误：转写失败：{exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
