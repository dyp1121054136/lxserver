#!/bin/bash  
  
# 启动lxserver服务  
npm start &  
  
# 等待服务启动并验证就绪  
echo "等待服务启动..."  
wait_time=0  
max_wait=120  
  
while [ $wait_time -lt $max_wait ]; do  
  # 检查服务是否响应  
  if curl -s -f -X POST -H "x-frontend-auth: $FRONTEND_PASSWORD" http://localhost:10000/api/admin/verify > /dev/null 2>&1; then  
    echo "✓ 服务已就绪 (等待 ${wait_time}s)"  
    break  
  fi  
    
  echo "等待服务启动... (${wait_time}s)"  
  sleep 5  
  wait_time=$((wait_time + 5))  
done  
  
if [ $wait_time -ge $max_wait ]; then  
  echo "❌ 服务启动超时，跳过音源导入"  
  wait  
  exit 1  
fi  
  
# 额外等待确保所有模块加载完成  
sleep 10  
  
# 音源列表（使用jsdelivr CDN加速）  
sources=("长青音源.js" "念心音源.js" "全豆要-聚合音源.js" "洛雪独家音源.js")  
  
# 导入音源（带重试机制）  
for source in "${sources[@]}"; do  
  echo "正在导入: $source"  
    
  # 重试机制  
  retry_count=0  
  max_retries=3  
    
  while [ $retry_count -lt $max_retries ]; do  
    import_response=$(curl -s -w "%{http_code}" -X POST http://localhost:10000/api/custom-source/import -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"url\":\"https://cdn.jsdelivr.net/gh/dyp1121054136/lxserver@master/$source\",\"filename\":\"$source\",\"username\":\"default\"}")  
      
    http_code="${import_response: -3}"  
    response_body="${import_response%???}"  
      
    if [ "$http_code" = "200" ]; then  
      echo "✓ 成功导入: $source"  
        
      # 解析响应获取source ID  
      source_id=$(echo "$response_body" | grep -o '"id":"[^"]*' | cut -d'"' -f4)  
        
      if [ ! -z "$source_id" ]; then  
        echo "正在启用: $source (ID: $source_id)"  
          
        # 启用音源  
        toggle_response=$(curl -s -w "%{http_code}" -X POST http://localhost:10000/api/custom-source/toggle -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"username\":\"default\",\"sourceId\":\"$source_id\",\"enabled\":true}")  
          
        toggle_code="${toggle_response: -3}"  
          
        if [ "$toggle_code" = "200" ]; then  
          echo "✓ 成功启用: $source"  
        else  
          echo "✗ 启用失败: $source (HTTP $toggle_code)"  
        fi  
      fi  
      break  
    else  
      retry_count=$((retry_count + 1))  
      echo "✗ 导入失败: $source (HTTP $http_code) - 重试 $retry_count/$max_retries"  
        
      if [ $retry_count -lt $max_retries ]; then  
        sleep 5  
      fi  
    fi  
  done  
    
  if [ $retry_count -ge $max_retries ]; then  
    echo "❌ $source 导入失败，已达到最大重试次数"  
  fi  
    
  # 等待3秒再导入下一个  
  sleep 3  
done  
  
echo "音源导入和启用完成"  
  
# 保持脚本运行，防止容器退出  
wait
