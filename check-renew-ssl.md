## 自动 SSL 证书续签 (CertGuard)

本项目包含一个 GitHub Actions 工作流，用于自动检查并续签部署在远程服务器上的 SSL 证书。

该工作流支持两种操作模式：
- **单域名模式**：设置 `DOMAIN` Secret 时激活，仅检查该特定域名。
- **全盘扫描模式**：不设置 `DOMAIN` Secret 时激活，自动扫描服务器上所有证书。

### 快速开始

1.  **复制工作流文件**：将 `.github/workflows/check-renew-ssl.yml` 文件添加到你的仓库中。
2.  **设置 GitHub Secrets**：这是最关键的一步，用于安全地存储敏感信息。

### 如何设置 GitHub Secrets

1.  在你的 GitHub 仓库页面，点击 **Settings** > **Secrets and variables** > **Actions**。
2.  点击 **New repository secret**，然后逐一添加以下 Secrets：

| Secret Name | 示例值 | 说明 |
| :--- | :--- | :--- |
| `SSH_HOST` | `192.0.2.1` | 你的远程服务器 IP 地址或域名。 |
| `SSH_USER` | `deployer` | 用于 SSH 登录的用户名。 |
| `SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY...` | SSH 私钥。**必须是 OpenSSH 格式**。通过 `cat ~/.ssh/id_rsa` 获取。 |
| `DOMAIN` | `example.com` | (可选) 指定一个域名以启用**单域名模式**。若留空，则激活**全盘扫描模式**。 |
| `RENEW_CMD` | `sudo certbot renew --quiet` | 在服务器上执行的续签命令。 |
| `RELOAD_CMD` | `sudo systemctl reload nginx` | 续签成功后重载 Web 服务的命令。 |
| `CERT_PORT` | `443` | (可选) 证书的 HTTPS 端口，默认为 443。 |
| `CERT_PATH` | `/etc/letsencrypt/live/example.com/fullchain.pem` | (可选) 在**单域名模式**下，直接读取本地证书文件，速度更快。 |
| `CERT_SCAN_PATH` | `/etc/letsencrypt/live` | (可选) 在**全盘扫描模式**下，指定存放证书的根目录。 |

### 如何选择 `certbot` 与 `acme.sh`

| 工具 | 优点 | 缺点 | 防火墙注意 |
| :--- | :--- | :--- | :--- |
| **Certbot** | - 官方推荐，社区支持好<br>- 与 Nginx/Apache 插件集成度高<br>- 通常由系统包管理器安装，易于管理 | - 可能需要 root 权限<br>- 依赖 Python 环境 | 续签时通常需要开放 **80 端口** 以完成 `http-01` 质询。 |
| **acme.sh** | - 单个 Shell 脚本，无依赖<br>- 无需 root 权限即可运行<br>- 支持海量 DNS API，便于签发泛域名证书 | - 社区相对较小<br>- 配置方式与 Certbot 不同 | 同样，`http-01` 质询需要开放 **80 端口**。若使用 `dns-01` 质询则无此要求。 |

**建议**：如果你的环境简单且有 root 权限，`certbot` 是一个稳妥的选择。如果你需要更强的灵活性、希望在非 root 用户下操作或使用 DNS 验证，`acme.sh` 是绝佳选择。

### 常见错误排查

如果 Actions 失败，请检查以下几点：

1.  **SSH 连接失败**：
    *   `SSH_HOST`, `SSH_USER` 是否正确？
    *   `SSH_KEY` 是否为完整的、正确的 OpenSSH 格式私钥？
    *   服务器防火墙是否允许来自 GitHub Actions Runner IP 地址的 SSH 连接？

2.  **无法获取证书日期** (`openssl s_client` 失败)：
    *   **DNS 解析**：在服务器上 `ping your.domain.com` 或 `nslookup your.domain.com` 确认能解析到正确的 IP。
    *   **防火墙**：确保服务器的 `443` 端口（或 `CERT_PORT`）对公网开放。
    *   **Web 服务**：确保 Nginx/Apache 正在运行，并且 SSL 配置正确。

3.  **续签/重载失败** (权限问题):
    *   `SSH_USER` 用户是否有权限执行 `RENEW_CMD` 和 `RELOAD_CMD`？通常这些命令需要 `sudo`。
    *   **解决方案**：为 `SSH_USER` 配置免密 `sudo`。创建一个新文件 `sudo visudo -f /etc/sudoers.d/deployer` 并添加以下内容（以 `certbot` 和 `nginx` 为例）：
        ```
        deployer ALL=(ALL) NOPASSWD: /usr/bin/certbot, /bin/systemctl reload nginx
        ```
        请根据你的实际命令路径进行调整。

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

*   **SAN/多域名证书说明**：
    `openssl s_client` 的 `-servername` 参数用于处理 SNI (服务器名称指示)。对于一张包含多个域名的 SAN 证书，只需指定主域名进行检测即可获取整张证书的信息。本方案已默认支持此场景。