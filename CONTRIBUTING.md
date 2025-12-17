# 🤝 Contributing to N8N Setup Script

Cảm ơn bạn đã quan tâm đến việc đóng góp cho dự án! Mọi đóng góp đều được chào đón.

## 🎯 Cách đóng góp

### 🐛 Báo lỗi (Bug Reports)

1. **Kiểm tra** xem lỗi đã được báo cáo chưa trong [Issues](https://github.com/ndoanh266/setup-n8n/issues)
2. **Tạo issue mới** với template có sẵn
3. **Cung cấp thông tin chi tiết**:
   - Hệ điều hành
   - Các bước tái tạo lỗi
   - Log files/error messages
   - Screenshots (nếu có)

### 💡 Đề xuất tính năng (Feature Requests)

1. **Tạo issue** với label `enhancement`
2. **Mô tả chi tiết**:
   - Tính năng muốn thêm
   - Lý do cần thiết
   - Cách implement (nếu có ý tưởng)

### 🔧 Đóng góp code

#### **Quy trình:**

1. **Fork** repository
2. **Tạo branch** cho feature/bugfix:
   ```bash
   git checkout -b feature/amazing-feature
   # hoặc
   git checkout -b bugfix/fix-something
   ```
3. **Commit** với message rõ ràng:
   ```bash
   git commit -m "feat: add amazing feature"
   git commit -m "fix: resolve issue with backup"
   ```
4. **Push** branch:
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Tạo Pull Request**

#### **Coding Standards:**

- **Bash scripting**: Tuân thủ [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Comments**: Viết comment bằng tiếng Việt cho user-facing messages
- **Error handling**: Luôn có error handling cho các function quan trọng
- **Testing**: Test trên ít nhất 2 platform (Ubuntu + 1 khác)

#### **Commit Message Format:**

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: Tính năng mới
- `fix`: Sửa lỗi
- `docs`: Cập nhật documentation
- `style`: Formatting, missing semicolons, etc
- `refactor`: Code refactoring
- `test`: Thêm tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(backup): add automatic cleanup for old backups
fix(install): resolve Docker permission issue on Ubuntu
docs(readme): update installation guide for macOS
```

### 📚 Cải thiện Documentation

- **README.md**: Hướng dẫn chính
- **QUICKSTART.md**: Hướng dẫn nhanh
- **Code comments**: Giải thích logic phức tạp
- **Examples**: Thêm ví dụ sử dụng

## 🧪 Testing

### **Trước khi submit PR:**

1. **Syntax check**:
   ```bash
   bash -n n8n.sh
   ```

2. **Test trên multiple platforms**:
   - Ubuntu 20.04+ (required)
   - Debian/CentOS/macOS (optional)

3. **Test các chức năng chính**:
   ```bash
   # Test menu
   sudo ./n8n.sh
   
   # Test command line
   sudo ./n8n.sh status
   sudo ./n8n.sh backup
   ```

4. **Kiểm tra security**:
   - File permissions
   - Input validation
   - No hardcoded secrets

## 📋 Pull Request Checklist

- [ ] Code tuân thủ style guide
- [ ] Đã test trên ít nhất 1 platform
- [ ] Documentation được cập nhật (nếu cần)
- [ ] Commit messages rõ ràng
- [ ] No breaking changes (hoặc có ghi chú)
- [ ] Đã thêm/cập nhật tests (nếu cần)

## 🎨 UI/UX Guidelines

### **Menu Design:**
- Sử dụng emoji để dễ nhận diện
- Màu sắc consistent (Blue/Green/Yellow/Red)
- Messages bằng tiếng Việt
- Progress indicators cho long-running tasks

### **Error Messages:**
- Rõ ràng, dễ hiểu
- Đề xuất cách khắc phục
- Include relevant context

### **Success Messages:**
- Positive feedback
- Next steps (nếu có)
- Relevant information

## 🌟 Recognition

Tất cả contributors sẽ được ghi nhận trong:
- **CHANGELOG.md**
- **README.md** (Contributors section)
- **GitHub Contributors** page

## 📞 Liên hệ

Có câu hỏi về contributing?

- 📧 **Email**: nguyendoanh266@gmail.com
- 💬 **Telegram**: [@marketingvn_net](https://t.me/marketingvn_net)
- 🐛 **Issues**: [GitHub Issues](https://github.com/ndoanh266/setup-n8n/issues)

## 📄 Code of Conduct

### **Cam kết của chúng tôi:**

- **Tôn trọng** mọi người bất kể background
- **Chào đón** newcomers và beginners
- **Constructive feedback** thay vì criticism
- **Focus** vào việc cải thiện dự án

### **Không chấp nhận:**

- Harassment hoặc discriminatory language
- Personal attacks
- Spam hoặc off-topic discussions
- Sharing private information

---

**Cảm ơn bạn đã đóng góp cho cộng đồng Vietnamese Developer! 🇻🇳**