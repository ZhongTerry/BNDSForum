#!/bin/bash

# =========================================================
# 1. 自动获取脚本所在目录作为工作目录
# =========================================================
# 解释：
# dirname "$0" 获取脚本所在的相对路径
# cd 进入该目录
# pwd 获取当前目录的绝对路径
WORK_DIR="$( cd "$( dirname "$0" )" && pwd )"

SERVICE_NAME="bnds-forum.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
WSGI_FILE="$WORK_DIR/wsgi.py"

# 2. 检查权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行此脚本。"
    exit 1
fi

echo "------------------------------------------------"
echo "检测到项目路径 (WORK_DIR): $WORK_DIR"
echo "如果不正确，请按 Ctrl+C 中止，并将此脚本移动到正确的项目根目录下运行。"
echo "------------------------------------------------"

# ---------------------------------------------------------
# 3. 创建 Python 入口文件 (wsgi.py)
# ---------------------------------------------------------
echo "正在生成 Python 入口文件: $WSGI_FILE"

cat > "$WSGI_FILE" <<EOF
import sys
import os
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from werkzeug.wrappers import Response

# 确保当前目录在 Python 路径中
sys.path.insert(0, os.getcwd())

try:
    # 尝试导入原本的 app
    from run import app as flask_app
except ImportError:
    try:
        from run import create_app
        flask_app = create_app()
    except ImportError:
        print("错误: 无法在 run.py 中找到 'app' 或 'create_app'")
        raise

def root_app(environ, start_response):
    # 302 临时重定向 / -> /blog/index
    response = Response(
        'Redirecting to /blog...',
        status=302,
        headers=[('Location', '/blog/index')]
    )
    return response(environ, start_response)

# 挂载应用
application = DispatcherMiddleware(root_app, {
    '/blog': flask_app
})
EOF

# ---------------------------------------------------------
# 4. 写入 Systemd 服务文件
# ---------------------------------------------------------
echo "正在创建服务文件: $SERVICE_PATH"

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=BNDS Forum Service (Auto Path)
After=network.target

[Service]
# 使用自动检测的 WORK_DIR
ExecStart=${WORK_DIR}/.venv/bin/python3 -m gunicorn --workers 8 --bind 0.0.0.0:6001 wsgi:application
WorkingDirectory=${WORK_DIR}
Environment=PYTHONUNBUFFERED=1
RestartSec=5s
Restart=always

[Install]
WantedBy=multi-user.target
EOF

${WORK_DIR}/.venv/bin/python3 -m pip install gunicorn

# ---------------------------------------------------------
# 5. 重载并完成
# ---------------------------------------------------------
if [ $? -eq 0 ]; then
    systemctl daemon-reload
    echo "✅ 服务文件写入成功！"
    echo "------------------------------------------------"
    echo "服务名: $SERVICE_NAME"
    echo "路径指向: $WORK_DIR"
    echo "启动命令: systemctl start ${SERVICE_NAME%.*}"
else
    echo "❌ 写入失败。"
    exit 1
fi