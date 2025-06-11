#!/bin/bash

# 清除可能存在的旧进程
pkill -x "xray" 2>/dev/null
pkill -x "cloudflared" 2>/dev/null

# 设置环境变量
export uuid=${uuid:-''}
export port=${port:-''}
export domain=${domain:-''} 
export auth=${auth:-''}

# 检查是否设置了必要的环境变量
if [ -z "$uuid" ] || [ -z "$port" ] || [ -z "$domain" ] || [ -z "$auth" ]; then
    echo "未设置所有变量，脚本退出"
    exit 1
fi

# 获取用户名
username=$(uname -n | cut -d'-' -f2)

# 获取 ws 路径
wspath=$(echo "$uuid" | cut -d'-' -f5)

# 创建必要的目录
mkdir -p /home/user/$username/xray
mkdir -p /home/user/$username/cloudflared

# 下载xray
mkdir -p /home/user/$username/xray/tmp
curl -Lo /home/user/$username/xray/tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o /home/user/$username/xray/tmp/xray.zip -d /home/user/$username/xray/tmp
mv /home/user/$username/xray/tmp/xray /home/user/$username/xray/xray
chmod +x /home/user/$username/xray/xray
rm -rf /home/user/$username/xray/tmp

# 下载cloudflared
curl -Lo /home/user/$username/cloudflared/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /home/user/$username/cloudflared/cloudflared

# 创建xray配置文件
cat >> /home/user/$username/xray/config.json <<EOF
{
    "log": {
        "access": "/home/user/$username/xray/access.log",
        "error": "/home/user/$username/xray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "tlsSettings": {
                    "serverName": "$domain",
                    "fingerprint": "random"
                },
                "wsSettings": {
                    "path": "$wspath",
                    "host": "$domain"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

# 创建自动运行脚本
cat >> /home/user/$username/autorun.sh <<EOF
#!/bin/bash

# 检查xray和cloudflared是否正在运行
if pgrep -x "xray" >/dev/null && pgrep -x "cloudflared" >/dev/null; then
    echo "Both xray and cloudflared are running. Exiting..."
    exit 1
fi

# 清除可能存在的旧进程
pkill -x "xray" 2>/dev/null
pkill -x "cloudflared" 2>/dev/null

# 运行xray
nohup /home/user/$username/xray/xray run -c /home/user/$username/xray/config.json >/dev/null 2>&1 &

# 运行cloudflared
nohup /home/user/$username/cloudflared/cloudflared tunnel --no-autoupdate --edge-ip-version 4 --protocol http2 run --token "$auth" >/dev/null 2>&1 &
EOF
chmod +x /home/user/$username/autorun.sh

# 添加到.bashrc以便自动运行
echo "bash /home/user/$username/autorun.sh" >> ~/.bashrc

# 运行xray
nohup /home/user/$username/xray/xray run -c /home/user/$username/xray/config.json >/dev/null 2>&1 &

# 运行cloudflared
nohup /home/user/$username/cloudflared/cloudflared tunnel --no-autoupdate --edge-ip-version 4 --protocol http2 run --token "$auth" >/dev/null 2>&1 &

# 输出成功信息
sub="vless://$uuid@usa.visa.com:443?encryption=none&security=tls&sni=$domain&fp=random&type=ws&host=$domain&path=/$wspath?ed=2048#idx-$username"
echo "脚本安装成功"
echo "订阅链接: $sub"
