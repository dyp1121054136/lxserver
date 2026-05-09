#!/bin/bash

# ==========================================
# 启动服务
# ==========================================
npm start &

# ==========================================
# 智能等待（替代原来的 sleep 45）
# ==========================================
echo "等待服务就绪..."
max_retries=30
retry_interval=2
ready=false

for i in $(seq 1 $max_retries); do
  # 尝试请求健康检查接口或根路径
  if curl -sf http://localhost:10000/ > /dev/null 2>&1; then
    echo "✓ 服务已就绪 (耗时约 $((i * retry_interval))秒)"
    ready=true
    break
  fi
  sleep $retry_interval
done

# 如果服务没能在限定时间内启动，退出脚本，Render会自动重启补救
if [ "$ready" = false ]; then
  echo "✗ 服务启动超时，退出"
  exit 1
fi

# ==========================================
# 定义并行导入函数
# ==========================================
import_source() {
  local source="$1"
  local base_url="https://cdn.jsdelivr.net/gh/dyp1121054136/lxserver@master"
  
  echo "正在导入: $source"
  
  # --max-time 30: 限制单次请求最长30秒，防止卡死
  response=$(curl -s --max-time 30 -X POST \
    http://localhost:10000/api/custom-source/import \
    -H "Content-Type: application/json" \
    -H "x-frontend-auth: $FRONTEND_PASSWORD" \
    -d "{\"url\":\"$base_url/$source\",\"filename\":\"$source\",\"username\":\"default\"}")
  
  if echo "$response" | grep -q '"success":true'; then
    echo "✓ 成功导入: $source"
    
    # 提取ID并启用
    source_id=$(echo "$response" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    if [ -n "$source_id" ]; then
      toggle_response=$(curl -s --max-time 10 -X POST \
        http://localhost:10000/api/custom-source/toggle \
        -H "Content-Type: application/json" \
        -H "x-frontend-auth: $FRONTEND_PASSWORD" \
        -d "{\"username\":\"default\",\"sourceId\":\"$source_id\",\"enabled\":true}")
      
      if echo "$toggle_response" | grep -q '"success":true'; then
        echo "✓ 成功启用: $source"
      else
        echo "✗ 启用失败: $source"
      fi
    fi
  else
    echo "✗ 导入失败: $source"
    echo "响应: $response"
  fi
}

# ==========================================
# 并行执行导入（4个音源同时进行）
# ==========================================
sources=("长青音源.js" "念心音源.js" "全豆要-聚合音源.js" "洛雪独家音源.js")

for source in "${sources[@]}"; do
  import_source "$source" &
done

# 等待所有后台导入任务完成
wait
echo "================================"
echo "✅ 所有音源导入并启用完毕"
echo "================================"

# ==========================================
# 保持脚本前台运行
# ==========================================
# 必须保留这行，否则脚本执行完毕退出，Render会认为服务挂了而重启
wait
