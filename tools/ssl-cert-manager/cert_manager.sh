#!/bin/bash
# SSL 证书管理脚本 - CertGuard 智能自适应版本
# 支持 certbot 和 acme.sh，智能检测并管理 SSL 证书

set -euo pipefail

# --- 配置参数 ---
RENEW_THRESHOLD_DAYS="${RENEW_THRESHOLD_DAYS:-5}"
CERT_SCAN_PATH="${CERT_SCAN_PATH:-/etc/letsencrypt/live}"
DOMAIN="${DOMAIN:-}"

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- 辅助函数 ---
log() { echo -e "[${GREEN}INFO${NC}] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
warn() { echo -e "[${YELLOW}WARN${NC}] $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
error() { echo -e "[${RED}ERROR${NC}] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; exit 1; }
step_start() { log "=== 开始执行: $1 ==="; }
step_end() { log "=== 完成执行: $1 ===\n"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }

# --- 显示帮助信息 ---
show_help() {
    cat << EOF
${BLUE}SSL 证书管理工具 - CertGuard${NC}

用法: $0 [选项]

选项:
  -d, --domain DOMAIN       指定域名 (用于单域名操作)
  -t, --threshold DAYS      续签阈值天数 (默认: 5)
  -p, --path PATH           证书扫描路径 (默认: /etc/letsencrypt/live)
  --install                 安装证书管理工具 (certbot)
  -h, --help                显示此帮助信息

工作原理:
  1. 检查证书有效期
  2. 如果剩余天数 < 阈值，自动续签
  3. 续签后重载相关服务
  4. 验证续签结果

环境变量:
  RENEW_THRESHOLD_DAYS      续签阈值天数
  CERT_SCAN_PATH           证书扫描路径
  DOMAIN                   目标域名

示例:
  $0                                 # 智能检查所有证书并按需续签
  $0 --domain example.com            # 检查特定域名
  $0 --threshold 7                   # 使用7天阈值
  $0 --install                       # 安装 certbot

EOF
}

# --- 参数解析 ---
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -t|--threshold)
                RENEW_THRESHOLD_DAYS="$2"
                shift 2
                ;;
            -p|--path)
                CERT_SCAN_PATH="$2"
                shift 2
                ;;
            --install)
                install_certbot
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                warn "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# --- 检测证书管理工具 ---
detect_cert_tool() {
    step_start "检测证书管理工具"
    
    if command -v certbot &> /dev/null; then
        log "检测到 certbot，将使用 certbot 进行管理。"
        CERT_TOOL="certbot"
        RENEW_CMD="sudo certbot renew --force-renewal"
        INSTALL_CMD="sudo certbot certonly --standalone -d"
    elif [ -f "$HOME/.acme.sh/acme.sh" ]; then
        log "检测到 acme.sh，将使用 acme.sh 进行管理。"
        CERT_TOOL="acme.sh"
        RENEW_CMD="\"$HOME/.acme.sh/acme.sh\" --renew-all --force-renewal"
        INSTALL_CMD="\"$HOME/.acme.sh/acme.sh\" --issue --standalone -d"
    else
        warn "未检测到 certbot 或 acme.sh"
        return 1
    fi
    
    step_end "检测证书管理工具"
    return 0
}

# --- 安装 certbot ---
install_certbot() {
    step_start "安装 certbot"
    
    if command -v apt-get &> /dev/null; then
        log "检测到 Ubuntu/Debian 系统，使用 apt 安装"
        sudo apt-get update -qq
        sudo apt-get install -y certbot python3-certbot-nginx
    elif command -v yum &> /dev/null; then
        log "检测到 RHEL/CentOS 系统，使用 yum 安装"
        sudo yum install -y certbot python3-certbot-nginx
    elif command -v dnf &> /dev/null; then
        log "检测到 Fedora 系统，使用 dnf 安装"
        sudo dnf install -y certbot python3-certbot-nginx
    elif command -v pacman &> /dev/null; then
        log "检测到 Arch Linux 系统，使用 pacman 安装"
        sudo pacman -S --noconfirm certbot certbot-nginx
    elif command -v brew &> /dev/null; then
        log "检测到 macOS 系统，使用 homebrew 安装"
        brew install certbot
    else
        error "不支持的系统，请手动安装 certbot"
    fi
    
    success "certbot 安装完成"
    step_end "安装 certbot"
}

