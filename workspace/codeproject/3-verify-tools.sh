#!/bin/bash

# BakerFi 多版本工具验证脚本
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: ./3-verify-tools.sh [目标目录]
# 注意: 请直接执行脚本，不要使用 source 命令

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
        echo "用法: ./workspace/codeproject/3-verify-tools.sh [目标目录]"
        echo ""
        echo "目标目录选项:"
        echo "  b-pre-mitigation   - 验证b-pre-mitigation版本工具"
        echo "  b-post-mitigation  - 验证b-post-mitigation版本工具"
        echo "  latest            - 验证latest版本工具"
        echo ""
        echo "示例:"
        echo "  ./workspace/codeproject/3-verify-tools.sh b-pre-mitigation"
        echo "  ./workspace/codeproject/3-verify-tools.sh b-post-mitigation"
        echo "  ./workspace/codeproject/3-verify-tools.sh latest"
        echo ""
        echo "如果不指定目标目录，将自动检测当前目录的版本"
        exit 0
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
    else
        echo -e "${RED}❌ 错误: 目录 $BASE_DIR/$TARGET_DIR 不存在${NC}"
        echo ""
        echo "可用的目录:"
        for dir in b-pre-mitigation b-post-mitigation latest; do
            if [ -d "$BASE_DIR/$dir" ]; then
                echo "  - $dir"
            fi
        done
        exit 1
    fi
else
    # 自动检测当前目录
    WORK_DIR="$PWD"
    VERSION_INFO=$(detect_version "$WORK_DIR")
    VERSION_TYPE=$(echo "$VERSION_INFO" | cut -d'|' -f1)
    COMMIT_HASH=$(echo "$VERSION_INFO" | cut -d'|' -f2)
    
    if [[ "$WORK_DIR" == *"/workspace"* ]]; then
        echo -e "${RED}❌ 错误: 请在BakerFi合约版本目录中运行此脚本，或使用参数指定目录${NC}"
        echo ""
        echo "使用方法:"
        echo "  ./workspace/codeproject/3-verify-tools.sh b-pre-mitigation"
        echo "  ./workspace/codeproject/3-verify-tools.sh b-post-mitigation"
        echo "  ./workspace/codeproject/3-verify-tools.sh latest"
        echo ""
        echo "或者进入目标目录后运行:"
        echo "  cd $BASE_DIR/b-pre-mitigation && ./workspace/codeproject/3-verify-tools.sh"
        exit 1
    fi
fi

echo "=========================================="
echo -e "${BLUE}BakerFi 工具验证 (${VERSION_TYPE}版本)${NC}"
echo "=========================================="
echo -e "${BLUE}版本: ${VERSION_TYPE} (${COMMIT_HASH})${NC}"
echo -e "${BLUE}目录: ${WORK_DIR}${NC}"
echo ""

# 切换到目标目录
if [ "$PWD" != "$WORK_DIR" ]; then
    echo -e "${YELLOW}切换到目标目录: ${WORK_DIR}${NC}"
    cd "$WORK_DIR"
fi

# 检查环境是否已安装
ENV_VERSION_FILE=".env-versions-${VERSION_TYPE}"
if [ ! -f "$ENV_VERSION_FILE" ]; then
    echo -e "${YELLOW}⚠️  检测到环境未安装 (${VERSION_TYPE})${NC}"
    echo -e "${YELLOW}请先运行: ./1-setup.sh${NC}"
    exit 1
fi

# 确保 PATH 包含所有必要目录
export PATH="$HOME/.local/bin:$PATH"

# 激活 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null

# 激活 conda 环境
eval "$($HOME/miniconda3/bin/conda shell.bash hook)" 2>/dev/null || true
conda activate bakerfi 2>/dev/null || {
    echo -e "${RED}❌ 错误: 无法激活conda环境 'bakerfi'${NC}"
    echo -e "${YELLOW}请先运行: ./1-setup.sh${NC}"
    exit 1
}

PASS=0
FAIL=0

check_tool() {
    local name=$1
    local cmd=$2
    
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        ((FAIL++))
        return 1
    fi
}

echo "=== 核心工具 ==="
check_tool "Node.js $(node --version 2>/dev/null)" "node --version"
check_tool "npm $(npm --version 2>/dev/null)" "npm --version"
check_tool "Python $(python --version 2>&1 | cut -d' ' -f2)" "python --version"
echo ""

echo "=== 审计工具 ==="

# Slither - 使用 pip show 获取版本（更可靠）
SLITHER_VER=$(pip show slither-analyzer 2>/dev/null | grep "^Version:" | cut -d' ' -f2 || echo "未知")
check_tool "Slither $SLITHER_VER" "pip show slither-analyzer"

# Echidna
ECHIDNA_VER=$(echidna --version 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "未知")
check_tool "Echidna $ECHIDNA_VER" "echidna --version"

# Mythril
MYTH_VER=$(pip show mythril 2>/dev/null | grep "^Version:" | cut -d' ' -f2 || echo "未知")
check_tool "Mythril v$MYTH_VER" "pip show mythril"

# Surya
check_tool "Surya" "surya --version"

# solc
SOLC_VER=$(solc --version 2>&1 | grep -oP 'Version: \d+\.\d+\.\d+' | head -n 1 || echo "未知")
check_tool "solc $SOLC_VER" "solc --version"
echo ""

echo "=== Hardhat 检查 ==="
check_tool "Hardhat" "npx hardhat --version"
echo ""

echo "=========================================="
echo -e "结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC}"
echo "=========================================="
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 所有工具都已正确安装！${NC}"
    echo ""
    echo -e "${BLUE}版本信息:${NC}"
    echo "  当前版本: ${VERSION_TYPE} (${COMMIT_HASH})"
    echo "  工作目录: ${WORK_DIR}"
    echo ""
    echo "可以开始工作了："
    echo -e "  ${GREEN}npx hardhat compile${NC}        # 编译合约"
    echo -e "  ${GREEN}npx hardhat test${NC}           # 运行测试"
    echo -e "  ${GREEN}npx hardhat coverage${NC}      # 生成覆盖率"
    echo -e "  ${GREEN}slither .${NC}                 # 运行Slither分析"
    echo -e "  ${GREEN}echidna-test .${NC}           # 运行Echidna测试"
    echo ""
    exit 0
else
    echo -e "${RED}❌ 有 $FAIL 个工具未能正常工作${NC}"
    echo ""
    echo -e "${BLUE}版本信息:${NC}"
    echo "  当前版本: ${VERSION_TYPE} (${COMMIT_HASH})"
    echo "  工作目录: ${WORK_DIR}"
    echo ""
    echo -e "${YELLOW}解决方案:${NC}"
    echo -e "  1. 重新安装环境: ${GREEN}./1-setup.sh${NC}"
    echo -e "  2. 检查版本文件: ${GREEN}.env-versions-${VERSION_TYPE}${NC}"
    echo -e "  3. 手动激活环境: ${GREEN}source ./workspace/codeproject/2-activate-env.sh${NC}"
    echo ""
    exit 1
fi

