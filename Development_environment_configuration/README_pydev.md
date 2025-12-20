# pydev.sh 使用说明与脚本详解

## 一、目标流程

1. 在项目根目录下启动（或进入）一个 tmux 会话，名字为 `pydev`。  
2. 左边 pane 用 Vim 编辑指定的 Python 文件。  
3. 右边 pane 监听所有 Python 文件的变动，并自动运行 / 调试 / 测试 左边的那份文件。  
4. 调试结束后，退出两个 pane（左边退出 Vim，右边停止监听并退出 shell）。  
5. 最后退出整个 `pydev` session。

脚本就是为了“一键”实现以上工作流程。

---

## 二、依赖工具

使用这个脚本，系统（或环境）中需具备以下命令工具：

- **tmux**：用于创建、管理 session / 窗口 / 窗格  
- **vim**：左 pane 用来编辑 Python 文件  
- **python3**：用于执行 / 调试 Python 脚本  
- **entr**：用于监听文件变动并触发命令  
- **conda**：可选，但如果要使用虚拟环境功能必须安装并正确初始化

> 提示：在 Ubuntu 上可以用 `sudo apt install tmux vim python3 entr` 安装；  
> Conda 推荐安装 [Miniconda](https://docs.conda.io/en/latest/miniconda.html)。

---

## 三、脚本用法

假设脚本命名为 `pydev.sh` 并已加执行权限 (`chmod +x pydev.sh`)，在项目根目录运行：

```bash
./pydev.sh [你的文件名.py]
````

- 如果你提供了一个参数，比如 `./pydev.sh myscript.py`，则脚本会尝试打开并调试 `myscript.py`。
- 如果你不提供参数，默认文件名是 `main.py`。如果当前目录没有 `main.py`，脚本会自动创建一个示例 `main.py`。
- 如果已经有名为 `pydev` 的 tmux 会话在运行，脚本会直接进入该会话（attach），不会重复创建。

示例：

```bash
./pydev.sh                   # 启动/进入 pydev，会打开 main.py（如果存在）或创建示例
./pydev.sh train_model.py    # 启动/进入 pydev，会打开 train_model.py 进行调试 / 监听
```

---

## 四、脚本内部工作流程详解

下面逐段解释脚本中各部分命令的作用。

### **顶部：环境控制 & 严格模式**

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `#!/usr/bin/env bash`：指定用 Bash 来执行脚本
- `set -euo pipefail`：启用严格选项

  - `-e`：命令失败时脚本退出
  - `-u`：使用未定义变量时报错退出
  - `-o pipefail`：管道中任一段失败即使整体失败

### **参数与默认值**

```bash
SESSION="pydev"
PROJECT_DIR="$(pwd)"
TARGET="${1:-main.py}"
LAYOUT="even"
```

* `SESSION`：tmux 会话名
* `PROJECT_DIR`：项目目录（脚本运行时的当前目录）
* `TARGET="${1:-main.py}"`：如果运行时带了第一个参数，则以该参数为目标文件；否则默认 `main.py`
* `LAYOUT`：将来可能支持多种布局，目前设为均分布局

### **验证目标文件**

```bash
if [[ ! -f "$TARGET" ]]; then
  if [[ "$TARGET" == "main.py" ]]; then
    # 创建示例 main.py
    … 
  else
    echo "错误：指定的目标文件不存在：$TARGET"
    exit 1
  fi
fi
```

* 如果文件不存在且名字是 `main.py`，脚本自动写一个最简示例 Python 脚本
* 否则报错退出（避免后来执行 `python3 $TARGET` 报错）

### **检查依赖**

脚本检查是否安装了 `tmux`、`vim`、`python3`、`entr`，若缺少关键环节就退出或警告。

### **session 存在处理**

```bash
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi
```

* 如果已经有 `pydev` session 正在运行，就直接 attach（进入它），不重复创建
* `exec` 会替换当前 shell，进入 tmux 后脚本末尾不再执行

### **创建 tmux session + pane 布局**

```bash
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
tmux split-window -h -l 15 -t "$SESSION":0
```

* `new-session -d`：后台创建新的 session
* `-s "$SESSION"`：为其命名
* `-c "$PROJECT_DIR"`：创建 session 时设置起始工作目录为你的项目目录
* `split-window -h -l 15 -t "$SESSION":0`：在 session 的第一个窗口（index 0）里水平分屏，将一个 pane 拆为左右布局，给右侧 pane 分配 15 行（可根据实际终端大小调整）

### **在左 / 右 Pane 注入命令**

如果启用了 Conda 环境选择功能，脚本会在两个 pane 内部执行：

```bash
eval "$(conda shell.bash hook)"; conda activate <你选择的环境>; <命令>
```

例如：

* 左 pane：`conda activate <env>; vim <TARGET>`
* 右 pane：`conda activate <env>; find . -name '*.py' | entr -cd python <TARGET>`

这样保证了两个 pane 内部运行的 Python 和 Vim 都在你选择的 Conda 环境中。

---

## 五、退出 & 清理流程

按照你最初的步骤：

1. **退出左 pane（Vim）**：在 Vim 中键入 `:q` 或 `:qa`

2. **退出右 pane（监听 / shell）**：在那边窗口里按 `Ctrl-C` 中断 `entr`，然后输入 `exit` 或 `Ctrl-D`

3. **退出 tmux session**（在 shell 中／tmux 外）：

   ```bash
   tmux kill-session -t pydev
   ```

   或在 tmux 内使用命令模式：`Ctrl-b : kill-session`

4. 若你下次再运行 `./pydev.sh` 会重新创建 session 或进入已有 session

---

## 六、测试 & 使用建议

* 第一次运行时，试：

  ```bash
  ./pydev.sh
  ```

  它会自动创建示例 `main.py`，打开 Vim 编辑，并且启动监听运行。

* 若你有自己的脚本文件（例如 `train.py`），则运行：

  ```bash
  ./pydev.sh train.py
  ```

  左边打开 `train.py`，右边监听保存并运行。

* 如果你已在一个 `pydev` session 里但想重置环境（重开 pane / 清空状态），你可以先在 shell 外或另一个终端执行：

  ```bash
  tmux kill-session -t pydev
  ```

  然后再运行脚本重新创建。

---

## 七、Conda 环境选择与激活

### 1. 列出 Conda 环境并选择

在脚本启动时，您将看到所有可用的 Conda 环境，脚本会要求您从中选择一个。即使您当前处于 `base` 环境中，脚本也会允许您选择其他任何环境。

```
可用 Conda 环境：
  [0] base
  [1] CTRW
  [2] deepseek-prover-V2
  [3] pydev
  [4] rqalpha
  [5] torch22-cuda118
```

您只需要输入环境编号（例如 `3` 选择 `pydev` 环境），脚本会自动切换到该环境。

### 2. 在 tmux 中激活并使用该环境

在选择了 Conda 环境之后，脚本会在每个 `tmux` pane 中执行以下命令来激活环境：

```bash
eval "$(conda shell.bash hook)"
conda activate <选择的环境>
```

然后，左边 pane 用 `vim` 编辑目标文件，右边 pane 用该环境的 `python` 解释器监听文件变动并自动运行。

---

## 八、总结

这个脚本使得在使用 `tmux` 进行 Python 开发时能够自动管理 Conda 环境、编辑文件并实时运行，极大提升了开发效率。通过一键激活所需的 Conda 环境，您可以更加专注于代码的开发和调试。


