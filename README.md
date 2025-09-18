## 自动 SSL 证书续签 (CertGuard - 智能自适应最终版)

本项目包含一个 GitHub Actions 工作流，用于自动检查并续签部署在**多台远程服务器**上的 SSL 证书。它具备以下特性：

- **并行执行**：利用矩阵策略（Matrix Strategy）为您列表中的每台服务器并行执行检查任务。
- **配置极简**：仅需配置 3 个基础 Secret，无需指定任何命令。
- **智能检测**：远程脚本会自动检测服务器环境，以确定使用何种续签和重载命令。
- **模式统一**：默认对所有服务器执行“全盘扫描”模式，检查所有找到的证书。

### 快速开始

1.  **确认工作流文件**：确保 `.github/workflows/check-renew-ssl.yml` 是最新版本。
2.  **设置 GitHub Secrets**：这是使用本方案唯一需要您配置的步骤。

### 如何设置 GitHub Secrets

最终版的智能工作流仅需 3 个 Secret。请在您的 GitHub 仓库 **Settings** > **Secrets and variables** > **Actions** 页面配置它们：

1.  **`SSH_HOSTS`** (必需)
    *   **内容**: 一个用**逗号**分隔的服务器 IP 或域名列表。
    *   **示例**: `192.0.2.1,server2.example.com,192.0.2.3`

2.  **`SSH_USER`** (必需)
    *   **内容**: 用于登录所有服务器的**同一个**用户名。
    *   **示例**: `root` 或 `deployer`

3.  **`SSH_KEY`** (必需)
    *   **内容**: 所有服务器**共享**的 SSH 私钥。
    *   **示例**: `-----BEGIN OPENSSH PRIVATE KEY...`

### 智能检测逻辑 (Auto-Detection Logic)

您无需再手动配置续签和重载命令，远程脚本会按以下顺序自动检测并选择合适的命令：

#### 续签命令检测
1.  检查 `certbot` 命令是否存在？ -> 是：使用 `sudo certbot renew`
2.  否则，检查 `~/.acme.sh/acme.sh` 是否存在？ -> 是：使用 `acme.sh --renew-all`
3.  否则，报错退出。

#### 重载命令检测
1.  检查是否存在名为 `nginx` 的 Docker 容器？ -> 是：使用 `docker exec <container> nginx -s reload`
2.  否则，检查 `nginx.service` 是否在运行？ -> 是：使用 `sudo systemctl reload nginx`
3.  否则，检查 `apache2.service` 或 `httpd.service` 是否在运行？ -> 是：使用 `sudo systemctl reload apache2` 或 `httpd`
4.  否则，检查 `gost.service` 是否在运行？ -> 是：使用 `sudo systemctl reload gost`
5.  否则，报错退出。

### 常见错误排查

如果 Actions 失败，请检查以下几点：

1.  **SSH 连接失败**：
    *   `SSH_HOSTS` 中的 IP/域名是否正确？ `SSH_USER` 是否正确？
    *   `SSH_KEY` 是否为正确的、完整的、且有权访问所有目标服务器的私钥？
    *   服务器防火墙是否允许来自 GitHub Actions Runner IP 地址的 SSH 连接？

2.  **命令检测失败或权限不足**:
    *   确保您的服务器上安装了 `certbot` 或 `acme.sh`。
    *   确保 `SSH_USER` 用户有权限执行 `sudo` 命令，或有权免密执行 `docker` 命令。
    *   **解决方案**：为 `SSH_USER` 配置免密 `sudo`。创建一个新文件 `sudo visudo -f /etc/sudoers.d/deployer` 并添加相关命令的免密权限。

### 本地快速验证命令

你可以在本地或服务器上使用这些命令快速诊断问题。

*   **网络探测模式** (检查 `example.com` 的证书)：
    ```sh
    echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -enddate -noout
    ```

*   **本地证书模式** (直接读取文件)：
    ```sh
    openssl x509 -enddate -noout -in /etc/letsencrypt/live/example.com/fullchain.pem
    ```