# --- 检测需要重载的服务 ---
detect_services() {
    step_start "检测需要重载的服务"
    
    RELOAD_CMDS=""

    # 检测 Docker 容器
    if command -v docker &> /dev/null; then
        log "检测 Docker 环境..."
        mapfile -t containers < <(docker ps --format "{{.ID}} {{.Names}}" | grep -iE 'nginx|proxy|apache|caddy' || true)
        for container in "${containers[@]}"; do
            if [ -n "$container" ]; then
                container_id=$(echo "$container" | cut -d' ' -f1)
                container_name=$(echo "$container" | cut -d' ' -f2-)
                log "检测到容器: $container_name (ID: $container_id)"
                RELOAD_CMDS+="docker exec $container_id nginx -s reload 2>/dev/null || docker restart $container_id;"
            fi
        done
    fi

    # 检测系统服务
    if command -v systemctl &> /dev/null; then
        log "检测 systemd 服务..."
        for service in nginx nginx-full openresty apache2 httpd apache caddy haproxy traefik gost; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                log "检测到运行中的 $service 服务"
                if [ "$service" = "gost" ]; then
                    RELOAD_CMDS+="sudo systemctl restart $service;"
                else
                    RELOAD_CMDS+="sudo systemctl reload $service;"
                fi
            fi
        done
    fi

    # 移除最后一个分号
    RELOAD_CMDS="${RELOAD_CMDS%;}"

    if [ -z "${RELOAD_CMDS}" ]; then
        warn "未检测到任何需要重载的服务"
        RELOAD_CMDS="echo '无需重载服务'"
    fi

    step_end "检测需要重载的服务"
}

# --- 获取证书剩余天数 ---
get_remaining_days_from_file() {
    local cert_file="$1"
    local expiry_date_str
    expiry_date_str=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
    if [[ -z "$expiry_date_str" ]]; then echo "0"; return; fi
    local expiry_epoch
    expiry_epoch=$(date --date="$expiry_date_str" +%s 2>/dev/null)
    local current_epoch
    current_epoch=$(date +%s)
    echo $(( (expiry_epoch - current_epoch) / 86400 ))
}

# --- 检查单个域名证书 ---
check_single_domain() {
    local domain="$1"
    local cert_file="$CERT_SCAN_PATH/$domain/fullchain.pem"
    
    if [ ! -f "$cert_file" ]; then
        error "域名 $domain 的证书文件不存在: $cert_file"
    fi
    
    local remaining_days
    remaining_days=$(get_remaining_days_from_file "$cert_file")
    
    if [[ "$remaining_days" -eq 0 ]]; then
        warn "无法读取证书 $domain 的有效期"
        return 1
    fi
    
    log "域名 $domain 剩余有效期: $remaining_days 天"
    
    if [[ "$remaining_days" -lt "$RENEW_THRESHOLD_DAYS" ]]; then
        warn "域名 $domain 需要续签 (剩余 $remaining_days 天 < 阈值 $RENEW_THRESHOLD_DAYS 天)"
        return 2
    else
        success "域名 $domain 证书有效期正常"
        return 0
    fi
}

# --- 扫描所有证书 ---
check_all_certificates() {
    step_start "证书扫描和有效期检查"
    
    log "启动全盘扫描模式 (路径: $CERT_SCAN_PATH)"
    if ! [ -d "$CERT_SCAN_PATH" ]; then 
        error "证书扫描路径 '$CERT_SCAN_PATH' 不存在或不是一个目录。"
    fi

    local min_remaining_days=9999
    local soonest_expiring_cert_file=""
    local soonest_expiring_domain=""
    local cert_count=0
    
    # 查找所有证书文件
    while IFS= read -r -d '' domain_dir; do
        local cert_file="$domain_dir/fullchain.pem"
        if [[ -f "$cert_file" ]]; then
            local domain_name=$(basename "$domain_dir")
            local current_days
            current_days=$(get_remaining_days_from_file "$cert_file")
            
            if [[ "$current_days" -eq 0 ]]; then
                warn "无法读取证书 '$domain_name' 的有效期，已跳过。"
                continue
            fi
            
            ((cert_count++))
            log "检测到域名: '$domain_name', 剩余 $current_days 天"
            
            if (( current_days < min_remaining_days )); then
                min_remaining_days=$current_days
                soonest_expiring_cert_file="$cert_file"
                soonest_expiring_domain="$domain_name"
            fi
        fi
    done < <(find "$CERT_SCAN_PATH" -type d -maxdepth 1 -mindepth 1 -print0 2>/dev/null)

    if [[ "$cert_count" -eq 0 ]]; then
        warn "在 '$CERT_SCAN_PATH' 中未找到任何有效的证书文件。"
        exit 0
    fi

    log "扫描完成。共找到 $cert_count 个证书。"
    log "最快过期的域名是 '$soonest_expiring_domain'，剩余 $min_remaining_days 天。"
    
    step_end "证书扫描和有效期检查"
    
    # 返回最小剩余天数
    echo "$min_remaining_days:$soonest_expiring_cert_file:$soonest_expiring_domain"
}

