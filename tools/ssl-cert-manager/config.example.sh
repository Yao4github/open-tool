#!/bin/bash
# SSL 证书管理工具配置文件示例
# 复制此文件为 config.sh 并根据实际情况修改

# --- 证书管理基础配置 ---
export RENEW_THRESHOLD_DAYS=5              # 续签阈值天数，证书剩余天数小于此值时触发续签
export CERT_SCAN_PATH="/etc/letsencrypt/live"  # 证书扫描路径，默认为 Let's Encrypt 证书存储路径

# --- 域名配置 ---
# 单域名操作时使用，留空则对所有域名进行操作
export DOMAIN=""

# --- 多服务器配置示例 ---
# 如果你有多台服务器需要管理 SSL 证书，可以配置以下服务器信息
# 这些配置主要用于 GitHub Actions 工作流

# 服务器1 - 生产环境
export PROD_SERVER_HOST="your-production-server.com"
export PROD_SERVER_USERNAME="deploy"
export PROD_SERVER_PORT="22"
# 注意：SSH 私钥应该通过 GitHub Secrets 管理，不要在此文件中明文存储

# 服务器2 - 测试环境
export TEST_SERVER_HOST="your-test-server.com"
export TEST_SERVER_USERNAME="deploy"
export TEST_SERVER_PORT="22"

# --- 通知配置 (可选) ---
# 如果需要在证书续签后发送通知，可以配置以下选项

# 企业微信通知
export WECHAT_WEBHOOK=""  # 企业微信机器人 Webhook URL

# 邮件通知
export SMTP_HOST=""       # SMTP 服务器
export SMTP_PORT="587"    # SMTP 端口
export SMTP_USER=""       # SMTP 用户名
export SMTP_PASS=""       # SMTP 密码
export MAIL_TO=""         # 收件人邮箱

# --- 自定义命令配置 ---
# 如果你有特殊的证书管理需求，可以自定义命令

# 自定义续签前钩子命令
export PRE_RENEW_HOOK=""

# 自定义续签后钩子命令  
export POST_RENEW_HOOK=""

# 自定义重载命令 (会覆盖自动检测的命令)
export CUSTOM_RELOAD_CMDS=""

# --- 日志配置 ---
export LOG_LEVEL="INFO"   # 日志级别: DEBUG, INFO, WARN, ERROR
export LOG_FILE="/var/log/ssl-cert-manager.log"  # 日志文件路径

# --- 备份配置 ---
export BACKUP_ENABLED="true"                     # 是否启用证书备份
export BACKUP_PATH="/backup/ssl-certificates"    # 证书备份路径
export BACKUP_RETENTION_DAYS=30                  # 备份保留天数