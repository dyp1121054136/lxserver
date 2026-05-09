#!/bin/bash  
  
# 启动lxserver服务  
npm start &  
  
# 等待服务启动  
echo "等待服务启动..."  
sleep 45  
  
# 音源列表（使用jsdelivr CDN加速）  
sources=("长青音源.js" "念心音源.js" "全豆要-聚合音源.js" "洛雪独家音源.js")  
  
# 导入音源  
for source in "${sources[@]}"; do  
  echo "正在导入: $source"  
    
  response=$(curl -s -X POST http://localhost:10000/api/custom-source/import -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"url\":\"https://cdn.jsdelivr.net/gh/dyp1121054136/lxserver@master/$source\",\"filename\":\"$source\",\"username\":\"default\"}")  
    
  if echo "$response" | grep -q '"success":true'; then  
    echo "✓ 成功导入: $source"  
      
    # 获取source ID并启用  
    source_id=$(echo "$response" | grep -o '"id":"[^"]*' | cut -d'"' -f4)  
    if [ ! -z "$source_id" ]; then  
      echo "正在启用: $source"  
      toggle_response=$(curl -s -X POST http://localhost:10000/api/custom-source/toggle -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"username\":\"default\",\"sourceId\":\"$source_id\",\"enabled\":true}")  
        
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
    
  sleep 3  
done  
  
echo "音源导入完成"  
  
# 保持脚本运行  
wait
