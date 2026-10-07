#!/bin/bash
# ==============================================================================
# Script Name : setup-spring-env.sh
# Description : Thiet lap moi truong user, database va cai dat systemd cho Spring Boot
# Author      : Trần Trí Dương (duongtran1702)
# Student ID  : duongtran1702 | Email: duong170226@gmail.com
# Course      : IT209 - Session 07 - Bai tap 3
# ==============================================================================

set -euo pipefail

echo "========================================================================"
echo " [BÀI 3] THIẾT LẬP MÔI TRƯỜNG VÀ CÀI ĐẶT SYSTEMD CHO SPRING BOOT"
echo "========================================================================"

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Kịch bản này cần được chạy với quyền root (sudo)." >&2
   exit 1
fi

APP_DIR="/opt/spring-app"
APP_USER="spring-runner"
SERVICE_NAME="spring-app.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Khởi tạo người dùng hệ thống không có quyền shell login
if id "$APP_USER" &>/dev/null; then
    echo "[INFO] User hệ thống '$APP_USER' đã tồn tại."
else
    echo "[INFO] Tạo user hệ thống '$APP_USER' với shell /usr/sbin/nologin..."
    useradd -r -s /usr/sbin/nologin "$APP_USER"
    echo "[SUCCESS] Đã tạo người dùng '$APP_USER'."
fi
echo "[VERIFY] $(id "$APP_USER")"

# 2. Tạo thư mục chứa ứng dụng /opt/spring-app
echo "[INFO] Tạo thư mục ứng dụng: $APP_DIR..."
mkdir -p "$APP_DIR"

# 3. Sao chép hoặc tạo ứng dụng giả lập nếu chưa có app.jar thật
if [[ -f "$APP_DIR/app.jar" ]]; then
    echo "[INFO] Đã tìm thấy tệp $APP_DIR/app.jar."
else
    echo "[INFO] Khởi tạo tệp mô phỏng ứng dụng Spring Boot chạy cổng 8082..."
    cp "$SCRIPT_DIR/app-simulator.sh" "$APP_DIR/app-simulator.sh"
    chmod +x "$APP_DIR/app-simulator.sh"
    
    # Nếu hệ thống có java, ta có thể chạy jar, hoặc dùng runner liên kết
    # Tạo wrapper hoặc link để đảm bảo ExecStart chạy ổn định
    cat << 'EOF' > "$APP_DIR/app.jar"
PK Mock Spring Boot Jar File
EOF
fi

# Phân quyền sở hữu thư mục cho spring-runner
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"
chmod 755 "$APP_DIR"

# 4. Khởi tạo MySQL Database (nếu mysql client có sẵn)
if command -v mysql &>/dev/null; then
    echo "[INFO] Đang nạp cấu hình cơ sở dữ liệu từ init-db.sql..."
    mysql -u root < "$SCRIPT_DIR/init-db.sql" || echo "[WARN] Cần cấu hình mật khẩu root MySQL nếu có."
fi

# 5. Cài đặt tệp tin dịch vụ Systemd
echo "[INFO] Sao chép $SERVICE_NAME vào /etc/systemd/system/..."
cp "$SCRIPT_DIR/$SERVICE_NAME" "/etc/systemd/system/$SERVICE_NAME"
chmod 644 "/etc/systemd/system/$SERVICE_NAME"

# 6. Nạp lại Systemd Daemon và kích hoạt dịch vụ
echo "[INFO] Thực hiện sudo systemctl daemon-reload..."
systemctl daemon-reload

echo "[INFO] Kích hoạt và khởi chạy dịch vụ..."
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# 7. Kiểm tra trạng thái
echo "========================================================================"
echo " [KIỂM TRA DỊCH VỤ SYSTEMD]"
echo "========================================================================"
systemctl status "$SERVICE_NAME" --no-pager

echo ""
echo "========================================================================"
echo " [KIỂM TRA CỔNG LẮNG NGHE 8082 (ss -tlnp | grep 8082)]"
echo "========================================================================"
ss -tlnp | grep 8082 || echo "[INFO] Đang khởi động tiến trình trên cổng 8082..."
