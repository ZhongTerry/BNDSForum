#!/bin/bash

# 检查是否提供了参数
if [ -z "$1" ]; then
    echo "错误: 未提供项目路径参数。"
    echo "用法: sudo $0 <项目路径>"
    echo "示例: sudo $0 /var/www/bndsoj/submodules/blog"
    exit 1
fi

# 获取路径参数（去除末尾的斜杠，以防用户输入 /path/to/dir/）
WORK_DIR="${1%/}"
SERVICE_NAME="bnds-forum.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# 检查当前是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "错误: 请使用 sudo 或 root 权限运行此脚本，因为需要写入 /etc/systemd/system/"
    exit 1
fi

echo "正在创建服务文件: $SERVICE_PATH"
echo "工作目录设置为: $WORK_DIR"

# 写入 systemd 服务文件
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=BNDS Forum Service
After=network.target

[Service]
# 使用传入的参数作为路径前缀
ExecStart=${WORK_DIR}/.venv/bin/python3 -m gunicorn --workers 8 --bind 0.0.0.0:6001 run:app
WorkingDirectory=${WORK_DIR}
Environment=PYTHONUNBUFFERED=1
RestartSec=5s
Restart=always

[Install]
WantedBy=multi-user.target
EOF

${WORK_DIR}/.venv/bin/python3 -m pip install gunicorn

# 检查写入是否成功
if [ $? -eq 0 ]; then
    echo "✅ 服务文件写入成功！"
    
    # 重载 systemd 守护进程以识别新服务
    systemctl daemon-reload
    echo "🔄 Systemd daemon 已重载。"
    
    echo "------------------------------------------------"
    echo "你可以使用以下命令管理服务："
    echo "启动服务: systemctl start ${SERVICE_NAME%.*}"
    echo "开机自启: systemctl enable ${SERVICE_NAME%.*}"
    echo "查看状态: systemctl status ${SERVICE_NAME%.*}"
else
    echo "❌ 写入失败。"
    exit 1
fi