#!/bin/bash  
  
# 启动lxserver服务  
npm start &  
  
# 等待服务启动  
echo "等待服务启动..."  
sleep 30  
  
# 音源列表  
sources=("长青音源.js" "念心音源.js" "全豆要-聚合音源.js" "洛雪独家音源.js")  
  
# 导入音源  
for source in "${sources[@]}"; do  
  echo "正在导入: $source"  
    
  response=$(curl -s -w "%{http_code}" -X POST http://localhost:10000/api/custom-source/import -H "Content-Type: application/json" -H "x-frontend-auth: $FRONTEND_PASSWORD" -d "{\"url\":\"https://raw.githubusercontent.com/dyp1121054136/lxserver/master/$source\",\"filename\":\"$source\",\"username\":\"default\"}")  
    
  # 提取状态码（最后3位）  
  http_code="${response: -3}"  
  # 提取响应体（除了最后3位）  
  response_body="${response%???}"  
    
  if [ "$http_code" = "200" ]; then  
    echo "✓ 成功导入: $source"  
  else  
    echo "✗ 导入失败: $source (HTTP $http_code)"  
    echo "响应: $response_body"  
  fi  
    
  # 等待3秒再导入下一个  
  sleep 3  
done  
  
echo "音源导入完成"  
  
# 保持脚本运行，防止容器退出  
wait
