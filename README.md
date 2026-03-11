# VideoForge

## 项目简介

VideoForge 是一个最小可用的命令行工具，用来把视频链接转换成字幕文件或转写文本。

v0.1 版本只解决一件事：稳定地把视频内容变成文本资产，方便后续做学习提炼、知识整理和内容分析。

当前流程如下：

1. 输入一个视频链接
2. 优先尝试下载官方字幕和自动字幕
3. 如果没有字幕，则下载音频
4. 使用 `faster-whisper` 做中文转写
5. 将结果输出到 `output/` 目录

## 安装方式

### 1. 进入项目目录

```bash
cd /home/icoffee/Projects/VideoForge
```

### 2. 在项目内创建固定虚拟环境并安装依赖

```bash
make install
```

执行后会在项目根目录生成 `.venv/`，后续 `make run` 会默认使用这个环境，不需要手动激活。

### 3. 安装系统依赖

本项目依赖 `ffmpeg` 处理音频。如果你的系统还没有安装，请先安装。

Ubuntu 或 Debian 示例：

```bash
sudo apt-get update
sudo apt-get install -y ffmpeg
```

## 使用方式

### 运行主流程

```bash
make run URL="https://example.com/video"
```

`make run` 会自动使用项目内 `.venv` 中的 `python` 和 `yt-dlp`。

### 执行结果

- 如果视频本身带字幕，`output/` 下会生成 `.srt`
- 如果没有可下载字幕，`output/` 下会生成 `.txt`

## 完整命令示例

```bash
cd /home/icoffee/Projects/VideoForge
make install
make run URL="https://example.com/video"
```

## 目录结构说明

```text
VideoForge/
├── Makefile
├── README.md
├── requirements.txt
├── scripts/
│   ├── run.sh
│   └── transcribe.py
└── output/
```

各文件作用如下：

- `Makefile`：统一安装、运行和清理入口
- `.venv/`：项目内固定 Python 虚拟环境，由 `make install` 自动创建
- `requirements.txt`：Python 最小依赖列表
- `scripts/run.sh`：主流程脚本，负责下载字幕、下载音频、调用转写
- `scripts/transcribe.py`：使用 `faster-whisper` 将音频转成文本
- `output/`：输出字幕、音频和转写结果

## 常见问题

### 1. 执行 `make run` 提示缺少 URL

请使用下面这种格式：

```bash
make run URL="https://example.com/video"
```

### 2. 提示 `yt-dlp: command not found`

说明项目虚拟环境还没有准备好，请先执行：

```bash
make install
```

### 3. 下载音频时报 `ffmpeg` 相关错误

这是因为系统没有安装 `ffmpeg`，请先安装系统依赖后再重试。

### 4. 转写阶段较慢

`faster-whisper` 首次运行会下载模型文件，速度取决于网络和机器性能。v0.1 默认使用 `small` 模型和 `int8` 计算类型，优先保证稳定和维护成本低。

### 5. 为什么有时输出的是 `.srt`，有时是 `.txt`

这是设计上的预期行为：

- 有字幕时优先保留字幕，输出 `.srt`
- 没有字幕时自动转写，输出 `.txt`

## 补充说明

- 所有输出默认写入 `output/`
- 文件名以视频 ID 为基础
- 当前版本不包含摘要、知识库、Web 服务、GUI、OCR 或批量调度
