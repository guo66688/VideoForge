#!/usr/bin/env bash

set -e

# 检查参数数量是否正确
if [ "$#" -lt 4 ]; then
    echo "错误：参数不足。"
    echo "使用方式：bash scripts/run.sh \"视频链接\" \"输出目录\" \"Python路径\" \"yt-dlp路径\""
    exit 1
fi

URL="$1"
OUTPUT_DIR="$2"
PYTHON_BIN="$3"
YT_DLP_BIN="$4"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRANSCRIBE_SCRIPT="$SCRIPT_DIR/transcribe.py"

if [ ! -x "$PYTHON_BIN" ]; then
    echo "错误：未找到可用的 Python 解释器：$PYTHON_BIN"
    exit 1
fi

if [ ! -x "$YT_DLP_BIN" ]; then
    echo "错误：未找到可用的 yt-dlp：$YT_DLP_BIN"
    exit 1
fi

prepare_cuda_library_path() {
    CUDA_LIB_PATH="$("$PYTHON_BIN" -c 'import importlib.util, os
paths = []
for name in ("nvidia.cublas.lib", "nvidia.cudnn.lib"):
    spec = importlib.util.find_spec(name)
    if spec is None:
        continue

    locations = list(spec.submodule_search_locations or [])
    if locations:
        paths.append(locations[0])
        continue

    if spec.origin:
        paths.append(os.path.dirname(spec.origin))

print(":".join(paths))' 2>/dev/null || true)"

    if [ -n "$CUDA_LIB_PATH" ]; then
        export LD_LIBRARY_PATH="$CUDA_LIB_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        echo "已自动注入 CUDA 库路径：$CUDA_LIB_PATH"
    else
        echo "提示：未检测到可用的 CUDA Python 运行库，将按 GPU 优先、CPU 回退策略继续。"
    fi
}

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "开始处理视频链接：$URL"
echo "输出目录：$(pwd)"
echo "当前使用环境：$PYTHON_BIN"

echo "正在获取视频 ID..."
YT_DLP_ERROR_FILE="$(mktemp)"

if ! VIDEO_ID_RAW="$("$YT_DLP_BIN" --get-id "$URL" 2>"$YT_DLP_ERROR_FILE")"; then
    echo "错误：无法读取视频信息。"
    if [ -s "$YT_DLP_ERROR_FILE" ]; then
        echo "yt-dlp 原始错误："
        cat "$YT_DLP_ERROR_FILE"
    else
        echo "请检查链接是否有效，或确认当前网络可以访问目标站点。"
    fi
    rm -f "$YT_DLP_ERROR_FILE"
    exit 1
fi

rm -f "$YT_DLP_ERROR_FILE"

VIDEO_ID="$(printf '%s\n' "$VIDEO_ID_RAW" | head -n 1 | tr -d '\r')"

if [ -z "$VIDEO_ID" ]; then
    echo "错误：无法获取视频 ID，请检查链接是否有效。"
    exit 1
fi

echo "视频 ID：$VIDEO_ID"
echo "开始尝试下载字幕..."

if "$YT_DLP_BIN" \
    --skip-download \
    --write-subs \
    --write-auto-subs \
    --sub-langs "zh.*,en.*" \
    --convert-subs srt \
    -o "%(id)s.%(ext)s" \
    "$URL"; then
    echo "字幕下载阶段已完成。"
else
    echo "未成功获取字幕，继续尝试下载音频并转写。"
fi

if ls "${VIDEO_ID}"*.srt >/dev/null 2>&1; then
    echo "已找到字幕文件，处理结束。"
    echo "生成文件："
    ls -1 "${VIDEO_ID}"*.srt
    exit 0
fi

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    echo "错误：当前系统未安装 ffmpeg 或 ffprobe，无法下载音频并转写。"
    echo "请先安装系统依赖后重试。"
    echo "Ubuntu 或 Debian 示例：sudo apt-get update && sudo apt-get install -y ffmpeg"
    exit 1
fi

echo "未找到可用字幕，开始下载音频..."
"$YT_DLP_BIN" \
    -x \
    --audio-format mp3 \
    -o "%(id)s.%(ext)s" \
    "$URL"

echo "开始执行中文转写..."
prepare_cuda_library_path
"$PYTHON_BIN" "$TRANSCRIBE_SCRIPT" "$(pwd)" "$VIDEO_ID"

echo "处理完成，生成文件如下："
ls -1 "${VIDEO_ID}"*.txt "${VIDEO_ID}"*.srt 2>/dev/null || true
