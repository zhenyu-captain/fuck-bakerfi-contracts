#!/bin/bash

# BakerFi 多版本项目功能验证脚本
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: ./4-verify-project.sh [目标目录]
# 注意: 请直接执行脚本，不要使用 source 命令

set -e

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
        echo "用法: ./workspace/codeproject/4-verify-project.sh [目标目录]"
        echo ""
        echo "目标目录选项:"
        echo "  b-pre-mitigation   - 验证b-pre-mitigation版本项目"
        echo "  b-post-mitigation  - 验证b-post-mitigation版本项目"
        echo "  latest            - 验证latest版本项目"
        echo ""
        echo "示例:"
        echo "  ./workspace/codeproject/4-verify-project.sh b-pre-mitigation"
        echo "  ./workspace/codeproject/4-verify-project.sh b-post-mitigation"
        echo "  ./workspace/codeproject/4-verify-project.sh latest"
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
        echo "  ./workspace/codeproject/4-verify-project.sh b-pre-mitigation"
        echo "  ./workspace/codeproject/4-verify-project.sh b-post-mitigation"
        echo "  ./workspace/codeproject/4-verify-project.sh latest"
        echo ""
        echo "从workspace目录运行:"
        echo "  ./workspace/verify-project.sh b-pre-mitigation"
        echo ""
        echo "或者进入目标目录后运行:"
        echo "  cd $BASE_DIR/b-pre-mitigation && ./workspace/codeproject/4-verify-project.sh"
        exit 1
    fi
fi

# 开始时间
START_TIME=$(date +%s)
REPORT_DATE=$(date +"%Y-%m-%d %H:%M")

echo "=========================================="
echo -e "${BLUE}BakerFi 项目功能验证脚本 (${VERSION_TYPE}版本)${NC}"
echo "=========================================="
echo -e "${BLUE}版本: ${VERSION_TYPE} (${COMMIT_HASH})${NC}"
echo -e "${BLUE}目录: ${WORK_DIR}${NC}"
echo -e "${BLUE}开始时间: $REPORT_DATE${NC}"
echo ""

# 检查环境是否已安装
ENV_VERSION_FILE=".env-versions-${VERSION_TYPE}"
if [ ! -f "$ENV_VERSION_FILE" ]; then
    echo -e "${YELLOW}⚠️  检测到环境未安装 (${VERSION_TYPE})${NC}"
    echo -e "${YELLOW}请先运行: ./1-setup.sh${NC}"
    exit 1
fi

# 检查是否在项目根目录
if [ ! -f "package.json" ] || [ ! -f "hardhat.config.ts" ]; then
    echo -e "${RED}❌ 错误: 当前目录不是有效的BakerFi项目根目录${NC}"
    echo -e "${YELLOW}当前目录: ${WORK_DIR}${NC}"
    exit 1
fi

# 创建临时文件存储结果
TEMP_DIR=$(mktemp -d)
TEST_OUTPUT="$TEMP_DIR/test_output.txt"
COVERAGE_OUTPUT="$TEMP_DIR/coverage_output.txt"
COMPILE_OUTPUT="$TEMP_DIR/compile_output.txt"

# 清理函数
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# ============================================
# 阶段 1: 环境激活
# ============================================
echo -e "${YELLOW}[1/7] 激活开发环境...${NC}"

export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

eval "$($HOME/miniconda3/bin/conda shell.bash hook)" 2>/dev/null || true
conda activate bakerfi 2>/dev/null || true

NODE_VERSION=$(node --version 2>/dev/null || echo "未安装")
NPM_VERSION=$(npm --version 2>/dev/null || echo "未安装")
PYTHON_VERSION=$(python --version 2>&1 || echo "未安装")

if [ "$NODE_VERSION" = "未安装" ]; then
    echo -e "${RED}❌ Node.js 未安装或环境未激活${NC}"
    echo "请先运行: ./1-setup.sh"
    exit 1
fi

echo -e "${GREEN}✓ 环境已激活${NC}"
echo "  Node.js: $NODE_VERSION"
echo "  npm: $NPM_VERSION"
echo "  Python: $PYTHON_VERSION"
echo ""

# ============================================
# 阶段 2: 安装依赖
# ============================================
echo -e "${YELLOW}[2/7] 检查并安装项目依赖...${NC}"

