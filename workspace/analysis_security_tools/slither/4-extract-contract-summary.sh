#!/bin/bash
# BakerFi 多版本合约摘要提取工具
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: ./extract-contract-summary.sh [目标目录]

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"  # 回到 fuck-bakerfi-contracts 目录

# 支持命令行参数指定目标目录
TARGET_DIR=""
if [ $# -gt 0 ]; then
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [目标目录]"
        echo ""
        echo "目标目录选项:"
        echo "  b-pre-mitigation   - 提取b-pre-mitigation版本合约摘要"
        echo "  b-post-mitigation  - 提取b-post-mitigation版本合约摘要"
        echo "  latest            - 提取latest版本合约摘要"
        echo ""
        echo "示例:"
        echo "  $0 b-pre-mitigation"
        echo "  $0 b-post-mitigation"
        echo "  $0 latest"
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
    
    if [[ "$WORK_DIR" == *"/workspace"* ]] || [ "$VERSION_TYPE" = "unknown" ]; then
        echo -e "${RED}❌ 错误: 无法检测到BakerFi版本，请使用参数指定目录${NC}"
        echo ""
        echo "使用方法:"
        echo "  $0 b-pre-mitigation"
        echo "  $0 b-post-mitigation"
        echo "  $0 latest"
        echo ""
        echo "或者进入目标目录后运行:"
        echo "  cd $BASE_DIR/b-pre-mitigation && $0"
        exit 1
    fi
fi

echo -e "${BLUE}=== BakerFi 合约摘要提取工具 (${VERSION_TYPE}版本) ===${NC}"
echo -e "${BLUE}版本: ${VERSION_TYPE} (${COMMIT_HASH})${NC}"
echo -e "${BLUE}目录: ${WORK_DIR}${NC}"
echo ""

# 检查是否在项目根目录
if [ ! -f "package.json" ] || [ ! -d "artifacts" ]; then
    echo -e "${RED}❌ 错误: 当前目录不是有效的BakerFi项目根目录${NC}"
    echo -e "${YELLOW}当前目录: ${WORK_DIR}${NC}"
    echo -e "${YELLOW}请确保项目已编译，artifacts 目录存在${NC}"
    exit 1
fi

# 设置输出目录（包含版本信息）
OUTPUT_DIR="$BASE_DIR/workspace/analysis_security_return/slither/contract-summary-${VERSION_TYPE}"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "📁 输出目录: $OUTPUT_DIR"
echo ""

# 检查 slither 是否安装
if ! command -v slither &> /dev/null; then
    echo -e "${RED}✗ Slither 未安装${NC}"
    echo "请安装: pip install slither-analyzer"
    exit 1
fi

echo -e "${GREEN}✓ Slither 已安装: $(slither --version)${NC}"
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/contract-summary-${TIMESTAMP}.txt"

echo -e "${YELLOW}📋 生成合约摘要...${NC}"
echo ""

# 运行 contract-summary printer
slither . \
  --filter-paths "node_modules/,test/,mocks/" \
  --exclude-dependencies \
  --print contract-summary \
  > "$OUTPUT_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 摘要生成成功${NC}"
else
    echo -e "${YELLOW}⚠ 生成完成（可能有警告）${NC}"
fi

echo ""
echo -e "${GREEN}=== 完成! ===${NC}"
echo "结果文件: $(basename $OUTPUT_FILE)"
echo "完整路径: $OUTPUT_FILE"
echo ""

# 统计信息
if [ -f "$OUTPUT_FILE" ]; then
    echo "统计信息:"
    echo "  总行数: $(wc -l < "$OUTPUT_FILE")"
    echo "  文件大小: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
fi

echo -e "${BLUE}版本信息:${NC}"
echo "  当前版本: ${VERSION_TYPE} (${COMMIT_HASH})"
echo "  工作目录: ${WORK_DIR}"
echo "  输出目录: ${OUTPUT_DIR}"
echo ""

echo "查看摘要:"
echo "  cat $OUTPUT_FILE | less"
echo ""

echo -e "${YELLOW}下一步操作:${NC}"
echo "  1. 检查生成的摘要文件"
echo "  2. 分析合约结构和功能"
echo "  3. 使用其他 Slither 工具进行深度分析"

