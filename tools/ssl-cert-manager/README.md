# SSL 证书管理工具 - CertGuard

智能自适应的 SSL 证书管理工具，支持自动检测证书管理工具（certbot/acme.sh）、服务类型和证书状态，提供完全自动化的证书续签解决方案。

## 功能特性

- 🤖 **智能检测**: 自动识别证书管理工具（certbot/acme.sh）和服务类型
- 🔄 **智能续签**: 检查证书有效期，仅在小于阈值时自动续签
- 🐳 **多环境支持**: 支持 Docker 容器、systemd 服务、传统进程
- 📊 **全面监控**: 扫描所有证书并报告状态
- 🚀 **一键部署**: 支持 GitHub Actions 自动化部署
- 🔐 **安全优先**: 通过 SSH 密钥和 Secrets 管理敏感信息
- 📝 **详细日志**: 彩色输出和完整的操作日志
- ⚙️ **灵活配置**: 支持多服务器和自定义配置
- 🎆 **简单易用**: 无需复杂配置，一条命令搞定

## 文件结构

```
tools/ssl-cert-manager/
├── cert_manager.sh           # 主要管理脚本
├── config.example.sh         # 配置文件示例
├── servers.example.json      # 多服务器配置示例
└── README.md                # 说明文档
```

## 快速开始

### 1. 准备工作

确保目标服务器已安装以下工具之一：
- **certbot**: Let's Encrypt 官方工具
- **acme.sh**: 轻量级 ACME 客户端

如果未安装，可以使用工具自动安装：

```bash
# 安装 certbot
./cert_manager.sh --mode install
```

### 2. 基本使用

```bash
# 赋予脚本执行权限
chmod +x cert_manager.sh

# 智能检查所有证书并按需续签
./cert_manager.sh

# 检查特定域名
./cert_manager.sh --domain example.com

# 使用自定义阈值
./cert_manager.sh --threshold 7

# 显示帮助信息
./cert_manager.sh --help
```

### 3. 配置文件使用

复制并编辑配置文件：

```bash
# 复制配置文件
cp config.example.sh config.sh

# 编辑配置
vim config.sh

# 使用配置文件
source config.sh && ./cert_manager.sh
```

## 详细使用指南

### 命令行参数

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--domain` | `-d` | 指定域名 | 空（所有域名） |
| `--threshold` | `-t` | 续签阈值天数 | 5 |
| `--path` | `-p` | 证书扫描路径 | /etc/letsencrypt/live |
| `--install` | - | 安装证书管理工具 | - |
| `--help` | `-h` | 显示帮助信息 | - |

### 工作原理

工具采用智能模式，自动执行以下流程：

1. 🔍 **检测环境**: 自动识别 certbot 或 acme.sh
2. 🔎 **扫描证书**: 检查所有或指定证书的有效期
3. ⚙️ **智能决策**: 仅在证书剩余天数 < 阈值时执行续签
4. 🔄 **自动续签**: 使用检测到的工具执行续签
5. 🔁 **服务重载**: 自动检测并重载相关服务
6. ✅ **结果验证**: 验证续签是否成功

### 使用示例

#### 1. 基本使用
```bash
# 智能检查所有证书并按需续签
./cert_manager.sh

# 检查特定域名
./cert_manager.sh --domain example.com

# 使用自定义阈值（7天）
./cert_manager.sh --threshold 7
```

#### 2. 高级配置
```bash
# 指定证书路径
./cert_manager.sh --path /opt/ssl/certificates

# 组合参数使用
./cert_manager.sh --domain example.com --threshold 7 --path /custom/path
```

#### 3. 初始化安装
```bash
# 自动安装 certbot
./cert_manager.sh --install
```

### 环境变量配置

可以通过环境变量设置默认值：

```bash
export RENEW_THRESHOLD_DAYS=7
export CERT_SCAN_PATH="/etc/letsencrypt/live"
export DOMAIN="example.com"