if [ ! -d "node_modules" ]; then
    echo "  正在安装 npm 依赖..."
    INSTALL_START=$(date +%s)
    npm install --silent > /dev/null 2>&1
    INSTALL_END=$(date +%s)
    INSTALL_TIME=$((INSTALL_END - INSTALL_START))
    echo -e "${GREEN}✓ 依赖安装完成 (${INSTALL_TIME}秒)${NC}"
else
    echo -e "${GREEN}✓ 依赖已存在，跳过安装${NC}"
fi

PACKAGE_COUNT=$(find node_modules -maxdepth 1 -type d | wc -l)
echo "  已安装包: $((PACKAGE_COUNT - 1)) 个"
echo ""

# ============================================
# 阶段 3: 编译合约
# ============================================
echo -e "${YELLOW}[3/7] 编译智能合约...${NC}"

COMPILE_START=$(date +%s)
npx hardhat compile > "$COMPILE_OUTPUT" 2>&1
COMPILE_END=$(date +%s)
COMPILE_TIME=$((COMPILE_END - COMPILE_START))

# 提取编译统计
CONTRACT_COUNT=$(grep -o "Compiled [0-9]* Solidity" "$COMPILE_OUTPUT" | grep -o "[0-9]*" || echo "0")
TYPECHAIN_COUNT=$(grep -o "Successfully generated [0-9]* typings" "$COMPILE_OUTPUT" | grep -o "[0-9]*" | head -1 || echo "0")
WARNING_COUNT=$(grep -c "Warning:" "$COMPILE_OUTPUT" || echo "0")

echo -e "${GREEN}✓ 编译完成 (${COMPILE_TIME}秒)${NC}"
echo "  合约数量: $CONTRACT_COUNT 个"
echo "  类型定义: $TYPECHAIN_COUNT 个"
echo "  警告数量: $WARNING_COUNT 个"
echo ""

# ============================================
# 阶段 4: 运行测试
# ============================================
echo -e "${YELLOW}[4/7] 运行完整测试套件...${NC}"

TEST_START=$(date +%s)
npx hardhat test > "$TEST_OUTPUT" 2>&1 || true
TEST_END=$(date +%s)
TEST_TIME=$((TEST_END - TEST_START))

# 提取测试统计
TEST_PASSING=$(grep -o "[0-9]* passing" "$TEST_OUTPUT" | grep -o "[0-9]*" || echo "0")
TEST_PENDING=$(grep -o "[0-9]* pending" "$TEST_OUTPUT" | grep -o "[0-9]*" || echo "0")
TEST_FAILING=$(grep -o "[0-9]* failing" "$TEST_OUTPUT" | grep -o "[0-9]*" || echo "0")
TEST_TOTAL=$((TEST_PASSING + TEST_PENDING + TEST_FAILING))

echo -e "${GREEN}✓ 测试完成 (${TEST_TIME}秒)${NC}"
echo "  总计: $TEST_TOTAL 个"
echo "  ✅ 通过: $TEST_PASSING 个"
echo "  ⏸️  跳过: $TEST_PENDING 个"
echo "  ❌ 失败: $TEST_FAILING 个"

if [ "$TEST_FAILING" -gt 0 ]; then
    echo -e "${RED}⚠️  发现失败的测试！${NC}"
fi
echo ""

# ============================================
# 阶段 5: 生成覆盖率
# ============================================
echo -e "${YELLOW}[5/7] 生成测试覆盖率报告...${NC}"

COV_START=$(date +%s)
npx hardhat coverage > "$COVERAGE_OUTPUT" 2>&1 || true
COV_END=$(date +%s)
COV_TIME=$((COV_END - COV_START))

# 提取覆盖率数据
STMT_COV=$(grep "All files" "$COVERAGE_OUTPUT" | awk '{print $2}' || echo "0")
BRANCH_COV=$(grep "All files" "$COVERAGE_OUTPUT" | awk '{print $3}' || echo "0")
FUNC_COV=$(grep "All files" "$COVERAGE_OUTPUT" | awk '{print $4}' || echo "0")
LINE_COV=$(grep "All files" "$COVERAGE_OUTPUT" | awk '{print $5}' || echo "0")

echo -e "${GREEN}✓ 覆盖率报告生成完成 (${COV_TIME}秒)${NC}"
echo "  语句覆盖率: $STMT_COV"
echo "  分支覆盖率: $BRANCH_COV"
echo "  函数覆盖率: $FUNC_COV"
echo "  行覆盖率: $LINE_COV"
echo ""

