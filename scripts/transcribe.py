#!/usr/bin/env python3

import subprocess
import sys
import time
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


def get_media_duration(audio_path: Path) -> Optional[float]:
    """使用 ffprobe 获取媒体总时长，供进度估算使用。"""
    command = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(audio_path),
    ]

    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
        duration_text = result.stdout.strip()
        if not duration_text:
            return None
        return float(duration_text)
    except (subprocess.SubprocessError, ValueError):
        return None


def format_seconds(seconds: float) -> str:
    """将秒数格式化为更易读的时间。"""
    total_seconds = max(0, int(seconds))
    minutes, secs = divmod(total_seconds, 60)
    hours, minutes = divmod(minutes, 60)

    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def render_progress(processed_seconds: float, total_seconds: Optional[float], start_time: float) -> None:
    """输出实时进度条与预计剩余时间。"""
    if not total_seconds or total_seconds <= 0:
        message = f"\r转写进度：已处理 {format_seconds(processed_seconds)}"
        print(message, end="", flush=True)
        return

    progress = min(processed_seconds / total_seconds, 1.0)
    bar_width = 30
    filled = int(progress * bar_width)
    bar = "#" * filled + "-" * (bar_width - filled)

    elapsed = max(time.time() - start_time, 0.001)
    speed = processed_seconds / elapsed if processed_seconds > 0 else 0
    remaining_media = max(total_seconds - processed_seconds, 0)
    eta_seconds = remaining_media / speed if speed > 0 else 0

    message = (
        f"\r转写进度：[{bar}] "
        f"{progress * 100:6.2f}% "
        f"已处理 {format_seconds(processed_seconds)} / {format_seconds(total_seconds)} "
        f"预计剩余 {format_seconds(eta_seconds)}"
    )
    print(message, end="", flush=True)


def create_model() -> tuple[WhisperModel, str]:
    """优先使用 GPU，加速失败时自动回退到 CPU。"""
    print("开始加载模型：small")

    try:
        model = WhisperModel("small", device="cuda", compute_type="int8")
        print("模型加载完成，当前使用设备：GPU")
        return model, "GPU"
    except Exception as exc:
        print(f"提示：GPU 模式不可用，自动回退到 CPU。原因：{exc}")

    model = WhisperModel("small", device="cpu", compute_type="int8")
    print("模型加载完成，当前使用设备：CPU")
    return model, "CPU"


def transcribe_audio(audio_path: Path, output_path: Path) -> None:
    """执行中文转写并写入文本文件。"""
    model, device_name = create_model()

    print(f"开始转写文件：{audio_path.name}")
    print(f"转写设备：{device_name}")
    total_duration = get_media_duration(audio_path)
    segments, info = model.transcribe(str(audio_path), language="zh")

    lines = []
    start_time = time.time()
    processed_seconds = 0.0

    for segment in segments:
        text = segment.text.strip()
        if text:
            lines.append(text)
        processed_seconds = max(processed_seconds, segment.end)
        render_progress(processed_seconds, total_duration, start_time)

    if processed_seconds > 0 or total_duration:
        render_progress(total_duration or processed_seconds, total_duration, start_time)
        print()

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
