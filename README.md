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

### 先做环境诊断

```bash
make diagnose
```

如果你想同时检查某个视频链接是否能被 `yt-dlp` 正常读取，可以这样执行：

```bash
make diagnose URL="https://example.com/video"
```

### 运行主流程

```bash
make run URL="https://example.com/video"
```

`make run` 会自动使用项目内 `.venv` 中的 `python` 和 `yt-dlp`。
如果虚拟环境里已安装 GPU 所需的 `cuBLAS` 和 `cuDNN` Python 包，运行时也会自动注入对应库路径，不需要手动 `export LD_LIBRARY_PATH`。

### 执行结果

- 如果视频本身带字幕，`output/` 下会生成 `.srt`
- 如果没有可下载字幕，`output/` 下会生成 `.txt`

## 完整命令示例

```bash
cd /home/icoffee/Projects/VideoForge
make install
make diagnose
make run URL="https://example.com/video"
```

## 目录结构说明

```text
VideoForge/
├── Makefile
├── README.md
├── requirements.txt
├── scripts/
│   ├── diagnose.sh
│   ├── run.sh
│   └── transcribe.py
└── output/
```

各文件作用如下：

- `Makefile`：统一安装、运行和清理入口
- `.venv/`：项目内固定 Python 虚拟环境，由 `make install` 自动创建
- `requirements.txt`：Python 最小依赖列表
- `scripts/diagnose.sh`：环境诊断脚本，检查虚拟环境、依赖和系统工具
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

也可以先执行下面的命令做诊断：

```bash
make diagnose
```

### 4. 转写阶段较慢

`faster-whisper` 首次运行会下载模型文件，速度取决于网络和机器性能。v0.1 默认使用 `small` 模型和 `int8` 计算类型，优先尝试 GPU；如果 GPU 或 CUDA 依赖不可用，会自动回退到 CPU。转写过程中会根据音频总时长显示进度条和预计剩余时间。

### 5. 为什么有时输出的是 `.srt`，有时是 `.txt`

这是设计上的预期行为：

- 有字幕时优先保留字幕，输出 `.srt`
- 没有字幕时自动转写，输出 `.txt`

## 补充说明

- 所有输出默认写入 `output/`
- 文件名以视频 ID 为基础
- 当前版本不包含摘要、知识库、Web 服务、GUI、OCR 或批量调度