# --- 续签证书 ---
renew_certificates() {
    step_start "证书续签流程"
    
    if [ -z "${RENEW_CMD:-}" ]; then
        error "续签命令未设置，请先检测证书管理工具"
    fi
    
    log "正在执行续签命令: $RENEW_CMD"
    if ! eval "$RENEW_CMD"; then 
        error "证书续签失败！请检查续签命令和相关日志。"
    fi
    
    success "证书续签命令执行成功"
    
    step_end "证书续签流程"
}

# --- 重载服务 ---
reload_services() {
    step_start "重载相关服务"
    
    if [ -z "${RELOAD_CMDS:-}" ]; then
        warn "重载命令未设置，跳过服务重载"
        return 0
    fi
    
    log "正在执行重载命令..."
    if ! eval "$RELOAD_CMDS"; then 
        error "服务重载失败！请检查相关日志。"
    fi
    
    success "所有检测到的服务均已重载"
    
    step_end "重载相关服务"
}

# --- 申请单个域名证书 ---
install_single_certificate() {
    local domain="$1"
    
    step_start "为域名 $domain 申请证书"
    
    if [ -z "${INSTALL_CMD:-}" ]; then
        error "安装命令未设置，请先检测证书管理工具"
    fi
    
    log "正在为域名 $domain 申请证书..."
    if ! eval "$INSTALL_CMD $domain"; then
        error "为域名 $domain 申请证书失败！"
    fi
    
    success "为域名 $domain 申请证书成功"
    
    step_end "为域名 $domain 申请证书"
}

# --- 主函数 ---
main() {
    log "启动 SSL 证书管理工具 - CertGuard"
    log "智能模式: 检查证书并按需续签 (阈值: $RENEW_THRESHOLD_DAYS 天)"
    
    # 检测证书管理工具
    if ! detect_cert_tool; then
        error "请先安装证书管理工具: $0 --install"
    fi
    
    # 检测相关服务
    detect_services
    
    if [ -n "$DOMAIN" ]; then
        # 单域名处理
        log "处理单域名: $DOMAIN"
        
        if check_single_domain "$DOMAIN"; then
            success "域名 $DOMAIN 证书有效期正常。"
        else
            exit_code=$?
            if [ $exit_code -eq 2 ]; then
                # 需要续签
                warn "域名 $DOMAIN 证书即将过期，开始续签..."
                
                step_start "为域名 $DOMAIN 续签证书"
                if ! eval "$RENEW_CMD"; then 
                    error "域名 $DOMAIN 证书续签失败！"
                fi
                success "域名 $DOMAIN 证书续签成功"
                step_end "为域名 $DOMAIN 续签证书"
                
                # 重载服务
                reload_services
                
                # 验证续签结果
                log "等待 3 秒后验证续签结果..."
                sleep 3
                check_single_domain "$DOMAIN"
                success "域名 $DOMAIN SSL 证书管理完成。"
            else
                exit $exit_code
            fi
        fi
    else
        # 所有域名处理
        log "扫描所有域名证书..."
        
        result=$(check_all_certificates)
        min_days=$(echo "$result" | cut -d: -f1)
        cert_file=$(echo "$result" | cut -d: -f2)
        domain_name=$(echo "$result" | cut -d: -f3)
        
        if [[ "$min_days" -lt "$RENEW_THRESHOLD_DAYS" ]]; then
            warn "发现证书即将过期（最快过期: $domain_name, 剩余 $min_days 天）"
            warn "开始执行证书续签..."
            
            # 执行续签
            renew_certificates
            
            # 重载服务
            reload_services
            
            # 验证续签结果
            log "等待 3 秒后验证续签结果..."
            sleep 3
            
            # 重新检查最快过期的证书
            new_remaining_days=$(get_remaining_days_from_file "$cert_file")
            log "续签后 '$domain_name' 剩余有效期: $new_remaining_days 天"
            
            if [[ "$new_remaining_days" -gt "$min_days" ]]; then
                success "✅ 证书续签成功！证书有效期已延长。"
            else
                error "二次校验失败！续签后证书有效期未延长。请立即手动检查！"
            fi
        else
            success "✅ 所有证书有效期正常（最快过期: $domain_name, 剩余 $min_days 天）。"
        fi
    fi
}

# --- 脚本入口 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main
fi