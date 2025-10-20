#!/bin/bash
# BakerFi 多版本合约数据依赖图提取工具 (重写版本)
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: ./extract-data-dependency.sh [版本目录] [合约目录]

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

# 支持命令行参数指定版本目录和合约目录
TARGET_DIR=""
CONTRACT_DIR=""
if [ $# -gt 0 ]; then
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [版本目录] [合约目录]"
        echo ""
        echo "参数说明:"
        echo "  版本目录选项:"
        echo "    b-pre-mitigation   - 使用b-pre-mitigation版本"
        echo "    b-post-mitigation  - 使用b-post-mitigation版本"
        echo "    latest            - 使用latest版本"
        echo ""
        echo "  合约目录选项:"
        echo "    core              - 分析核心合约 (contracts/core/)"
        echo "    interfaces        - 分析接口合约 (contracts/interfaces/)"
        echo "    libraries         - 分析库合约 (contracts/libraries/)"
        echo "    oracles           - 分析预言机合约 (contracts/oracles/)"
        echo "    proxy             - 分析代理合约 (contracts/proxy/)"
        echo ""
        echo "示例:"
        echo "  $0 b-pre-mitigation core"
        echo "  $0 b-post-mitigation interfaces"
        echo "  $0 latest libraries"
        echo ""
        echo "如果不指定合约目录，将分析所有合约"
        echo "如果不指定版本目录，将自动检测当前目录的版本"
        exit 0
    else
        TARGET_DIR="$1"
        if [ $# -gt 1 ]; then
            CONTRACT_DIR="$2"
        fi
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

echo -e "${BLUE}=== BakerFi 数据依赖图提取工具 (${VERSION_TYPE}版本) ===${NC}"
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
OUTPUT_DIR="$BASE_DIR/workspace/analysis_security_return/slither/data-dependency-${VERSION_TYPE}"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "📁 输出目录: $OUTPUT_DIR"
echo ""

# 检查 slither 是否安装
SLITHER_CMD=""
if command -v slither &> /dev/null; then
    SLITHER_CMD="slither"
elif [ -f "/home/mi/miniconda3/envs/bakerfi/bin/slither" ]; then
    SLITHER_CMD="/home/mi/miniconda3/envs/bakerfi/bin/slither"
else
    echo -e "${RED}✗ Slither 未安装${NC}"
    echo "请安装: pip install slither-analyzer"
    exit 1
fi

echo -e "${GREEN}✓ Slither 已安装: $($SLITHER_CMD --version)${NC}"
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -n "$CONTRACT_DIR" ]; then
    OUTPUT_FILE="${OUTPUT_DIR}/data-dependency-${VERSION_TYPE}-${CONTRACT_DIR}-${TIMESTAMP}.txt"
else
    OUTPUT_FILE="${OUTPUT_DIR}/data-dependency-${VERSION_TYPE}-all-${TIMESTAMP}.txt"
fi

echo -e "${YELLOW}📊 生成数据依赖报告...${NC}"
echo "（这可能需要几分钟时间...）"
echo ""

# 运行 data-dependency printer（严格过滤版本）
echo "  正在运行 Slither 分析..."
echo "  🔍 分析核心合约的数据依赖关系..."
echo "  ⚠ 使用严格过滤条件，排除测试和依赖文件..."
echo ""

# 根据指定的合约目录确定过滤路径
FILTER_PATHS="node_modules/,test/,mocks/"

if [ -n "$CONTRACT_DIR" ]; then
    # 检查指定的合约目录是否存在
    if [ -d "contracts/$CONTRACT_DIR" ]; then
        # 构建过滤路径，排除其他合约目录
        case "$CONTRACT_DIR" in
            "core")
                FILTER_PATHS="node_modules/,test/,mocks/,interfaces/,libraries/,oracles/,proxy/"
                echo "  📁 分析目标: 核心合约 (contracts/core/)"
                ;;
            "interfaces")
                FILTER_PATHS="node_modules/,test/,mocks/,core/,libraries/,oracles/,proxy/"
                echo "  📁 分析目标: 接口合约 (contracts/interfaces/)"
                ;;
            "libraries")
                FILTER_PATHS="node_modules/,test/,mocks/,core/,interfaces/,oracles/,proxy/"
                echo "  📁 分析目标: 库合约 (contracts/libraries/)"
                ;;
            "oracles")
                FILTER_PATHS="node_modules/,test/,mocks/,core/,interfaces/,libraries/,proxy/"
                echo "  📁 分析目标: 预言机合约 (contracts/oracles/)"
                ;;
            "proxy")
                FILTER_PATHS="node_modules/,test/,mocks/,core/,interfaces/,libraries/,oracles/"
                echo "  📁 分析目标: 代理合约 (contracts/proxy/)"
                ;;
            *)
                echo -e "${YELLOW}⚠ 警告: 未知的合约目录 $CONTRACT_DIR，将分析所有合约${NC}"
                ;;
        esac
    else
        echo -e "${YELLOW}⚠ 警告: 合约目录 contracts/$CONTRACT_DIR 不存在，将分析所有合约${NC}"
    fi
else
    echo "  📁 分析目标: 所有合约"
fi

echo ""

# 使用严格过滤条件，根据指定的合约目录进行分析
$SLITHER_CMD . \
  --filter-paths "$FILTER_PATHS" \
  --exclude-dependencies \
  --print data-dependency \
  > "$OUTPUT_FILE.tmp" 2>&1

# 过滤输出，只保留核心合约的数据依赖信息
if [ -f "$OUTPUT_FILE.tmp" ]; then
    # 移除ANSI颜色代码并过滤内容
    sed 's/\x1b\[[0-9;]*m//g' "$OUTPUT_FILE.tmp" | \
    grep -E "(Contract |Function |Variable |Dependencies)" | \
    head -10000 > "$OUTPUT_FILE"
    rm -f "$OUTPUT_FILE.tmp"
fi

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ 生成完成${NC}"
elif [ $EXIT_CODE -eq 255 ]; then
    echo -e "${YELLOW}⚠ 生成完成（有警告）${NC}"
else
    echo -e "${RED}✗ 生成失败（退出码: $EXIT_CODE）${NC}"
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

echo "查看数据依赖:"
echo "  cat $OUTPUT_FILE | less"
echo "  grep -A 10 'Function functionName' $OUTPUT_FILE"
echo ""

echo -e "${YELLOW}下一步操作:${NC}"
echo "  1. 检查生成的数据依赖文件"
echo "  2. 分析变量和函数间的数据流关系"
echo "  3. 识别潜在的数据依赖风险"