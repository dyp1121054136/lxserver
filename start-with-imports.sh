#!/bin/bash  
  
# 启动lxserver服务  
npm start &  
  
# 等待服务启动  
echo "等待服务启动..."  
sleep 30  
  
# 音源列表（使用jsdelivr CDN加速）  
sources=("长青音源.js" "念心音源.js" "全豆要-聚合音源.js" "洛雪独家音源.js")  
  
# 导入音源  
for source in "${sources[@]}"; do  
  echo "正在导入: $source"  
    
  # 使用jsdelivr CDN链接 - 整个curl命令必须在同一行  
  import_response=$(curl -s -w "%{http_code}" -X POST http://localhost:10000/api/custom-source/import -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"url\":\"https://cdn.jsdelivr.net/gh/dyp1121054136/lxserver@master/$source\",\"filename\":\"$source\",\"username\":\"default\"}")  
    
  # 提取状态码  
  http_code="${import_response: -3}"  
  response_body="${import_response%???}"  
    
  if [ "$http_code" = "200" ]; then  
    echo "✓ 成功导入: $source"  
      
    # 解析响应获取source ID  
    source_id=$(echo "$response_body" | grep -o '"id":"[^"]*' | cut -d'"' -f4)  
      
    if [ ! -z "$source_id" ]; then  
      echo "正在启用: $source (ID: $source_id)"  
        
      # 启用音源 - 同样必须在同一行  
      toggle_response=$(curl -s -w "%{http_code}" -X POST http://localhost:10000/api/custom-source/toggle -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"username\":\"default\",\"sourceId\":\"$source_id\",\"enabled\":true}")  
        
      toggle_code="${toggle_response: -3}"  
        
      if [ "$toggle_code" = "200" ]; then  
        echo "✓ 成功启用: $source"  
      else  
        echo "✗ 启用失败: $source (HTTP $toggle_code)"  
      fi  
    fi  
  else  
    echo "✗ 导入失败: $source (HTTP $http_code)"  
    echo "响应: $response_body"  
  fi  
    
  # 等待3秒再导入下一个  
  sleep 3  
done  
  
echo "音源导入和启用完成"  
  
# 保持脚本运行，防止容器退出  
wait
