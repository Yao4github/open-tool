# 企业微信值班通知工具

自动通过 GitHub Actions 定时发送企业微信值班通知，包含今日值班和明日值班员工信息。

## 功能特性

- 🕒 定时自动发送值班通知
- 📱 支持企业微信机器人 Markdown 格式消息
- 👥 支持多种值班排班模式：
  - 按日循环轮值
  - 按周固定值班
  - 特殊日期单独配置
- 🤖 通过 GitHub Actions 自动执行
- ⚙️ 灵活的配置文件管理

## 文件结构

```
tools/wechat-duty-notification/
├── wechat_notification.py     # 主要脚本
├── duty_schedule.json         # 值班排班配置
├── requirements.txt           # Python 依赖
└── README.md                  # 说明文档
```

## 快速开始

### 1. 获取企业微信机器人 Webhook URL

1. 在企业微信群聊中，点击右上角 "..." → "群机器人"
2. 选择 "添加群机器人" → "自定义机器人"
3. 设置机器人名称，复制生成的 Webhook URL
4. **重要：保存好这个 URL，格式类似：**
   ```
   https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxxxxx
   ```

### 2. 配置 GitHub Secrets

1. 在你的 GitHub 仓库中，进入 "Settings" → "Secrets and variables" → "Actions"
2. 点击 "New repository secret"
3. 添加以下 Secret：
   - **Name:** `WECHAT_WEBHOOK`
   - **Value:** 你的企业微信机器人 Webhook URL

### 3. 配置值班排班

编辑 `duty_schedule.json` 文件，配置你的值班安排：

```json
{
  "daily_rotation": {
    "start_date": "2024-01-01",
    "employees": [
      {
        "name": "张三",
        "department": "技术部",
        "phone": "138****1234"
      }
    ]
  }
}
```

### 4. 自定义通知时间

工具使用项目根目录的 GitHub Actions 工作流 `.github/workflows/wechat_duty_notification.yml`。

修改其中的 cron 表达式来调整通知时间：

```yaml
schedule:
  # 每天上午 9:00 北京时间 (UTC+8 01:00)
  - cron: '0 1 * * *'
  # 每天下午 2:30 北京时间 (UTC+8 06:30)
  - cron: '30 6 * * *'
```

## 配置说明

### 值班排班配置 (duty_schedule.json)

支持三种配置模式，优先级从高到低：

#### 1. 特殊日期配置 (special_dates)
```json
"special_dates": {
  "2024-12-25": {
    "name": "值班经理",
    "department": "管理层",
    "phone": "188****0000"
  }
}
```

#### 2. 周固定值班配置 (weekly_schedule)
```json
"weekly_schedule": {
  "monday": {
    "name": "张三",
    "department": "技术部",
    "phone": "138****1234"
  }
}
```

#### 3. 日循环轮值配置 (daily_rotation)
```json
"daily_rotation": {
  "start_date": "2024-01-01",
  "employees": [
    {
      "name": "张三",
      "department": "技术部",
      "phone": "138****1234"
    }
  ]
}
```

### 时间配置

**重要：GitHub Actions 使用 UTC 时间，需要转换为北京时间 (UTC+8)**

常用时间对照表：
- 北京时间 09:00 → UTC 01:00 → cron: `'0 1 * * *'`
- 北京时间 14:30 → UTC 06:30 → cron: `'30 6 * * *'`
- 北京时间 18:00 → UTC 10:00 → cron: `'0 10 * * *'`

## 本地测试

### 安装依赖
```bash
cd tools/wechat-duty-notification
pip install -r requirements.txt
```

### 设置环境变量
```bash
export WECHAT_WEBHOOK="你的企业微信机器人Webhook URL"
```

### 运行脚本
```bash
python wechat_notification.py
```

## 手动触发通知

1. 进入 GitHub 仓库的 "Actions" 页面
2. 选择 "企业微信值班通知" 工作流
3. 点击 "Run workflow" 按钮
4. 确认运行

## 消息格式示例

脚本会发送以下格式的 Markdown 消息：

```
# 📋 值班通知

**今日值班 (2024-09-27 Friday)**
👤 值班人员: 张三
🏢 所属部门: 技术部
📞 联系电话: 138****1234

**明日值班 (2024-09-28 Saturday)**
👤 值班人员: 李四
🏢 所属部门: 运维部
📞 联系电话: 139****5678

---
⏰ 通知时间: 2024-09-27 09:00:15
🤖 自动发送 by GitHub Actions
```

## 常见问题

### Q: 为什么通知没有发送？
A: 请检查：
1. GitHub Secrets 中的 `WECHAT_WEBHOOK` 是否正确设置
2. 企业微信机器人是否还有效
3. GitHub Actions 工作流是否正常运行

### Q: 如何修改通知时间？
A: 修改项目根目录的 `.github/workflows/wechat_duty_notification.yml` 文件中的 cron 表达式，注意时区转换。

### Q: 如何临时停止通知？
A: 可以在 GitHub 仓库的 Actions 页面禁用对应的工作流。

### Q: 支持多个群聊发送吗？
A: 目前版本支持单个群聊，如需多群聊可以添加多个 Webhook URL 的环境变量。

## 安全提醒

- ⚠️ 绝对不要在代码中直接写入 Webhook URL
- ⚠️ 使用 GitHub Secrets 安全存储敏感信息
- ⚠️ 定期检查和更新企业微信机器人配置
- ⚠️ 员工联系信息请注意隐私保护

## 版本历史

- v1.0.0 - 初始版本，支持基本的值班通知功能