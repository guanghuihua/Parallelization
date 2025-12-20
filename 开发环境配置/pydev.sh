#!/usr/bin/env bash
#
# pydev.sh — 启动 / 连接 tmux “pydev”，左边编辑，右边监听 + 运行
#

set -euo pipefail

# ========== 配置参数与默认值 ==========
SESSION="pydev"
PROJECT_DIR="$(pwd)"
TARGET="${1:-main.py}"    # 支持通过第一个参数指定目标文件，默认为 main.py
LAYOUT="even"             # 布局（左右均分，目前只一种）

# --- Conda：列出并选择环境（无论当前是否在 base 都可切换） ---
if ! command -v conda >/dev/null 2>&1; then
  echo "错误：未检测到 conda，请先安装/初始化 conda（如：conda init bash）"
  exit 1
fi

# 让 conda activate 在脚本/非交互 shell 中可用
eval "$(conda shell.bash hook)" 2>/dev/null || true

# 列出所有环境名（忽略注释与空行）
mapfile -t ENV_LIST < <(conda env list | awk '!/^#/ && NF { print $1 }')

if [[ ${#ENV_LIST[@]} -eq 0 ]]; then
  echo "未检测到任何 Conda 环境"
  exit 1
fi

echo "可用 Conda 环境："
for i in "${!ENV_LIST[@]}"; do
  printf "  [%d] %s\n" "$i" "${ENV_LIST[$i]}"
done

read -rp "请选择一个环境编号: " sel
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 0 || sel >= ${#ENV_LIST[@]} )); then
  echo "无效的编号"; exit 1
fi

CHOSEN_ENV="${ENV_LIST[$sel]}"

# 生成在 pane 内可复用的激活片段（确保每个 pane 都先激活再运行）
CONDASNIP=$(printf 'eval "$(conda shell.bash hook)"; conda activate %q' "$CHOSEN_ENV")

# ========== 验证和准备目标文件 ==========
if [[ ! -f "$TARGET" ]]; then
  if [[ "$TARGET" == "main.py" ]]; then
    # 自动创建示例 main.py
    cat > "$TARGET" <<'PY'
#!/usr/bin/env python3
def main():
    print("Hello from main.py. Edit me and save to rerun automatically.")
if __name__ == "__main__":
    main()
PY
    chmod +x "$TARGET"
    echo "已创建示例文件：$TARGET"
  else
    echo "错误：指定的目标文件不存在：$TARGET"
    exit 1
  fi
fi

# ========== 检查依赖 ==========
if ! command -v tmux >/dev/null 2>&1; then
  echo "错误：未安装 tmux"
  exit 1
fi

if ! command -v vim >/dev/null 2>&1; then
  # vim 可选，这里假设你用 vim
  echo "警告：未安装 vim，左边 pane 无法启动编辑器"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "错误：未安装 python3"
  exit 1
fi
if ! command -v entr >/dev/null 2>&1; then
  echo "错误：未安装 entr，无法监听文件变动"
  exit 1
fi

# ========== 如果 session 已存在则 attach ==========
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# ========== 创建 tmux 会话和窗格 ==========
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
tmux split-window -h -l 15 -t "$SESSION":0

# 左 pane：激活所选 conda 环境后，用 Vim 编辑
tmux send-keys -t "$SESSION":0.0 "$CONDASNIP; vim \"$TARGET\"" C-m

# 右 pane：激活所选 conda 环境后，用该环境的 Python 监听并运行
tmux send-keys -t "$SESSION":0.1 "$CONDASNIP; find . -name '*.py' | entr -cd python \"$TARGET\"" C-m

# 左 pane：打开 Vim 编辑目标文件
# tmux send-keys -t "$SESSION":0.0 "vim \"$TARGET\"" C-m

# 右 pane：监听 *.py 变动并运行目标脚本
# tmux send-keys -t "$SESSION":0.1 "find . -name '*.py' | entr -cd python3 \"$TARGET\"" C-m

# 焦点回到左 pane（方便开始编辑）
tmux select-pane -t "$SESSION":0.0

# 最后 attach 到 tmux 会话
tmux attach -t "$SESSION"
