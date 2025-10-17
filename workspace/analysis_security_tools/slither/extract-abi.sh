#!/bin/bash
# BakerFi 多版本合约 ABI 提取工具
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 使用方法: ./extract-abi.sh [目标目录]

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
        echo "  b-pre-mitigation   - 提取b-pre-mitigation版本合约ABI"
        echo "  b-post-mitigation  - 提取b-post-mitigation版本合约ABI"
        echo "  latest            - 提取latest版本合约ABI"
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

echo -e "${BLUE}=== BakerFi 合约 ABI 提取工具 (${VERSION_TYPE}版本) ===${NC}"
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
OUTPUT_DIR="$BASE_DIR/workspace/analysis_security_return/slither/abi-${VERSION_TYPE}"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "📁 输出目录: $OUTPUT_DIR"
echo ""

# 提取核心合约
echo "📦 提取核心合约 ABI..."
CORE_CONTRACTS=(
  "Vault"
  "VaultBase"
  "VaultSettings"
  "VaultRegistry"
  "VaultRouter"
  "GovernableOwnable"
  "MultiCommand"
  "MultiStrategy"
  "MultiStrategyVault"
)

for contract in "${CORE_CONTRACTS[@]}"; do
  file="artifacts/contracts/core/${contract}.sol/${contract}.json"
  if [ -f "$file" ]; then
    cat "$file" | jq . > "${OUTPUT_DIR}/${contract}.json"
    echo -e "  ${GREEN}✓${NC} ${contract}.json"
  else
    echo -e "  ⚠ ${contract}.json (未找到)"
  fi
done

# 提取策略合约
echo ""
echo "🎯 提取策略合约 ABI..."
STRATEGY_DIR="artifacts/contracts/core/strategies"
if [ -d "$STRATEGY_DIR" ]; then
  for file in "$STRATEGY_DIR"/*.sol/*.json; do
    if [ -f "$file" ] && [[ ! "$file" =~ \.dbg\.json$ ]]; then
      name=$(basename "$file")
      cat "$file" | jq . > "${OUTPUT_DIR}/${name}"
      echo -e "  ${GREEN}✓${NC} ${name}"
    fi
  done
fi

# 提取 Oracle 合约
echo ""
echo "🔮 提取 Oracle 合约 ABI..."
ORACLE_DIR="artifacts/contracts/oracles"
if [ -d "$ORACLE_DIR" ]; then
  for file in "$ORACLE_DIR"/*.sol/*.json; do
    if [ -f "$file" ] && [[ ! "$file" =~ \.dbg\.json$ ]]; then
      name=$(basename "$file")
      cat "$file" | jq . > "${OUTPUT_DIR}/${name}"
      echo -e "  ${GREEN}✓${NC} ${name}"
    fi
  done
fi

# 统计
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
echo "  1. 检查提取的 ABI 文件"
echo "  2. 使用 ABI 进行安全分析"
echo "  3. 运行 Slither 或其他分析工具"

