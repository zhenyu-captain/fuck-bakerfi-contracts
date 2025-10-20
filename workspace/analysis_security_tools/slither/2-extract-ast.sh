#!/bin/bash
# BakerFi 多版本合约 AST 提取工具
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: ./extract-ast.sh [目标目录]

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
        echo "  b-pre-mitigation   - 提取b-pre-mitigation版本合约AST"
        echo "  b-post-mitigation  - 提取b-post-mitigation版本合约AST"
        echo "  latest            - 提取latest版本合约AST"
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

echo -e "${BLUE}=== BakerFi 合约 AST 提取工具 (${VERSION_TYPE}版本) ===${NC}"
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
OUTPUT_DIR="$BASE_DIR/workspace/analysis_security_return/slither/ast-${VERSION_TYPE}"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "📁 输出目录: $OUTPUT_DIR"
echo ""

# 查找 build-info 文件
BUILD_INFO=$(ls -t artifacts/build-info/*.json 2>/dev/null | head -1)

if [ -z "$BUILD_INFO" ]; then
  echo -e "${YELLOW}⚠ 未找到 build-info 文件，请先运行: npx hardhat compile${NC}"
  exit 1
fi

echo "📁 使用 build-info: $(basename $BUILD_INFO)"
echo ""

# 要提取的合约列表
CONTRACTS=(
  "contracts/core/Vault.sol"
  "contracts/core/VaultBase.sol"
  "contracts/core/VaultSettings.sol"
  "contracts/core/VaultRegistry.sol"
  "contracts/core/VaultRouter.sol"
  "contracts/core/GovernableOwnable.sol"
  "contracts/core/MultiCommand.sol"
  "contracts/core/MultiStrategy.sol"
  "contracts/core/MultiStrategyVault.sol"
)

echo "🌳 提取 AST..."
for contract_path in "${CONTRACTS[@]}"; do
  contract_name=$(basename "$contract_path" .sol)
  
  # 提取完整源码信息（包括 AST、id 等）
  cat "$BUILD_INFO" | \
    jq ".output.sources[\"$contract_path\"]" \
    > "${OUTPUT_DIR}/${contract_name}-full.json"
  
  # 只提取 AST 部分
  cat "$BUILD_INFO" | \
    jq ".output.sources[\"$contract_path\"].ast" \
    > "${OUTPUT_DIR}/${contract_name}-ast.json"
  
  echo -e "  ${GREEN}✓${NC} ${contract_name}-ast.json"
done

# 提取策略合约 AST
echo ""
echo "🎯 提取策略合约 AST..."
for strategy_path in artifacts/contracts/core/strategies/*.sol; do
  if [ -d "$strategy_path" ]; then
    strategy_file=$(basename "$strategy_path")
    strategy_name="${strategy_file%.sol}"
    contract_path="contracts/core/strategies/$strategy_file"
    
    # 检查是否存在于 build-info 中
    if cat "$BUILD_INFO" | jq -e ".output.sources[\"$contract_path\"]" > /dev/null 2>&1; then
      cat "$BUILD_INFO" | \
        jq ".output.sources[\"$contract_path\"].ast" \
        > "${OUTPUT_DIR}/${strategy_name}-ast.json"
      echo -e "  ${GREEN}✓${NC} ${strategy_name}-ast.json"
    fi
  fi
done

echo ""
echo -e "${GREEN}=== 完成! ===${NC}"
echo "总计: $(ls -1 "$OUTPUT_DIR"/*.json 2>/dev/null | wc -l) 个文件"
echo "位置: $OUTPUT_DIR/"
echo ""
echo -e "${BLUE}版本信息:${NC}"
echo "  当前版本: ${VERSION_TYPE} (${COMMIT_HASH})"
echo "  工作目录: ${WORK_DIR}"
echo "  输出目录: ${OUTPUT_DIR}"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo "  1. 检查提取的 AST 文件"
echo "  2. 使用 AST 进行深度分析"
echo "  3. 运行 Slither 或其他分析工具"

