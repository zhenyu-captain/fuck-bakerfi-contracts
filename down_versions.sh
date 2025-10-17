#!/bin/bash

# =============================================================================
# BakerFi合约版本拉取脚本
# 用于拉取b-pre-mitigation、b-post-mitigation和latest版本到本地
# 
# 作者: AI Assistant
# 版本: 1.0
# 日期: 2025年
# =============================================================================

set -e  # 遇到错误立即退出

# 配置变量
REPO_URL="https://github.com/baker-fi/bakerfi-contracts.git"
BASE_DIR="/home/mi/fuck-bakerfi-contracts"
B_PRE_COMMIT="81485a9"
B_POST_COMMIT="f99edb1"

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

# 显示脚本信息
show_script_info() {
    echo -e "${PURPLE}"
    echo "=============================================================================="
    echo "                    BakerFi合约版本拉取脚本"
    echo "=============================================================================="
    echo -e "${NC}"
    echo "📋 脚本功能:"
    echo "   • 拉取 b-pre-mitigation 版本 (commit: $B_PRE_COMMIT)"
    echo "   • 拉取 b-post-mitigation 版本 (commit: $B_POST_COMMIT)"
    echo "   • 拉取 latest 版本 (最新提交)"
    echo "   • 版本验证和目录结构显示"
    echo ""
    echo "📁 目标目录: $BASE_DIR"
    echo "🔗 仓库地址: $REPO_URL"
    echo ""
}

# 检查目录是否存在
check_directory() {
    log_step "检查基础目录..."
    if [ ! -d "$BASE_DIR" ]; then
        log_error "基础目录 $BASE_DIR 不存在!"
        log_info "请确保目录存在或修改脚本中的 BASE_DIR 变量"
        exit 1
    fi
    log_success "基础目录检查通过"
}

# 检查Git是否安装
check_git() {
    log_step "检查Git安装..."
    if ! command -v git &> /dev/null; then
        log_error "Git未安装! 请先安装Git:"
        echo "  Ubuntu/Debian: sudo apt-get install git"
        echo "  CentOS/RHEL: sudo yum install git"
        echo "  macOS: brew install git"
        exit 1
    fi
    log_success "Git检查通过"
}

# 检查网络连接
check_network() {
    log_step "检查网络连接..."
    if ! ping -c 1 github.com &> /dev/null; then
        log_warning "无法连接到GitHub，但继续尝试..."
    else
        log_success "网络连接正常"
    fi
}


# 验证版本
verify_versions() {
    log_header "验证版本信息"
    
    # 验证 b-pre-mitigation
    if [ -d "$BASE_DIR/b-pre-mitigation" ]; then
        log_step "验证 b-pre-mitigation..."
        cd "$BASE_DIR/b-pre-mitigation"
        local current_commit=$(git rev-parse --short HEAD)
        if [ "$current_commit" = "$B_PRE_COMMIT" ]; then
            log_success "b-pre-mitigation 版本验证成功 ($current_commit)"
        else
            log_error "b-pre-mitigation 版本不匹配"
            log_info "期望: $B_PRE_COMMIT"
            log_info "实际: $current_commit"
        fi
        cd "$BASE_DIR"
    else
        log_warning "b-pre-mitigation 目录不存在"
    fi
    
    # 验证 b-post-mitigation
    if [ -d "$BASE_DIR/b-post-mitigation" ]; then
        log_step "验证 b-post-mitigation..."
        cd "$BASE_DIR/b-post-mitigation"
        local current_commit=$(git rev-parse --short HEAD)
        if [ "$current_commit" = "$B_POST_COMMIT" ]; then
            log_success "b-post-mitigation 版本验证成功 ($current_commit)"
        else
            log_error "b-post-mitigation 版本不匹配"
            log_info "期望: $B_POST_COMMIT"
            log_info "实际: $current_commit"
        fi
        cd "$BASE_DIR"
    else
        log_warning "b-post-mitigation 目录不存在"
    fi
    
    # 验证 latest
    if [ -d "$BASE_DIR/latest" ]; then
        log_step "验证 latest..."
        cd "$BASE_DIR/latest"
        local current_commit=$(git rev-parse --short HEAD)
        log_success "latest 版本验证成功 ($current_commit)"
        cd "$BASE_DIR"
    else
        log_warning "latest 目录不存在"
    fi
    
    echo ""
}

