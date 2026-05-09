#!/bin/bash
set -uo pipefail

# ============ 配置 ============
PORT=${SERVER_PORT:-10000}
BASE_URL="http://localhost:${PORT}"
MAX_RETRIES=30
RETRY_INTERVAL=3
STATE_DIR="/tmp/lxserver-import-state"
LOG_FILE="/var/log/lxserver-import.log"

sources=("长青音源.js" "念心音源.js" "全豆要-聚合音源.js" "洛雪独家音源.js")
CDN_BASE="https://cdn.jsdelivr.net/gh/dyp1121054136/lxserver@master"

# ============ 前置校验 ============
if [ -z "${FRONTEND_PASSWORD:-}" ]; then
  echo "✗ 错误：环境变量 FRONTEND_PASSWORD 未设置"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "✗ 错误：需要 jq 命令，请先安装 (apt install jq / apk add jq)"
  exit 1
fi

mkdir -p "$STATE_DIR"

# 日志
exec > >(tee -a "$LOG_FILE") 2>&1
echo "===== $(date '+%Y-%m-%d %H:%M:%S') 开始执行 ====="

# ============ 启动服务 ============
npm start &
SERVER_PID=$!
echo "服务进程PID: $SERVER_PID"

cleanup() {
  echo "正在停止服务 (PID: $SERVER_PID)..."
  kill $SERVER_PID 2>/dev/null
  wait $SERVER_PID 2>/dev/null
}
trap cleanup EXIT SIGINT SIGTERM

# ============ 等待服务就绪 ============
for ((i=1; i<=MAX_RETRIES; i++)); do
  if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo "✗ 服务进程已退出"
    exit 1
  fi
  if curl -sf "${BASE_URL}/api/health" > /dev/null 2>&1; then
    echo "✓ 服务已启动"
    break
  fi
  if [ $i -eq $MAX_RETRIES ]; then
    echo "✗ 服务启动超时 (${MAX_RETRIES}x${RETRY_INTERVAL}s)"
    exit 1
  fi
  echo "等待服务启动... ($i/$MAX_RETRIES)"
  sleep $RETRY_INTERVAL
done

# ============ 导入音源 ============
for source in "${sources[@]}"; do
  STATE_FILE="$STATE_DIR/$source.done"

  # 幂等：跳过已完成
  if [ -f "$STATE_FILE" ]; then
    echo "⏭ 跳过已导入: $source"
    continue
  fi

  echo "正在导入: $source"
  source_url="${CDN_BASE}/${source}"

  # 预检文件可访问性
  HTTP_CODE=$(curl -sIo /dev/null -w "%{http_code}" "$source_url")
  if [ "$HTTP_CODE" != "200" ]; then
    echo "✗ 音源文件不可访问 (HTTP $HTTP_CODE): $source"
    continue
  fi

  # 导入
  response=$(curl -sf -X POST "${BASE_URL}/api/custom-source/import" \
    -H "Content-Type: application/json" \
    -H "x-frontend-auth: $FRONTEND_PASSWORD" \
    -d "{\"url\":\"$source_url\",\"filename\":\"$source\",\"username\":\"default\"}" 2>&1) || {
    echo "✗ 导入请求失败: $source"
    echo "  响应: $response"
    continue
  }

  success=$(echo "$response" | jq -r '.success // false')
  if [ "$success" != "true" ]; then
    echo "✗ 导入失败: $source"
    echo "  响应: $response"
    continue
  fi

  echo "✓ 成功导入: $source"

  # 获取ID并启用
  source_id=$(echo "$response" | jq -r '.id // .data.id // empty')
  if [ -z "$source_id" ]; then
    echo "⚠ 无法获取音源ID，跳过启用"
    touch "$STATE_FILE"
    continue
  fi

  toggle_response=$(curl -sf -X POST "${BASE_URL}/api/custom-source/toggle" \
    -H "Content-Type: application/json" \
    -H "x-frontend-auth: $FRONTEND_PASSWORD" \
    -d "{\"username\":\"default\",\"sourceId\":\"$source_id\",\"enabled\":true}" 2>&1) || {
    echo "⚠ 启用请求失败: $source"
    touch "$STATE_FILE"
    continue
  }

  toggle_success=$(echo "$toggle_response" | jq -r '.success // false')
  if [ "$toggle_success" = "true" ]; then
    echo "✓ 成功启用: $source"
  else
    echo "⚠ 启用失败: $source — $toggle_response"
  fi

  touch "$STATE_FILE"
  sleep 3
done

echo "===== $(date '+%Y-%m-%d %H:%M:%S') 音源导入完成 ====="

# 保持脚本运行
wait $SERVER_PID
