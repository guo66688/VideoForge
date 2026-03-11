#!/usr/bin/env bash

set -e

# 检查参数数量是否正确
if [ "$#" -lt 4 ]; then
    echo "错误：参数不足。"
    echo "使用方式：bash scripts/diagnose.sh \"输出目录\" \"Python路径\" \"pip路径\" \"yt-dlp路径\" [视频链接]"
    exit 1
fi

OUTPUT_DIR="$1"
PYTHON_BIN="$2"
PIP_BIN="$3"
YT_DLP_BIN="$4"
URL="${5:-}"
FAILED_COUNT=0

pass() {
    echo "通过：$1"
}

fail() {
    echo "失败：$1"
    FAILED_COUNT=$((FAILED_COUNT + 1))
}

echo "开始环境诊断..."
echo "输出目录：$OUTPUT_DIR"

if command -v python3 >/dev/null 2>&1; then
    pass "系统已安装 python3：$(python3 --version 2>&1)"
else
    fail "系统未安装 python3。请先安装 Python 3。"
fi

if [ -x "$PYTHON_BIN" ]; then
    pass "项目虚拟环境 Python 可用：$("$PYTHON_BIN" --version 2>&1)"
else
    fail "项目虚拟环境 Python 不存在：$PYTHON_BIN。请先执行 make install。"
fi

if [ -x "$PIP_BIN" ]; then
    pass "项目虚拟环境 pip 可用：$("$PIP_BIN" --version 2>&1)"
else
    fail "项目虚拟环境 pip 不存在：$PIP_BIN。请先执行 make install。"
fi

if [ -x "$YT_DLP_BIN" ]; then
    pass "yt-dlp 可用：$("$YT_DLP_BIN" --version 2>&1)"
else
    fail "yt-dlp 不存在：$YT_DLP_BIN。请先执行 make install。"
fi

if [ -x "$PYTHON_BIN" ]; then
    if "$PYTHON_BIN" -c "import faster_whisper" >/dev/null 2>&1; then
        pass "faster-whisper 已安装。"
    else
        fail "faster-whisper 未安装或不可用。请重新执行 make install。"
    fi
fi

if command -v ffmpeg >/dev/null 2>&1; then
    pass "ffmpeg 已安装：$(ffmpeg -version | head -n 1)"
else
    fail "ffmpeg 未安装。Ubuntu 或 Debian 示例：sudo apt-get update && sudo apt-get install -y ffmpeg"
fi

if command -v ffprobe >/dev/null 2>&1; then
    pass "ffprobe 已安装：$(ffprobe -version | head -n 1)"
else
    fail "ffprobe 未安装。通常安装 ffmpeg 后会一起提供。"
fi

mkdir -p "$OUTPUT_DIR"
if [ -w "$OUTPUT_DIR" ]; then
    pass "输出目录可写：$(cd "$OUTPUT_DIR" && pwd)"
else
    fail "输出目录不可写：$OUTPUT_DIR"
fi

if [ -n "$URL" ] && [ -x "$YT_DLP_BIN" ]; then
    echo "开始检查视频链接可访问性..."
    YT_DLP_ERROR_FILE="$(mktemp)"
    if VIDEO_ID="$("$YT_DLP_BIN" --get-id "$URL" 2>"$YT_DLP_ERROR_FILE")"; then
        VIDEO_ID="$(printf '%s\n' "$VIDEO_ID" | head -n 1 | tr -d '\r')"
        pass "视频链接可读取，视频 ID：$VIDEO_ID"
    else
        fail "视频链接读取失败。原始错误如下："
        cat "$YT_DLP_ERROR_FILE"
    fi
    rm -f "$YT_DLP_ERROR_FILE"
fi

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "环境诊断完成：发现 $FAILED_COUNT 个问题。"
    exit 1
fi

echo "环境诊断完成：所有关键依赖均已就绪。"
