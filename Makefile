SYSTEM_PYTHON := python3
VENV_DIR := .venv
PYTHON := $(VENV_DIR)/bin/python
PIP := $(VENV_DIR)/bin/pip
YT_DLP := $(VENV_DIR)/bin/yt-dlp
OUTPUT_DIR := output
RUN_SCRIPT := scripts/run.sh

.PHONY: help install run clean

help:
	@echo "VideoForge v0.1 可用命令："
	@echo "  make install                         在项目内创建 .venv 并安装依赖"
	@echo "  make run URL=\"https://example.com/video\"   使用 .venv 执行下载字幕或转写"
	@echo "  make clean                           清理 output/ 下生成文件"
	@echo ""
	@echo "命令示例："
	@echo "  make run URL=\"https://example.com/video\""

install:
	@echo "开始创建项目内虚拟环境：$(VENV_DIR)"
	@$(SYSTEM_PYTHON) -m venv $(VENV_DIR)
	@echo "开始安装依赖..."
	@$(PYTHON) -m pip install --upgrade pip
	@$(PIP) install -r requirements.txt
	@echo "依赖安装完成。"

run:
	@if [ -z "$(URL)" ]; then \
		echo "错误：缺少 URL 参数。"; \
		echo "使用示例：make run URL=\"https://example.com/video\""; \
		exit 1; \
	fi
	@if [ ! -x "$(PYTHON)" ] || [ ! -x "$(YT_DLP)" ]; then \
		echo "错误：项目虚拟环境未准备好，请先执行 make install。"; \
		exit 1; \
	fi
	@mkdir -p $(OUTPUT_DIR)
	@bash $(RUN_SCRIPT) "$(URL)" "$(OUTPUT_DIR)" "$(PYTHON)" "$(YT_DLP)"

clean:
	@mkdir -p $(OUTPUT_DIR)
	@find $(OUTPUT_DIR) -mindepth 1 -maxdepth 1 -type f -delete
	@echo "已清理 output/ 下的生成文件。"
