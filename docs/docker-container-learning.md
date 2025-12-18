# Container 与 Docker 入门学习计划与示例

## 学习目标

- 理解什么是 container，为什么比传统虚拟机更轻量
- 掌握 Docker 基本命令：pull/run/build/stop/rm/logs
- 能独立写一个 Dockerfile，并用 Docker Compose 组织多容器
- 能把本地代码打包成镜像并运行

## 前置准备（Windows）

1. 安装 Docker Desktop
2. 启用 WSL2 并设置为默认后端
3. 终端建议使用 PowerShell 或 Windows Terminal

## 7 天入门学习计划（简单可执行）

Day 1 - 基础概念
- 了解 image、container、registry 的关系
- 任务：运行一个官方镜像并进入容器

Day 2 - 生命周期命令
- 学习 run/start/stop/rm/logs/exec
- 任务：启动、停止、删除一个容器

Day 3 - 网络与端口
- 学习 -p 端口映射与容器网络
- 任务：跑一个 Web 服务并在浏览器访问

Day 4 - Dockerfile
- 学习 FROM/WORKDIR/COPY/RUN/CMD/EXPOSE
- 任务：把一个简单应用打包成镜像

Day 5 - 数据持久化
- 学习 volume 与 bind mount
- 任务：把容器内文件写到宿主机

Day 6 - Docker Compose
- 学习 services、depends_on、volumes、networks
- 任务：用 compose 启动多个服务

Day 7 - 复盘与小项目
- 任务：把一个小应用（API 或前端）容器化

## 示例 1：运行现成镜像（nginx）

```powershell
# 拉取镜像
Docker pull nginx:latest

# 运行并映射端口
Docker run --name web -p 8080:80 -d nginx:latest

# 访问 http://localhost:8080

# 查看日志
Docker logs web

# 停止并删除容器
Docker stop web
Docker rm web
```

## 示例 2：把一个简单 Python Web 应用打包成镜像

文件结构：

```
hello-docker/
  app.py
  requirements.txt
  Dockerfile
```

`app.py`：

```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Docker!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

`requirements.txt`：

```
flask==3.0.0
```

`Dockerfile`：

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

构建与运行：

```powershell
Docker build -t hello-docker .
Docker run --name hello -p 5000:5000 -d hello-docker
# 访问 http://localhost:5000
Docker logs hello
Docker rm -f hello
```

## 示例 3：数据持久化（把文件写到宿主机）

```powershell
# 在当前目录创建 data 文件夹
New-Item -ItemType Directory -Force data | Out-Null

# 把容器内 /data 挂载到宿主机
Docker run --rm -v "$($PWD.Path)\data:/data" busybox sh -c "date > /data/time.txt"

# 查看宿主机文件内容
Get-Content .\data\time.txt
```

## 示例 4：Docker Compose 组合多个服务

`docker-compose.yml`：

```yaml
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
  redis:
    image: redis:7
```

运行：

```powershell
Docker compose up -d
Docker compose ps
Docker compose down
```

## 常用命令速查

- `Docker images`：列出镜像
- `Docker ps -a`：列出容器
- `Docker exec -it <name> sh`：进入容器
- `Docker rm -f <name>`：强制删除容器
- `Docker system prune`：清理无用资源（谨慎）

## 建议练习

- 把一个本地小项目（比如静态页面）放进 nginx 容器
- 给镜像打 tag 并推送到 Docker Hub（可选）
- 为你的应用加一个环境变量并在容器内读取
