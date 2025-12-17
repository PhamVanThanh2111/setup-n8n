# 🚀 Quick Start - Cài đặt N8N trong 5 phút

> **Hướng dẫn nhanh để có N8N chạy trong vòng 5 phút!**

## ⚡ Cài đặt siêu nhanh

### 1️⃣ **Tải và chạy script (1 dòng lệnh)**

```bash
# Linux/macOS/WSL
curl -fsSL https://raw.githubusercontent.com/ndoanh266/setup-n8n/main/n8n.sh | sudo bash
```

### 2️⃣ **Hoặc tải về rồi chạy**

```bash
# Tải script
wget https://raw.githubusercontent.com/ndoanh266/setup-n8n/main/n8n.sh

# Cấp quyền và chạy
chmod +x n8n.sh
sudo ./n8n.sh
```

## 🔧 Chuẩn bị trước (2 phút)

### **Bước 1: Tạo Cloudflare Tunnel**

1. Truy cập: https://one.dash.cloudflare.com/
2. Chọn **Access** > **Tunnels** > **Create a tunnel**
3. Đặt tên: `n8n-tunnel`
4. **Copy token** (dạng: `eyJhIjoiXXXXXX...`)

### **Bước 2: Chuẩn bị domain**

- **Có domain**: Thêm vào Cloudflare
- **Chưa có**: Dùng miễn phí từ [DuckDNS](https://www.duckdns.org/)

## 🎯 Chạy script (3 phút)

### **Menu sẽ hiện ra:**

```
================================================
    N8N MANAGEMENT SCRIPT
================================================

Chọn hành động:
1. 🚀 Cài đặt N8N mới (với Cloudflare Tunnel)
...
```

### **Chọn `1` và làm theo hướng dẫn:**

1. **Nhập Cloudflare Token** (đã copy ở bước 1)
2. **Nhập hostname** (ví dụ: `n8n.yourdomain.com`)
3. **Đợi script tự động cài đặt** (2-3 phút)

## ✅ Hoàn thành!

### **Truy cập N8N:**
- URL: `https://your-hostname.com`
- Tạo tài khoản admin đầu tiên
- Bắt đầu tạo workflow!

## 🔄 Các lệnh hữu ích

```bash
# Kiểm tra trạng thái
sudo ./n8n.sh status

# Backup dữ liệu
sudo ./n8n.sh backup

# Update N8N
sudo ./n8n.sh update

# Backup + Update
sudo ./n8n.sh backup-update
```

## 🆘 Gặp vấn đề?

### **Lỗi thường gặp:**

```bash
# Lỗi permission
sudo chmod +x n8n.sh

# Lỗi Docker
sudo systemctl start docker

# Kiểm tra logs
sudo ./n8n.sh status
```

### **Cần hỗ trợ:**
- 📖 [README đầy đủ](README.md)
- 🐛 [Báo lỗi](https://github.com/ndoanh266/setup-n8n/issues)
- 💬 [Telegram](https://t.me/marketingvn_net)

---

**🎉 Chúc mừng! Bạn đã có N8N server riêng!**