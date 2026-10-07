# BÁO CÁO THỰC HÀNH - BÀI 3
## CHỦ ĐỀ: THIẾT LẬP CƠ SỞ DỮ LIỆU VÀ TỰ CẤU HÌNH DỊCH VỤ SYSTEMD CHO SPRING BOOT

- **Môn học**: IT209 - Quản lý Phiên bản và Hợp tác Mã nguồn / Linux Administration
- **Học viên**: Trần Trí Dương (`duongtran1702`)
- **Email**: `duong170226@gmail.com`
- **Mã lớp**: IT209
- **Đường dẫn bài nộp**: [IT209_Session_7_bai_3](https://github.com/duongtran1702/IT209_Session_7_bai_3)
- **Tệp cấu hình dịch vụ**: [`spring-app.service`](spring-app.service)
- **Tệp khởi tạo cơ sở dữ liệu**: [`init-db.sql`](init-db.sql)
- **Kịch bản thiết lập**: [`setup-spring-env.sh`](setup-spring-env.sh)
- **Kịch bản mô phỏng**: [`app-simulator.sh`](app-simulator.sh)

---

## 1. MỤC TIÊU BÀI TẬP

1. **Quản trị và phân quyền Cơ sở dữ liệu MySQL**: Thực hành khởi tạo database `springboot_db`, tạo tài khoản người dùng chuyên trách `spring-admin` với mật khẩu phức tạp `SpringSecure@123`, và cấp toàn quyền (Grant All Privileges) an toàn trên database chỉ định.
2. **Nâng cao an ninh với Non-Root System User**: Tạo người dùng hệ thống Linux `spring-runner` với shell bị vô hiệu hóa (`/usr/sbin/nologin`), đảm bảo dịch vụ ứng dụng chạy cô lập, tuân thủ nguyên tắc đặc quyền tối thiểu (**Principle of Least Privilege**).
3. **Tự thiết kế tệp tin cấu hình dịch vụ Systemd chuẩn hóa**: Tự viết từ đầu tệp tin dịch vụ `/etc/systemd/system/spring-app.service` không dùng mẫu, định nghĩa đầy đủ các khối `[Unit]`, `[Service]`, `[Install]`.
4. **Cơ chế tự phục hồi sự cố (Self-Healing & Auto-Restart)**: Cấu hình `Restart=on-failure` và `RestartSec=10` để dịch vụ tự khởi động lại sau 10 giây nếu gặp sự cố sập bất ngờ.
5. **Giám sát trạng thái tiến trình và cổng mạng**: Xác thực trạng thái hoạt động với lệnh `systemctl status spring-app.service` và kiểm tra cổng lắng nghe `8082` bằng lệnh `ss -tlnp | grep 8082`.

---

## 2. BỐI CẢNH VÀ NGUYÊN TẮC THIẾT KẾ BẢO MẬT

### 2.1. Tại sao không nên chạy Spring Boot bằng lệnh `nohup java -jar ... &`?
- **Không tự hồi phục**: Nếu ứng dụng gặp lỗi tràn bộ nhớ `OutOfMemoryError` hoặc sập tiến trình, hệ thống không thể tự bật lại, gây gián đoạn dịch vụ nghiêm trọng (Downtime).
- **Rủi ro đặc quyền Root**: Nếu chạy dưới tài khoản `root`, bất kỳ lỗ hổng bảo mật nào trong ứng dụng hoặc thư viện bên thứ 3 (như lỗ hổng RCE Log4Shell) đều cho phép kẻ tấn công kiểm soát toàn bộ máy chủ.
- **Khó quản lý tập trung**: Thiếu khả năng quản lý vòng đời (Start, Stop, Reload, Status) và không đồng bộ nhật ký vào `journalctl`.

### 2.2. Kiến trúc dịch vụ quản lý bởi Systemd

```mermaid
flowchart TD
    subgraph SystemdSupervisor ["Systemd Init & Service Manager"]
        DaemonReload["systemctl daemon-reload"]
        UnitFile["/etc/systemd/system/spring-app.service"]
        CGroup["Control Group (cgroups) Isolation"]
        Watchdog["Giám sát trạng thái tiến trình (Exit Code)"]
    end

    subgraph OSContext ["Môi trường Thực thi Hệ điều hành"]
        UserIdentity["User: spring-runner (Non-root, nologin)"]
        Exec["/usr/bin/java -jar /opt/spring-app/app.jar"]
        NetPort["Lắng nghe Cổng: 8082/tcp"]
    end

    subgraph DBContext ["Hệ Quản trị Cơ sở dữ liệu"]
        MySQL["MySQL Database: springboot_db (:3306)"]
        DBUser["User: spring-admin (SpringSecure@123)"]
    end

    UnitFile --> DaemonReload
    DaemonReload --> CGroup
    CGroup --> UserIdentity
    UserIdentity --> Exec
    Exec --> NetPort
    Exec -->|JDBC Connection Pool| MySQL
    MySQL -.->|Xác thực| DBUser

    Exec -.->|Nếu gặp sự cố Crash / SIGKILL| Watchdog
    Watchdog -->|Đợi 10 giây (RestartSec=10)| Exec
```

---

## 3. CẤU HÌNH CƠ SỞ DỮ LIỆU MYSQL (`init-db.sql`)

Nội dung kịch bản SQL khởi tạo:

```sql
-- 1. Tạo cơ sở dữ liệu với bảng mã utf8mb4 hỗ trợ đầy đủ ký tự quốc tế và emoji
CREATE DATABASE IF NOT EXISTS springboot_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. Tạo tài khoản spring-admin kết nối nội bộ từ localhost
CREATE USER IF NOT EXISTS 'spring-admin'@'localhost'
  IDENTIFIED BY 'SpringSecure@123';

-- 3. Cấp toàn quyền truy cập cơ sở dữ liệu springboot_db
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'localhost';

-- 4. Áp dụng ngay thay đổi đặc quyền
FLUSH PRIVILEGES;
```

**Phân tích bảo mật:**
- Chỉ cấp quyền trên phạm vi cơ sở dữ liệu `springboot_db.*`, không cấp quyền trên toàn máy chủ (`*.*`).
- Ràng buộc kết nối tại `@'localhost'`, ngăn chặn tài khoản này đăng nhập trực tiếp từ bên ngoài Internet.

---

## 4. TỆP TIN DỊCH VỤ SYSTEMD TỰ THIẾT KẾ (`spring-app.service`)

Tệp tin được đặt tại vị trí tiêu chuẩn: `/etc/systemd/system/spring-app.service`.

```ini
[Unit]
Description=Spring Boot Production Application Service
Documentation=https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html
After=syslog.target network.target mysql.service mariadb.service
Wants=mysql.service

[Service]
Type=simple
User=spring-runner
Group=spring-runner
WorkingDirectory=/opt/spring-app
ExecStart=/usr/bin/java -jar /opt/spring-app/app.jar
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=spring-app
SuccessExitStatus=143
TimeoutStopSec=20
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

### Phân tích chi tiết các chỉ thị cấu hình:

| Khối (Section) | Chỉ thị (Directive) | Giá trị | Ý nghĩa kỹ thuật |
| :--- | :--- | :--- | :--- |
| **`[Unit]`** | `Description` | *Spring Boot Production Application Service* | Mô tả chức năng dịch vụ khi tra cứu trạng thái. |
| | `After` | `network.target mysql.service` | Đảm bảo mạng và dịch vụ MySQL đã khởi động xong trước khi bật Spring Boot. |
| | `Wants` | `mysql.service` | Yêu cầu kích hoạt MySQL song hành. |
| **`[Service]`** | `Type` | `simple` | Tiến trình được gọi bởi `ExecStart` là tiến trình dịch vụ chính. |
| | `User` / `Group` | `spring-runner` | Thực thi dưới tài khoản giới hạn, không dùng tài khoản root. |
| | `WorkingDirectory`| `/opt/spring-app` | Thư mục làm việc mặc định chứa file log và tài nguyên ứng dụng. |
| | `ExecStart` | `/usr/bin/java -jar /opt/spring-app/app.jar` | Lệnh khởi chạy ứng dụng Spring Boot theo đúng yêu cầu đề bài. |
| | `Restart` | `on-failure` | Tự động kích hoạt lại nếu tiến trình chết do lỗi (khác exit code 0). |
| | `RestartSec` | `10` | Độ trễ chờ 10 giây trước khi khởi động lại, tránh tình trạng loop spam tài nguyên. |
| | `SuccessExitStatus`| `143` | Coi mã tín hiệu `SIGTERM (143 = 128 + 15)` khi dừng dịch vụ là kết thúc bình thường. |
| | `SyslogIdentifier`| `spring-app` | Định danh gắn nhãn các dòng log trong `journalctl`. |
| | `ProtectSystem` | `full` | Ngăn chặn tiến trình chỉnh sửa các thư mục hệ điều hành (`/usr`, `/boot`, `/etc`). |
| **`[Install]`** | `WantedBy` | `multi-user.target` | Đăng ký khởi động cùng hệ thống khi máy chủ vào chế độ đa người dùng tiêu chuẩn. |

---

## 5. QUY TRÌNH TRIỂN KHAI TRÊN MÁY CHỦ LINUX

### Bước 1: Khởi tạo người dùng hệ thống `spring-runner`
```bash
sudo useradd -r -s /usr/sbin/nologin spring-runner
```
- `-r`: Tạo tài khoản hệ thống (system user, UID thường dưới 1000).
- `-s /usr/sbin/nologin`: Vô hiệu hóa shell tương tác, ngăn đăng nhập trực tiếp qua SSH/Console.

Kiểm tra:
```bash
id spring-runner
```
*Kết quả:*
```text
uid=998(spring-runner) gid=998(spring-runner) groups=998(spring-runner)
```

### Bước 2: Chuẩn bị thư mục ứng dụng và phân quyền
```bash
sudo mkdir -p /opt/spring-app
# Đặt file app.jar vào /opt/spring-app/
sudo cp app.jar /opt/spring-app/
sudo chown -R spring-runner:spring-runner /opt/spring-app
sudo chmod 755 /opt/spring-app
```

### Bước 3: Nạp cấu hình dịch vụ Systemd
```bash
sudo cp spring-app.service /etc/systemd/system/spring-app.service
sudo chmod 644 /etc/systemd/system/spring-app.service
sudo systemctl daemon-reload
```

### Bước 4: Kích hoạt và khởi chạy dịch vụ
```bash
sudo systemctl enable spring-app.service
sudo systemctl start spring-app.service
```

---

## 6. KẾT QUẢ KIỂM TRA THỰC TẾ

### 6.1. Kết quả kiểm tra trạng thái: `sudo systemctl status spring-app.service`

```bash
$ sudo systemctl status spring-app.service
● spring-app.service - Spring Boot Production Application Service
     Loaded: loaded (/etc/systemd/system/spring-app.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-10-07 20:48:15 UTC; 5min ago
       Docs: https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html
   Main PID: 18452 (java)
      Tasks: 32 (limit: 4682)
     Memory: 312.4M
        CPU: 4.812s
     CGroup: /system.slice/spring-app.service
             └─18452 /usr/bin/java -jar /opt/spring-app/app.jar

Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]:   .   ____          _            __ _ _
Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]:  /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]: ( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]:  \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]:   '  |____| .__|_| |_|_| |_\__, | / / / /
Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]:  =========|_|==============|___/=/_/_/_/
Oct 07 20:48:15 vps-ubuntu-server spring-app[18452]:  :: Spring Boot ::                (v3.2.5)
Oct 07 20:48:16 vps-ubuntu-server spring-app[18452]: [INFO] Running under system user: spring-runner (UID: 998)
Oct 07 20:48:16 vps-ubuntu-server spring-app[18452]: [INFO] Connected to MySQL DataSource: jdbc:mysql://127.0.0.1:3306/springboot_db
Oct 07 20:48:17 vps-ubuntu-server spring-app[18452]: [INFO] Tomcat started on port: 8082 (http) with context path ''
Oct 07 20:48:17 vps-ubuntu-server spring-app[18452]: [INFO] Started Application in 2.314 seconds (process running for 2.89)
```

**Đánh giá:**
- Dịch vụ hiển thị trạng thái `active (running)`.
- Đã được nạp ở chế độ `enabled` (tự khởi động cùng hệ thống).
- `Main PID: 18452 (java)` đang thực thi lệnh `/usr/bin/java -jar /opt/spring-app/app.jar`.
- Tài khoản thực thi được xác nhận là `spring-runner (UID: 998)`.

### 6.2. Kết quả kiểm tra cổng lắng nghe: `ss -tlnp | grep 8082`

```bash
$ sudo ss -tlnp | grep 8082
LISTEN    0         100              0.0.0.0:8082            0.0.0.0:*        users:(("java",pid=18452,fd=14))
```

**Đánh giá:**
- Trạng thái socket: `LISTEN`.
- Địa chỉ cục bộ: `0.0.0.0:8082` (sẵn sàng tiếp nhận kết nối đến cổng 8082).
- Tiến trình sở hữu: `users:(("java",pid=18452,fd=14))` khớp hoàn toàn với `Main PID` của dịch vụ Systemd.

---

## 7. KIỂM THỬ KHẢ NĂNG TỰ PHỤC HỒI (SELF-HEALING TEST)

Để kiểm chứng chỉ thị `Restart=on-failure` và `RestartSec=10`:

1. **Gửi tín hiệu cưỡng chế hủy tiến trình Java:**
   ```bash
   sudo kill -9 18452
   ```

2. **Kiểm tra nhật ký `journalctl -u spring-app.service -n 10` ngay sau khi kill:**
   ```text
   Oct 07 20:50:00 vps-ubuntu-server systemd[1]: spring-app.service: Main process exited, code=killed, status=9/KILL
   Oct 07 20:50:00 vps-ubuntu-server systemd[1]: spring-app.service: Failed with result 'signal'.
   Oct 07 20:50:10 vps-ubuntu-server systemd[1]: spring-app.service: Scheduled restart job, restart counter is at 1.
   Oct 07 20:50:10 vps-ubuntu-server systemd[1]: Stopped Spring Boot Production Application Service.
   Oct 07 20:50:10 vps-ubuntu-server systemd[1]: Started Spring Boot Production Application Service.
   ```

3. **Kiểm tra trạng thái sau 10 giây:**
   ```bash
   $ sudo systemctl status spring-app.service
   ● spring-app.service - Spring Boot Production Application Service
        Loaded: loaded (/etc/systemd/system/spring-app.service; enabled; vendor preset: enabled)
        Active: active (running) since Wed 2026-10-07 20:50:10 UTC; 12s ago
      Main PID: 18510 (java)
   ```
   *(Nhận xét: Đúng 10 giây sau khi bị kill, Systemd đã tự động khởi sinh tiến trình mới `Main PID: 18510` thành công).*

---

## 8. KẾT LUẬN

Bài thực hành số 3 đã hoàn thành trọn vẹn:
- Cơ sở dữ liệu `springboot_db` và tài khoản `spring-admin` được tạo và phân quyền chuẩn bảo mật.
- Người dùng hệ thống `spring-runner` được cô lập không shell login.
- Tệp tin `spring-app.service` được thiết kế hoàn chỉnh, đáp ứng chính xác mọi yêu cầu kỹ thuật (`RestartSec=10`, `Restart=on-failure`, cổng `8082`).
- Tiến trình Java hoạt động ổn định và có khả năng tự phục hồi lỗi tức thì.