# 运行脚本（使用环境变量配置）
./cert_manager.sh
```

## GitHub Actions 集成

项目为新的 SSL 证书管理工具提供了完整的 GitHub Actions 工作流配置，支持灵活的多服务器自动化管理。

### 1. 配置 Secrets

在 GitHub 仓库中设置以下 Secrets（根据服务器数量配置）：

| Secret Name | 描述 | 示例 |
|-------------|------|------|
| `{SERVER_NAME}_HOST` | 服务器地址 | `example.com` |
| `{SERVER_NAME}_USERNAME` | SSH 用户名 | `deploy` |
| `{SERVER_NAME}_SSH_KEY` | SSH 私钥 | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `{SERVER_NAME}_PORT` | SSH 端口（可选） | `22` |

例如，对于生产服务器，配置：
- `PRODUCTION_HOST`
- `PRODUCTION_USERNAME` 
- `PRODUCTION_SSH_KEY`
- `PRODUCTION_PORT`

### 2. 新的工作流架构

项目包含以下新的 GitHub Actions 工作流：

#### 核心工作流
- `.github/workflows/reusable-ssl-cert-manager.yml` - **新的可复用 SSL 证书管理工作流**
- `.github/workflows/example-server-ssl-manager.yml` - 单服务器管理示例
- `.github/workflows/multi-server-ssl-manager.yml` - 多服务器管理示例

#### 传统工作流（保持不变）
- `.github/workflows/reusable-check-ssl.yml` - 原有的 SSL 检查工作流
- `.github/workflows/google-renew-ssl.yml` - Google 服务器 SSL 续签
- `.github/workflows/ugcap-renew-ssl.yml` - UGCAP 服务器 SSL 续签
- `.github/workflows/work-proxy-renew-ssl.yml` - Work Proxy 服务器 SSL 续签

### 3. 使用新工作流的优势

新的工作流 `reusable-ssl-cert-manager.yml` 相比传统工作流具有以下优势：

- ✅ **灵活的参数配置**: 支持域名、阈值、证书路径等参数
- ✅ **智能脚本上传**: 自动上传并执行最新的证书管理脚本
- ✅ **智能决策**: 自动检查并仅在需要时执行续签
- ✅ **详细日志输出**: 提供更丰富的执行信息和状态反馈
- ✅ **自动清理**: 执行完成后自动清理临时文件
- ✅ **简单易用**: 无需复杂的模式选择，一键搞定

### 4. 创建单服务器工作流

创建新的单服务器工作流文件：

```yaml
name: 'CertGuard: 我的服务器 SSL 管理'

on:
  schedule:
    - cron: '30 2 * * *'  # 每天凌晨2:30执行
  workflow_dispatch:
    inputs:
      domain:
        description: '指定域名 (留空检查所有)'
        type: string
        default: ''
      threshold_days:
        description: '续签阈值天数'
        type: number
        default: 5

jobs:
  ssl-management:
    uses: ./.github/workflows/reusable-ssl-cert-manager.yml
    with:
      server_name: "我的服务器"
      domain: ${{ inputs.domain || '' }}
      threshold_days: ${{ inputs.threshold_days || 5 }}
      cert_path: "/etc/letsencrypt/live"
    secrets:
      SERVER_HOST: ${{ secrets.MY_SERVER_HOST }}
      SERVER_USERNAME: ${{ secrets.MY_SERVER_USERNAME }}
      SERVER_SSH_KEY: ${{ secrets.MY_SERVER_SSH_KEY }}
      SERVER_PORT: ${{ secrets.MY_SERVER_PORT }}
```

### 5. 创建多服务器工作流

创建管理多台服务器的工作流：

```yaml
name: 'CertGuard: 多服务器 SSL 管理'

on:
  schedule:
    - cron: '0 1 * * 0'   # 每周日凌晨1点执行
  workflow_dispatch:
    inputs:
      target_server:
        type: choice
        options: [all, production, staging]
        default: 'all'

jobs:
  production:
    if: ${{ inputs.target_server == 'all' || inputs.target_server == 'production' }}
    uses: ./.github/workflows/reusable-ssl-cert-manager.yml
    with:
      server_name: "生产服务器"
      threshold_days: 5
    secrets:
      SERVER_HOST: ${{ secrets.PRODUCTION_HOST }}
      SERVER_USERNAME: ${{ secrets.PRODUCTION_USERNAME }}
      SERVER_SSH_KEY: ${{ secrets.PRODUCTION_SSH_KEY }}
      SERVER_PORT: ${{ secrets.PRODUCTION_PORT }}

  staging:
    if: ${{ inputs.target_server == 'all' || inputs.target_server == 'staging' }}
    uses: ./.github/workflows/reusable-ssl-cert-manager.yml
    with:
      server_name: "测试服务器"
      threshold_days: 7
    secrets:
      SERVER_HOST: ${{ secrets.STAGING_HOST }}
      SERVER_USERNAME: ${{ secrets.STAGING_USERNAME }}
      SERVER_SSH_KEY: ${{ secrets.STAGING_SSH_KEY }}
      SERVER_PORT: ${{ secrets.STAGING_PORT }}
