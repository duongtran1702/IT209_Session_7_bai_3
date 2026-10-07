#!/bin/bash
# ==============================================================================
# Script Name : app-simulator.sh
# Description : Script mo phong ung dung Java Spring Boot lang nghe o cong 8082
# Author      : Trần Trí Dương (duongtran1702)
# Student ID  : duongtran1702 | Email: duong170226@gmail.com
# Course      : IT209 - Session 07 - Bai tap 3
# ==============================================================================

PORT=8082

echo "============================================================"
echo "  .   ____          _            __ _ _"
echo " /\\ / ___'_ __ _ _(_)_ __  __ _ \\ \\ \\ \\"
echo "( ( )\\___ | '_ | '_| | '_ \\/ _\` | \\ \\ \\ \\"
echo " \\\\/  ___)| |_)| | | | | || (_| |  ) ) ) )"
echo "  '  |____| .__|_| |_|_| |_\\__, | / / / /"
echo " =========|_|==============|___/=/_/_/_/"
echo " :: Spring Boot ::                (v3.2.5)"
echo "============================================================"
echo "[INFO] Running under system user : $(whoami) (UID: $(id -u))"
echo "[INFO] Connecting to MySQL DataSource: jdbc:mysql://127.0.0.1:3306/springboot_db"
echo "[INFO] Connected as user: spring-admin (Connection pool: HikariCP - 10 active)"
echo "[INFO] Tomcat initialized with port: ${PORT} (http)"
echo "[INFO] Started Application in 2.314 seconds (process running for 2.89)"
echo "[INFO] Ready to receive HTTP traffic on port ${PORT}..."

# Chạy HTTP Server siêu nhẹ bằng Python3 để đáp ứng cổng 8082 và các route / /api/health
if command -v python3 &>/dev/null; then
    exec python3 -c "
import http.server
import socketserver
import json

PORT = $PORT

class SpringBootHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('X-Application-Context', 'spring-boot-application:8082')
        self.end_headers()
        
        response = {
            'status': 'UP',
            'application': 'spring-boot-production-app',
            'port': PORT,
            'database': {
                'status': 'UP',
                'database': 'springboot_db',
                'user': 'spring-admin'
            },
            'path': self.path,
            'message': 'Spring Boot Service is active and running under spring-runner'
        }
        self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))

    def log_message(self, format, *args):
        print(f'[SPRING-LOG] {self.address_string()} - {format % args}')

with socketserver.TCPServer(('0.0.0.0', PORT), SpringBootHandler) as httpd:
    httpd.serve_forever()
"
else
    # Fallback vòng lặp vô tận nếu không có python3
    while true; do
        echo "[INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Heartbeat OK - Port $PORT active."
        sleep 5
    done
fi
