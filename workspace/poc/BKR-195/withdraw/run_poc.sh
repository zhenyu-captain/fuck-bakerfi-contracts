#!/bin/bash

# =============================================================================
# BKR-195 _withdraw 函数漏洞POC运行脚本
# 用于快速运行不同版本的POC测试
# 
# 作者: AI Assistant
# 版本: 1.0
# 日期: 2025年
# =============================================================================

set -e  # 遇到错误立即退出

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_FILE="bkr195_withdraw_poc.js"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 显示使用说明
show_usage() {
    echo -e "${PURPLE}"
    echo "=============================================================================="
    echo "                BKR-195 _withdraw 函数漏洞POC运行脚本"
    echo "=============================================================================="
    echo -e "${NC}"
    echo "📋 使用方法:"
    echo "   $0 [版本] [选项]"
    echo ""
    echo "🎯 支持的版本:"
    echo "   b-pre-mitigation    - 第二轮审计前版本（包含漏洞）"
    echo "   b-post-mitigation   - 第二轮审计后版本（已修复）"
    echo "   latest              - 最新版本"
    echo "   all                 - 运行所有版本测试"
    echo ""
    echo "🔧 选项:"
    echo "   --help, -h          - 显示此帮助信息"
    echo "   --install           - 安装依赖"
    echo "   --clean             - 清理依赖"
    echo ""
    echo "📝 示例:"
    echo "   $0 b-pre-mitigation"
    echo "   $0 b-post-mitigation"
    echo "   $0 latest"
    echo "   $0 all"
    echo "   $0 --install"
    echo ""
}

# 检查依赖
check_dependencies() {
    log_step "检查依赖..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装! 请先安装 Node.js"
        echo "  Ubuntu/Debian: sudo apt-get install nodejs npm"
        echo "  CentOS/RHEL: sudo yum install nodejs npm"
        echo "  macOS: brew install node"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "NPM 未安装! 请先安装 NPM"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 安装依赖
install_dependencies() {
    log_step "安装依赖..."
    
    if [ ! -f "$SCRIPT_DIR/package.json" ]; then
        log_error "package.json 不存在!"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
    npm install
    log_success "依赖安装完成"
}

# 清理依赖
clean_dependencies() {
    log_step "清理依赖..."
    
    cd "$SCRIPT_DIR"
    if [ -d "node_modules" ]; then
        rm -rf node_modules
        log_success "node_modules 已删除"
    fi
    
    if [ -f "package-lock.json" ]; then
        rm package-lock.json
        log_success "package-lock.json 已删除"
    fi
}

# 检查版本目录
check_version_directory() {
    local version=$1
    local version_path=""
    
    case $version in
        "b-pre-mitigation")
            version_path="../../b-pre-mitigation"
            ;;
        "b-post-mitigation")
            version_path="../../b-post-mitigation"
            ;;
        "latest")
            version_path="../../latest"
            ;;
        *)
            log_error "不支持的版本: $version"
            return 1
            ;;
    esac
    
    local full_path="$(cd "$SCRIPT_DIR" && cd "$version_path" && pwd)"
    
    if [ ! -d "$full_path" ]; then
        log_error "版本目录不存在: $full_path"
        log_warning "请先运行 down_versions.sh 脚本拉取版本"
        return 1
    fi
    
    log_success "版本目录检查通过: $full_path"
    return 0
}

# 运行POC
run_poc() {
    local version=$1
    
    log_header "运行 BKR-195 _withdraw 函数漏洞POC"
    log_info "目标版本: $version"
    log_info "POC文件: $POC_FILE"
    echo ""
    
    # 检查POC文件
    if [ ! -f "$SCRIPT_DIR/$POC_FILE" ]; then
        log_error "POC文件不存在: $POC_FILE"
        exit 1
    fi
    
    # 检查版本目录
    if ! check_version_directory "$version"; then
        exit 1
    fi
    
    # 运行POC
    cd "$SCRIPT_DIR"
    log_step "执行POC..."
    echo ""
    
    node "$POC_FILE" --version "$version"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "POC执行成功"
    else
        log_error "POC执行失败 (退出码: $exit_code)"
    fi
    
    return $exit_code
}

# 运行所有版本
run_all_versions() {
    log_header "运行所有版本测试"
    
    local versions=("b-pre-mitigation" "b-post-mitigation" "latest")
    local success_count=0
    local total_count=${#versions[@]}
    
    for version in "${versions[@]}"; do
        log_step "测试版本: $version"
        echo ""
        
        if run_poc "$version"; then
            ((success_count++))
        fi
        
        echo ""
        log_info "----------------------------------------"
        echo ""
    done
    
    log_header "测试结果总结"
    log_info "成功: $success_count/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        log_success "所有版本测试完成"
        return 0
    else
        log_warning "部分版本测试失败"
        return 1
    fi
}

# 主函数
main() {
    local version=""
    local install_deps=false
    local clean_deps=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --install)
                install_deps=true
                shift
                ;;
            --clean)
                clean_deps=true
                shift
                ;;
            b-pre-mitigation|b-post-mitigation|latest|all)
                version="$1"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定版本，显示帮助
    if [ -z "$version" ] && [ "$install_deps" = false ] && [ "$clean_deps" = false ]; then
        show_usage
        exit 0
    fi
    
    # 执行操作
    if [ "$install_deps" = true ]; then
        check_dependencies
        install_dependencies
        exit 0
    fi
    
    if [ "$clean_deps" = true ]; then
        clean_dependencies
        exit 0
    fi
    
    # 检查依赖
    check_dependencies
    
    # 运行POC
    if [ "$version" = "all" ]; then
        run_all_versions
    else
        run_poc "$version"
    fi
}

# 直接执行主函数
main "$@"
