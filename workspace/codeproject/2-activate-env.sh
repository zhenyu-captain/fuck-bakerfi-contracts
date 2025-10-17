#!/bin/bash

# BakerFi 多版本环境激活脚本
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: source ./2-activate-env.sh [目标目录]

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录
# 使用固定的脚本路径，避免 source 命令时的路径问题
SCRIPT_DIR="/home/mi/fuck-bakerfi-contracts/workspace/codeproject"
BASE_DIR="/home/mi/fuck-bakerfi-contracts"

# 支持命令行参数指定目标目录
TARGET_DIR=""
if [ $# -gt 0 ]; then
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法: source ./workspace/codeproject/2-activate-env.sh [目标目录]"
        echo ""
        echo "目标目录选项:"
        echo "  b-pre-mitigation   - 激活b-pre-mitigation版本环境"
        echo "  b-post-mitigation  - 激活b-post-mitigation版本环境"
        echo "  latest            - 激活latest版本环境"
        echo ""
        echo "示例:"
        echo "  source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation"
        echo "  source ./workspace/codeproject/2-activate-env.sh b-post-mitigation"
        echo "  source ./workspace/codeproject/2-activate-env.sh latest"
        echo ""
        echo "如果不指定目标目录，将自动检测当前目录的版本"
        return 0 2>/dev/null || exit 0
    else
        TARGET_DIR="$1"
    fi
fi

# 检测版本类型
detect_version() {
    local dir_path="$1"
    local version_type="unknown"
    local commit_hash="unknown"
    
    if [[ "$dir_path" == *"/b-pre-mitigation"* ]]; then
        version_type="b-pre-mitigation"
        commit_hash="81485a9"
    elif [[ "$dir_path" == *"/b-post-mitigation"* ]]; then
        version_type="b-post-mitigation"
        commit_hash="f99edb1"
    elif [[ "$dir_path" == *"/latest"* ]]; then
        version_type="latest"
        commit_hash="HEAD"
    elif [ -f "$dir_path/package.json" ]; then
        # 尝试从git信息检测版本
        cd "$dir_path"
        if git rev-parse --short HEAD >/dev/null 2>&1; then
            current_commit=$(git rev-parse --short HEAD)
            if [ "$current_commit" = "81485a9" ]; then
                version_type="b-pre-mitigation"
                commit_hash="81485a9"
            elif [ "$current_commit" = "f99edb1" ]; then
                version_type="b-post-mitigation"
                commit_hash="f99edb1"
            else
                version_type="latest"
                commit_hash="$current_commit"
            fi
        fi
        cd - > /dev/null
    fi
    
    echo "$version_type|$commit_hash"
}

# 确定目标目录和版本信息
if [ -n "$TARGET_DIR" ]; then
    # 使用命令行指定的目录
    if [ -d "$BASE_DIR/$TARGET_DIR" ]; then
        WORK_DIR="$BASE_DIR/$TARGET_DIR"
        VERSION_INFO=$(detect_version "$WORK_DIR")
        VERSION_TYPE=$(echo "$VERSION_INFO" | cut -d'|' -f1)
        COMMIT_HASH=$(echo "$VERSION_INFO" | cut -d'|' -f2)
        
        # 切换到目标目录
        cd "$WORK_DIR"
    else
        echo -e "${RED}❌ 错误: 目录 $BASE_DIR/$TARGET_DIR 不存在${NC}"
        echo ""
        echo "可用的目录:"
        for dir in b-pre-mitigation b-post-mitigation latest; do
            if [ -d "$BASE_DIR/$dir" ]; then
                echo "  - $dir"
            fi
        done
        return 1 2>/dev/null || exit 1
    fi
else
    # 自动检测当前目录
    WORK_DIR="$PWD"
    VERSION_INFO=$(detect_version "$WORK_DIR")
    VERSION_TYPE=$(echo "$VERSION_INFO" | cut -d'|' -f1)
    COMMIT_HASH=$(echo "$VERSION_INFO" | cut -d'|' -f2)
    
    if [[ "$WORK_DIR" == *"/workspace"* ]] || [ "$VERSION_TYPE" = "unknown" ]; then
        echo -e "${RED}❌ 错误: 无法检测到BakerFi版本，请使用参数指定目录${NC}"
        echo ""
        echo "使用方法:"
        echo "  source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation"
        echo "  source ./workspace/codeproject/2-activate-env.sh b-post-mitigation"
        echo "  source ./workspace/codeproject/2-activate-env.sh latest"
        echo ""
        echo "或者进入目标目录后运行:"
        echo "  cd $BASE_DIR/b-pre-mitigation && source ./workspace/codeproject/2-activate-env.sh"
        return 1 2>/dev/null || exit 1
    fi
fi

# 检查环境是否已安装
ENV_VERSION_FILE=".env-versions-${VERSION_TYPE}"
if [ ! -f "$ENV_VERSION_FILE" ]; then
    echo -e "${YELLOW}⚠️  检测到环境未安装 (${VERSION_TYPE})${NC}"
    echo -e "${YELLOW}请先运行: ./1-setup.sh${NC}"
    return 1 2>/dev/null || exit 1
fi

# 添加本地 bin 到 PATH
export PATH="$HOME/.local/bin:$PATH"

# 激活 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 激活 conda 环境
eval "$($HOME/miniconda3/bin/conda shell.bash hook)" 2>/dev/null || true
conda activate bakerfi 2>/dev/null || {
    echo -e "${RED}❌ 错误: 无法激活conda环境 'bakerfi'${NC}"
    echo -e "${YELLOW}请先运行: ./1-setup.sh${NC}"
    return 1 2>/dev/null || exit 1
}

# 设置版本信息
export BAKERFI_VERSION_TYPE="${VERSION_TYPE}"
export BAKERFI_COMMIT_HASH="${COMMIT_HASH}"
export BAKERFI_WORK_DIR="${WORK_DIR}"

echo -e "${GREEN}✓ BakerFi 开发环境已激活 (${VERSION_TYPE}版本)${NC}"
echo -e "${BLUE}  版本: ${VERSION_TYPE} (${COMMIT_HASH})${NC}"
echo -e "${BLUE}  目录: ${WORK_DIR}${NC}"
echo -e "${BLUE}  Node.js: $(node --version 2>/dev/null || echo '未安装')${NC}"
echo -e "${BLUE}  Python: $(python --version 2>&1 || echo '未安装')${NC}"
echo ""

# 显示可用的命令
echo -e "${YELLOW}可用的命令:${NC}"
echo "  npx hardhat compile     # 编译合约"
echo "  npx hardhat test        # 运行测试"
echo "  npx hardhat coverage    # 生成覆盖率"
echo "  slither .               # 运行Slither分析"
echo "  echidna-test .          # 运行Echidna测试"
echo ""
