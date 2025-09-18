## 自动 SSL 证书续签 (CertGuard V4 - 混合密钥版)

本项目包含一个 GitHub Actions 工作流，用于自动检查并续签部署在**多台远程服务器**上的 SSL 证书。它利用**矩阵策略 (Matrix Strategy)** 为您定义的每台服务器并行执行检查任务，并支持**共享密钥**与**独立密钥**的混合使用。

工作流在每台服务器上支持两种操作模式：
- **单域名模式**：在服务器配置中提供 `domain` 时激活，仅检查该特定域名。
- **全盘扫描模式**：在服务器配置中 `domain` 为空时激活，自动扫描该服务器上所有证书。

### 快速开始

1.  **确认工作流文件**：确保 `.github/workflows/check-renew-ssl.yml` 是最新版本。
2.  **设置 GitHub Secrets**：这是最关键的一步，用于安全地存储所有目标服务器的连接信息和私钥。

### 如何设置 GitHub Secrets

新版工作流采用高度灵活的密钥管理策略，使用 `SSH_TARGETS` 和一个可选的 `SSH_KEY` Secret。

1.  在你的 GitHub 仓库页面，点击 **Settings** > **Secrets and variables** > **Actions**。
2.  创建以下 Secrets：

#### 1. `SSH_KEY` (可选的全局共享密钥)
*   **内容**: 一个全局共享的 SSH 私钥。当 `SSH_TARGETS` 中的服务器对象**未**提供自己的 `ssh_key` 时，将默认使用此密钥。
*   **示例**: `-----BEGIN OPENSSH PRIVATE KEY...`

#### 2. `SSH_TARGETS` (必需，服务器定义列表)
*   **内容**: 一个 JSON 数组，其中每个对象代表一台服务器的完整配置。您可以在这里为特定服务器内联其独立的 SSH 私钥。
*   **示例**:
    ```json
    [
      {
        "name": "WebApp (使用全局共享密钥)",
        "host": "192.0.2.1",
        "user": "deployer1",
        "renew_cmd": "sudo certbot renew --quiet",
        "reload_cmd": "sudo systemctl reload nginx"
      },
      {
        "name": "API Server (使用独立密钥)",
        "host": "192.0.2.2",
        "user": "deployer2",
        "renew_cmd": "~/.acme.sh/acme.sh --renew-all",
        "reload_cmd": "sudo systemctl reload apache2",
        "ssh_key": "-----BEGIN OPENSSH PRIVATE KEY-----\n...your private key content...\n-----END OPENSSH PRIVATE KEY-----"
      }
    ]
    ```

*   **JSON 字段说明**:
    *   `name`, `host`, `user`, `renew_cmd`, `reload_cmd`: (必需) 服务器基础信息和命令。
    *   `ssh_key`: (可选) **服务器独立密钥**。如果提供，则**仅对此服务器**使用该密钥。如果省略，则此服务器将使用全局的 `SSH_KEY` Secret。
    *   `port`, `domain`, `cert_path`, `cert_scan_path`: (可选) 其他精细化配置。

> **⚠️ 重要提示：内联 `ssh_key` 的格式**
> 由于 JSON 字符串不支持原生多行文本，您在 `ssh_key` 字段中粘贴私钥时，必须将所有的**换行符**手动替换为 `\n`，使其成为一个符合 JSON 规范的单行字符串。

### 如何选择 `certbot` 与 `acme.sh`

| 工具 | 优点 | 缺点 | 防火墙注意 |
| :--- | :--- | :--- | :--- |
| **Certbot** | - 官方推荐，社区支持好<br>- 与 Nginx/Apache 插件集成度高<br>- 通常由系统包管理器安装，易于管理 | - 可能需要 root 权限<br>- 依赖 Python 环境 | 续签时通常需要开放 **80 端口** 以完成 `http-01` 质询。 |
| **acme.sh** | - 单个 Shell 脚本，无依赖<br>- 无需 root 权限即可运行<br>- 支持海量 DNS API，便于签发泛域名证书 | - 社区相对较小<br>- 配置方式与 Certbot 不同 | 同样，`http-01` 质询需要开放 **80 端口**。若使用 `dns-01` 质询则无此要求。 |

### 常见错误排查

如果 Actions 失败，请检查以下几点：

1.  **SSH 连接失败**：
    *   `host`, `user` 是否正确？
    *   使用的 `ssh_key` (无论是独立的还是共享的) 是否正确、完整且有权访问服务器？
    *   服务器防火墙是否允许来自 GitHub Actions Runner IP 地址的 SSH 连接？

2.  **无法获取证书日期** (`openssl s_client` 失败)：
    *   **DNS 解析**：在服务器上 `ping your.domain.com` 或 `nslookup your.domain.com` 确认能解析到正确的 IP。
    *   **防火墙**：确保服务器的 `443` 端口（或 `port`）对公网开放。
    *   **Web 服务**：确保 Nginx/Apache 正在运行，并且 SSL 配置正确。

3.  **续签/重载失败** (权限问题):
    *   `user` 用户是否有权限执行 `renew_cmd` 和 `reload_cmd`？通常这些命令需要 `sudo`。
    *   **解决方案**：为 `user` 配置免密 `sudo`。创建一个新文件 `sudo visudo -f /etc/sudoers.d/deployer` 并添加以下内容（以 `certbot` 和 `nginx` 为例）：
        ```
        deployer ALL=(ALL) NOPASSWD: /usr/bin/certbot, /bin/systemctl reload nginx
        ```
        请根据你的实际命令路径和用户名进行调整。

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