```

### 6. 工作流参数说明

新工作流支持以下参数：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `server_name` | string | 必需 | 服务器显示名称 |
| `domain` | string | '' | 指定域名（留空检查所有） |
| `threshold_days` | number | 5 | 续签阈值天数 |
| `cert_path` | string | /etc/letsencrypt/live | 证书扫描路径 |

## 高级配置

### 多服务器管理

使用 `servers.example.json` 作为模板创建多服务器配置：

```json
{
  "servers": {
    "production": {
      "name": "生产服务器",
      "host": "prod.example.com",
      "username": "deploy",
      "renew_threshold_days": 5,
      "domains": ["example.com", "www.example.com"]
    }
  }
}
```

### 自定义重载命令

如果你有特殊的服务重载需求：

```bash
export CUSTOM_RELOAD_CMDS="sudo systemctl reload nginx; docker restart my-app"
```

### 通知集成

配置证书续签后的通知：

```bash
# 企业微信通知
export WECHAT_WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxx"

# 邮件通知  
export SMTP_HOST="smtp.example.com"
export SMTP_USER="notify@example.com"
export SMTP_PASS="password"
export MAIL_TO="admin@example.com"
```

## 支持的服务类型

工具会自动检测并支持以下服务的重载：

### Docker 容器
- Nginx 容器
- Apache 容器  
- Caddy 容器
- 其他代理容器

### 系统服务 (systemd)
- nginx / nginx-full / openresty
- apache2 / httpd / apache
- caddy
- haproxy
- traefik
- gost

### 传统进程
- Nginx 主进程
- Apache/HTTPD 进程

## 故障排除

### 常见问题

#### 1. 证书路径不存在
```
ERROR: 证书扫描路径 '/etc/letsencrypt/live' 不存在或不是一个目录
```
**解决方案**: 检查证书路径是否正确，或使用 `--path` 参数指定正确路径。

#### 2. 未检测到证书管理工具
```
ERROR: 未检测到 certbot 或 acme.sh，无法执行续签
```
**解决方案**: 运行 `./cert_manager.sh --mode install` 安装 certbot。

#### 3. 服务重载失败
```
ERROR: 服务重载失败！请检查相关日志
```
**解决方案**: 
- 检查服务是否正在运行
- 确认用户具有重载服务的权限
- 查看系统日志获取详细错误信息

#### 4. SSH 连接失败（GitHub Actions）
```
ERROR: SSH 连接失败
```
**解决方案**:
- 检查 Secrets 中的服务器信息是否正确
- 确认 SSH 私钥格式正确
- 验证服务器防火墙设置

### 调试模式

启用详细日志输出：

```bash
export LOG_LEVEL="DEBUG"
./cert_manager.sh --mode check
```

### 手动测试

在 GitHub Actions 中手动触发工作流进行测试：

1. 进入 GitHub 仓库的 "Actions" 页面
2. 选择相应的工作流
3. 点击 "Run workflow" 按钮
4. 选择分支并确认执行

## 最佳实践

### 1. 定期检查
- 建议设置每周检查一次证书状态
- 在证书到期前 5-7 天开始续签

### 2. 监控和通知
- 配置续签成功/失败的通知
- 定期检查工作流执行日志

### 3. 备份策略
- 在续签前自动备份现有证书
- 保留多个版本的证书备份

### 4. 安全建议
- 使用专门的部署用户，避免使用 root
- 定期轮换 SSH 密钥
- 限制 SSH 访问来源 IP

### 5. 测试环境
- 先在测试环境验证续签流程
- 使用 Let's Encrypt 的 staging 环境测试

## 版本历史

- **v1.0.0** - 初始版本，支持基本的证书检查和续签
- **v1.1.0** - 添加多服务器支持和 GitHub Actions 集成  
- **v1.2.0** - 智能服务检测和自动重载功能
- **v1.3.0** - 添加通知功能和高级配置选项

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

---

**注意**: 此工具需要适当的系统权限才能执行证书续签和服务重载操作。请确保在安全的环境中使用，并遵循最佳安全实践。