# 显示目录结构
show_structure() {
    log_header "目录结构"
    
    echo "📁 完整目录结构:"
    echo "├── b-pre-mitigation/     (commit: $B_PRE_COMMIT)"
    echo "├── b-post-mitigation/    (commit: $B_POST_COMMIT)"
    echo "└── latest/               (最新版本)"
    echo ""
    
    if [ -d "$BASE_DIR" ]; then
        echo "📋 实际目录列表:"
        ls -la "$BASE_DIR" | grep "^d.*b-pre-mitigation\|b-post-mitigation\|latest" || echo "   (暂无相关目录)"
        echo ""
        
        # 显示各版本的大小
        echo "📊 目录大小:"
        for dir in b-pre-mitigation b-post-mitigation latest; do
            if [ -d "$BASE_DIR/$dir" ]; then
                local size=$(du -sh "$BASE_DIR/$dir" | cut -f1)
                echo "   $dir/: $size"
            fi
        done
        echo ""
    fi
}

# 显示使用说明
show_usage() {
    log_header "使用说明"
    
    echo "🎯 进入特定版本目录:"
    echo "   cd $BASE_DIR/b-pre-mitigation"
    echo "   cd $BASE_DIR/b-post-mitigation"
    echo "   cd $BASE_DIR/latest"
    echo ""
    
    echo "🔍 查看版本信息:"
    echo "   cd $BASE_DIR/b-pre-mitigation && git log --oneline -1"
    echo "   cd $BASE_DIR/b-post-mitigation && git log --oneline -1"
    echo "   cd $BASE_DIR/latest && git log --oneline -1"
    echo ""
    
    echo "📝 版本对比:"
    echo "   diff -r $BASE_DIR/b-pre-mitigation $BASE_DIR/b-post-mitigation"
    echo ""
    
    echo "🛠️  常用命令:"
    echo "   # 查看合约文件"
    echo "   ls $BASE_DIR/b-pre-mitigation/contracts/"
    echo ""
    echo "   # 查看测试文件"
    echo "   ls $BASE_DIR/b-pre-mitigation/test/"
    echo ""
}

# 自动拉取所有版本
auto_setup() {
    log_header "自动拉取所有版本"
    log_info "将自动拉取所有版本，无需交互确认"
    echo ""
    
    # 拉取 b-pre-mitigation
    log_step "拉取 b-pre-mitigation..."
    git clone "$REPO_URL" "$BASE_DIR/b-pre-mitigation"
    cd "$BASE_DIR/b-pre-mitigation"
    git checkout "$B_PRE_COMMIT"
    log_success "b-pre-mitigation 拉取完成"
    cd "$BASE_DIR"
    
    # 拉取 b-post-mitigation
    log_step "拉取 b-post-mitigation..."
    git clone "$REPO_URL" "$BASE_DIR/b-post-mitigation"
    cd "$BASE_DIR/b-post-mitigation"
    git checkout "$B_POST_COMMIT"
    log_success "b-post-mitigation 拉取完成"
    cd "$BASE_DIR"
    
    # 拉取 latest
    log_step "拉取 latest..."
    git clone "$REPO_URL" "$BASE_DIR/latest"
    log_success "latest 拉取完成"
    
    echo ""
}


# 主函数
main() {
    show_script_info
    
    # 预检查
    check_directory
    check_git
    check_network
    echo ""
    
    # 自动拉取所有版本
    auto_setup
    
    # 验证版本
    verify_versions
    
    # 显示结果
    show_structure
    show_usage
    
    log_success "🎉 所有版本拉取完成!"
    echo ""
    log_info "📚 脚本执行完毕，自动退出"
}


# 直接执行主函数，无需参数
main