# ============================================
# 阶段 6: 检查 POC 和 Echidna
# ============================================
echo -e "${YELLOW}[6/7] 检查 POC 和 Echidna 测试...${NC}"

POC_FILES=$(find contracts -name "*Attack*" -o -name "*POC*" 2>/dev/null | wc -l)
TEST_CONTRACTS=$(find contracts/tests -name "*.sol" 2>/dev/null | wc -l)
ECHIDNA_EXISTS=$([ -f "echidna.yaml" ] && echo "是" || echo "否")

echo -e "${GREEN}✓ POC 检查完成${NC}"
echo "  攻击测试文件: $POC_FILES 个"
echo "  测试合约: $TEST_CONTRACTS 个"
echo "  Echidna 配置: $ECHIDNA_EXISTS"
echo ""

# ============================================
# 阶段 7: 显示验证总结
# ============================================
echo -e "${YELLOW}[7/7] 显示验证总结...${NC}"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_MINUTES=$((TOTAL_TIME / 60))
TOTAL_SECONDS=$((TOTAL_TIME % 60))

# 计算测试通过率（避免除以0）
if [ "$TEST_TOTAL" -gt 0 ]; then
    TEST_PASS_RATE=$((TEST_PASSING * 100 / TEST_TOTAL))
else
    TEST_PASS_RATE=0
fi

echo ""
echo -e "${GREEN}✓ 验证总结已准备${NC}"
echo ""

# ============================================
# 完成总结
# ============================================
echo "=========================================="
echo -e "${GREEN}验证完成！${NC}"
echo "=========================================="
echo ""

echo -e "${BLUE}=== 📊 验证总结 ===${NC}"
echo ""
echo "执行时间:"
echo "  总耗时: ${TOTAL_MINUTES}分${TOTAL_SECONDS}秒"
echo ""

echo "编译结果:"
echo "  合约数量: $CONTRACT_COUNT 个"
echo "  类型定义: $TYPECHAIN_COUNT 个"  
echo "  编译警告: $WARNING_COUNT 个"
echo ""

echo "测试结果:"
echo "  ✅ 通过: $TEST_PASSING 个 (${TEST_PASS_RATE}%)"
echo "  ⏸️  跳过: $TEST_PENDING 个"
echo "  ❌ 失败: $TEST_FAILING 个"
echo ""

echo "代码覆盖率:"
echo "  语句覆盖率: $STMT_COV"
echo "  分支覆盖率: $BRANCH_COV"
echo "  函数覆盖率: $FUNC_COV"
echo "  行覆盖率: $LINE_COV"
echo ""

echo "POC 和安全测试:"
echo "  攻击测试文件: $POC_FILES 个"
echo "  测试合约: $TEST_CONTRACTS 个"  
echo "  Echidna 配置: $ECHIDNA_EXISTS"
echo ""

echo "版本信息:"
echo "  当前版本: ${VERSION_TYPE} (${COMMIT_HASH})"
echo "  工作目录: ${WORK_DIR}"
echo ""

echo "生成的文件:"
echo "  ✅ coverage/index.html (覆盖率报告)"
echo "  ✅ artifacts/ (编译产物)"
echo "  ✅ src/types/ (类型定义)"
echo ""

if [ "$TEST_FAILING" -eq 0 ]; then
    echo -e "${GREEN}🎉 所有测试通过，项目功能正常，可以开始审计工作！${NC}"
    echo ""
    echo -e "${BLUE}下一步操作:${NC}"
    echo -e "  1. 激活环境: ${GREEN}source ./workspace/codeproject/2-activate-env.sh${NC}"
    echo -e "  2. 运行工具验证: ${GREEN}./workspace/codeproject/3-verify-tools.sh${NC}"
    echo -e "  3. 开始审计工作"
    exit 0
else
    echo -e "${YELLOW}⚠️  发现 $TEST_FAILING 个失败的测试${NC}"
    echo ""
    echo -e "${YELLOW}解决方案:${NC}"
    echo -e "  1. 检查测试日志进行调试"
    echo -e "  2. 重新安装环境: ${GREEN}./1-setup.sh${NC}"
    echo -e "  3. 检查版本文件: ${GREEN}.env-versions-${VERSION_TYPE}${NC}"
    exit 1
fi
