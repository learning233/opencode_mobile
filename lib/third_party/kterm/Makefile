.PHONY: all smoke unit golden fuzz test clean

all: test

# ─── 测试 ────────────────────────────────────────────────────────────

test:		## 全量测试 (flutter test, 随机顺序)
	./run_test.sh

smoke:		## 烟雾测试 (纯 Dart, 无需 Flutter SDK)
	./run_test.sh smoke

golden:		## Golden 文件测试 (更新 golden)
	./run_test.sh golden

fuzz:		## 多种子乱序测试 (默认 5 次)
	./run_test.sh fuzz

unit:		## 快速测试单个文件
	@echo 'Usage: make unit FILE=test/xxx_test.dart'
	./run_test.sh $(FILE)

# ─── 清理 ────────────────────────────────────────────────────────────

clean:		## 清理构建产物
	rm -rf .dart_tool build
	find . -name '.DS_Store' -delete

# ─── 帮助 ───────────────────────────────────────────────────────────

help:
	@echo 'Usage: make <target>'
	@echo ''
	@sed -n 's/^\([a-z_]*\):.*##/\1/p' $(MAKEFILE_LIST) | column -t -s'	'
