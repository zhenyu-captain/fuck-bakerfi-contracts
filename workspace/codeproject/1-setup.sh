#!/bin/bash

# BakerFi Contracts 多版本环境安装脚本
# 支持 b-pre-mitigation, b-post-mitigation, latest 版本
# 所有工具均使用指定版本，不使用 latest

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# 版本配置（所有版本在此集中管理）
# ============================================
NODE_VERSION="20.11.0"
NVM_VERSION="0.39.7"
PYTHON_VERSION="3.11.7"
MINICONDA_VERSION="py311_24.1.2-0"
SLITHER_VERSION="0.10.0"
MYTHRIL_VERSION="0.24.8"
ECHIDNA_VERSION="2.2.4"
SOLC_SELECT_VERSION="1.0.4"

echo "=========================================="
echo "BakerFi 多版本合约环境安装脚本"
echo "=========================================="
echo ""

# ============================================
# 版本检测和路径配置
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"  # 回到 fuck-bakerfi-contracts 目录

# 支持命令行参数指定目标目录
TARGET_DIR=""
if [ $# -gt 0 ]; then
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [目标目录]"
        echo ""
        echo "目标目录选项:"
        echo "  b-pre-mitigation   - 设置b-pre-mitigation版本环境"
        echo "  b-post-mitigation  - 设置b-post-mitigation版本环境"
        echo "  latest            - 设置latest版本环境"
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
    
    if [[ "$WORK_DIR" == *"/workspace"* ]]; then
        echo -e "${RED}❌ 错误: 请在BakerFi合约版本目录中运行此脚本，或使用参数指定目录${NC}"
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

echo -e "${BLUE}检测到的版本: ${VERSION_TYPE} (${COMMIT_HASH})${NC}"
echo -e "${BLUE}目标目录: ${WORK_DIR}${NC}"
echo ""

# 检测是否为重复运行
ENV_VERSION_FILE=".env-versions-${VERSION_TYPE}"
if [ -f "$ENV_VERSION_FILE" ] && [ -z "$FORCE_REINSTALL" ]; then
    echo -e "${YELLOW}⚠️  检测到已安装的环境 (${VERSION_TYPE})${NC}"
    echo ""
    cat "$ENV_VERSION_FILE"
    echo ""
    echo "环境已存在，脚本将跳过已安装的组件"
    echo "如需强制重新安装，请运行: FORCE_REINSTALL=1 ./setup.sh"
    echo "如需验证环境，请运行: ./verify-tools.sh"
    echo ""
    sleep 2
fi

echo -e "${BLUE}版本配置:${NC}"
echo "  BakerFi版本: ${VERSION_TYPE} (${COMMIT_HASH})"
echo "  Node.js: ${NODE_VERSION}"
echo "  Python: ${PYTHON_VERSION} (via Anaconda)"
echo "  Slither: ${SLITHER_VERSION}"
echo "  Mythril: ${MYTHRIL_VERSION}"
echo "  Echidna: ${ECHIDNA_VERSION}"
echo ""

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}❌ 请不要使用 root 用户运行此脚本${NC}"
    exit 1
fi

# 检测操作系统
OS="unknown"
ARCH=$(uname -m)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

echo -e "${GREEN}检测到系统: $OS ($ARCH)${NC}"
echo ""

# ============================================
# 1. 检查系统基础依赖
# ============================================
echo -e "${YELLOW}[1/8] 检查系统基础依赖...${NC}"

MISSING_DEPS=()

# 检查必需工具
for cmd in curl wget git; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_DEPS+=($cmd)
    fi
done

if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ 必需的系统工具已安装${NC}"
else
    echo -e "${YELLOW}⚠️  缺少系统工具: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}请手动安装后重新运行脚本：${NC}"
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        echo "  sudo apt-get install curl wget git build-essential"
    elif [ "$OS" = "fedora" ] || [ "$OS" = "rhel" ] || [ "$OS" = "centos" ]; then
        echo "  sudo dnf install curl wget git gcc gcc-c++ make"
    elif [ "$OS" = "arch" ] || [ "$OS" = "manjaro" ]; then
        echo "  sudo pacman -S curl wget git base-devel"
    fi
    
    exit 1
fi
echo ""

# ============================================
# 2. 安装 nvm 和 Node.js
# ============================================
echo -e "${YELLOW}[2/8] 安装 Node.js ${NODE_VERSION} (via nvm ${NVM_VERSION})...${NC}"

# 安装 nvm
if [ ! -d "$HOME/.nvm" ]; then
    echo "  安装 nvm ${NVM_VERSION}..."
    curl -sS https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash > /dev/null 2>&1
fi

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# 安装指定版本的 Node.js
if ! nvm list | grep -q "v${NODE_VERSION}"; then
    echo "  安装 Node.js ${NODE_VERSION}..."
    nvm install ${NODE_VERSION} > /dev/null 2>&1
fi

nvm use ${NODE_VERSION} > /dev/null 2>&1
nvm alias default ${NODE_VERSION} > /dev/null 2>&1

NODE_ACTUAL=$(node --version)
NPM_ACTUAL=$(npm --version)

echo -e "${GREEN}✓ Node.js ${NODE_ACTUAL} 安装完成${NC}"
echo -e "${GREEN}✓ npm ${NPM_ACTUAL} 已就绪${NC}"
echo ""

# ============================================
# 3. 安装 Miniconda 和 Python
# ============================================
echo -e "${YELLOW}[3/8] 安装 Python ${PYTHON_VERSION} (via Miniconda)...${NC}"

CONDA_DIR="$HOME/miniconda3"
CONDA_ENV_NAME="bakerfi"

if [ ! -d "$CONDA_DIR" ]; then
    echo "  下载 Miniconda ${MINICONDA_VERSION}..."
    
    if [ "$ARCH" = "x86_64" ]; then
        MINICONDA_INSTALLER="Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh"
    elif [ "$ARCH" = "aarch64" ]; then
        MINICONDA_INSTALLER="Miniconda3-${MINICONDA_VERSION}-Linux-aarch64.sh"
    else
        echo -e "${RED}❌ 不支持的架构: $ARCH${NC}"
        exit 1
    fi
    
    cd /tmp
    wget -q https://repo.anaconda.com/miniconda/${MINICONDA_INSTALLER}
    bash ${MINICONDA_INSTALLER} -b -p $CONDA_DIR > /dev/null 2>&1
    rm ${MINICONDA_INSTALLER}
    cd - > /dev/null
    
    echo "  Miniconda 安装完成"
fi

# 初始化 conda
eval "$($CONDA_DIR/bin/conda shell.bash hook)"

# 创建或更新 conda 环境
if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
    echo "  环境 ${CONDA_ENV_NAME} 已存在，跳过创建"
else
    echo "  创建 conda 环境: ${CONDA_ENV_NAME} (Python ${PYTHON_VERSION})..."
    conda create -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} -y -q > /dev/null 2>&1
fi

# 激活环境
conda activate ${CONDA_ENV_NAME}

PYTHON_ACTUAL=$(python --version 2>&1)
echo -e "${GREEN}✓ ${PYTHON_ACTUAL} 安装完成${NC}"
echo -e "${GREEN}✓ Conda 环境: ${CONDA_ENV_NAME}${NC}"
echo ""

# ============================================
# 4. 安装项目 npm 依赖
# ============================================
echo -e "${YELLOW}[4/8] 检查并安装项目 npm 依赖...${NC}"

if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ 未找到 package.json${NC}"
    echo -e "${YELLOW}当前目录: ${PWD}${NC}"
    echo -e "${YELLOW}请确保在正确的BakerFi合约版本目录中运行此脚本${NC}"
    exit 1
fi

# 检查是否已安装依赖
if [ -d "node_modules" ] && [ -z "$FORCE_REINSTALL" ]; then
    echo "  检测到 node_modules 目录，检查依赖完整性..."
    
    # 检查 package-lock.json 是否存在且匹配
    if [ -f "package-lock.json" ]; then
        # 使用 npm ls 检查依赖是否完整（静默模式）
        if npm ls --depth=0 > /dev/null 2>&1; then
            PACKAGE_COUNT=$(find node_modules -maxdepth 1 -type d | wc -l)
            echo -e "${GREEN}✓ npm 依赖已安装且完整 (${PACKAGE_COUNT} 个包)${NC}"
            echo "  版本: ${VERSION_TYPE} (${COMMIT_HASH})"
            echo "  如需重新安装，请运行: FORCE_REINSTALL=1 ./1-setup.sh"
            echo ""
            # 跳过安装步骤
        else
            echo "  依赖不完整，重新安装..."
            npm install --silent > /dev/null 2>&1
            echo -e "${GREEN}✓ npm 依赖重新安装完成${NC}"
        fi
    else
        echo "  未找到 package-lock.json，重新安装..."
        npm install --silent > /dev/null 2>&1
        echo -e "${GREEN}✓ npm 依赖安装完成${NC}"
    fi
else
    echo "  执行 npm install (可能需要几分钟)..."
    echo "  版本: ${VERSION_TYPE} (${COMMIT_HASH})"
    INSTALL_START=$(date +%s)
    npm install --silent > /dev/null 2>&1
    INSTALL_END=$(date +%s)
    INSTALL_TIME=$((INSTALL_END - INSTALL_START))
    echo -e "${GREEN}✓ npm 依赖安装完成 (${INSTALL_TIME}秒)${NC}"
fi

# 显示包数量统计
if [ -d "node_modules" ]; then
    PACKAGE_COUNT=$(find node_modules -maxdepth 1 -type d | wc -l)
    echo "  已安装包: $((PACKAGE_COUNT - 1)) 个"
fi
echo ""

# ============================================
# 5. 安装 Slither
# ============================================
echo -e "${YELLOW}[5/8] 检查并安装 Slither ${SLITHER_VERSION}...${NC}"

# 检查 Slither 是否已安装且版本正确
SLITHER_INSTALLED=$(pip show slither-analyzer 2>/dev/null | grep Version | cut -d' ' -f2 || echo "")
SOLC_SELECT_INSTALLED=$(pip show solc-select 2>/dev/null | grep Version | cut -d' ' -f2 || echo "")

if [ "$SLITHER_INSTALLED" = "$SLITHER_VERSION" ] && [ "$SOLC_SELECT_INSTALLED" = "$SOLC_SELECT_VERSION" ] && [ -z "$FORCE_REINSTALL" ]; then
    echo -e "${GREEN}✓ Slither ${SLITHER_INSTALLED} 已安装${NC}"
    echo -e "${GREEN}✓ solc-select ${SOLC_SELECT_INSTALLED} 已安装${NC}"
    echo "  如需重新安装，请运行: FORCE_REINSTALL=1 ./1-setup.sh"
else
    if [ -n "$SLITHER_INSTALLED" ] || [ -n "$SOLC_SELECT_INSTALLED" ]; then
        echo "  检测到不同版本的工具，重新安装..."
        # 先卸载可能存在的旧版本
        pip uninstall -y slither-analyzer mythril solc-select > /dev/null 2>&1 || true
    else
        echo "  安装 Slither 和 solc-select..."
    fi
    
    # 重新安装 Slither 及其依赖（一次性安装避免冲突）
    pip install --quiet slither-analyzer==${SLITHER_VERSION} > /dev/null 2>&1
    
    # 安装 solc-select 用于管理 Solidity 编译器版本
    pip install --quiet solc-select==${SOLC_SELECT_VERSION} > /dev/null 2>&1
    
    # 安装项目需要的 solc 版本 (0.8.24 是主版本)
    solc-select install 0.8.24 > /dev/null 2>&1 || true
    solc-select use 0.8.24 > /dev/null 2>&1 || true
    
    # 验证安装（忽略警告）
    SLITHER_ACTUAL=$(pip show slither-analyzer 2>/dev/null | grep Version | cut -d' ' -f2 || echo "${SLITHER_VERSION}")
    SOLC_SELECT_ACTUAL=$(pip show solc-select 2>/dev/null | grep Version | cut -d' ' -f2 || echo "${SOLC_SELECT_VERSION}")
    echo -e "${GREEN}✓ Slither ${SLITHER_ACTUAL} 安装完成${NC}"
    echo -e "${GREEN}✓ solc-select ${SOLC_SELECT_ACTUAL} 安装完成${NC}"
fi
echo ""

# ============================================
# 6. 安装 Mythril (可选)
# ============================================
echo -e "${YELLOW}[6/8] 检查并安装 Mythril ${MYTHRIL_VERSION}...${NC}"

# 检查 Mythril 是否已安装且版本正确
MYTHRIL_INSTALLED=$(pip show mythril 2>/dev/null | grep Version | cut -d' ' -f2 || echo "")

if [ "$MYTHRIL_INSTALLED" = "$MYTHRIL_VERSION" ] && [ -z "$FORCE_REINSTALL" ]; then
    echo -e "${GREEN}✓ Mythril ${MYTHRIL_INSTALLED} 已安装${NC}"
    echo "  如需重新安装，请运行: FORCE_REINSTALL=1 ./1-setup.sh"
else
    if [ -n "$MYTHRIL_INSTALLED" ]; then
        echo "  检测到不同版本的 Mythril，重新安装..."
        # 先卸载可能存在的旧版本
        pip uninstall -y mythril > /dev/null 2>&1 || true
    else
        echo "  安装 Mythril..."
    fi
    
    # 安装 Mythril
    pip install --quiet mythril==${MYTHRIL_VERSION} > /dev/null 2>&1 || {
        echo -e "${YELLOW}⚠️  Mythril 安装失败（可选工具，不影响主要功能）${NC}"
    }
    
    if command -v myth &> /dev/null; then
        MYTH_ACTUAL=$(myth version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' | head -n 1 || echo "${MYTHRIL_VERSION}")
        echo -e "${GREEN}✓ Mythril ${MYTH_ACTUAL} 安装完成${NC}"
    else
        echo -e "${YELLOW}⚠️  Mythril 未安装（可选）${NC}"
    fi
fi
echo ""

# ============================================
# 7. 安装 Echidna
# ============================================
echo -e "${YELLOW}[7/8] 检查并安装 Echidna ${ECHIDNA_VERSION}...${NC}"

# 检查 Echidna 是否已安装
ECHIDNA_INSTALLED=""

# 临时添加 ~/.local/bin 到 PATH 进行检查
export PATH="$HOME/.local/bin:$PATH"

if command -v echidna &> /dev/null; then
    ECHIDNA_INSTALLED=$(echidna --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -n 1 || echo "")
elif command -v echidna-test &> /dev/null; then
    ECHIDNA_INSTALLED=$(echidna-test --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -n 1 || echo "")
fi

# 如果版本检测失败但命令存在，假设已安装
if [ -z "$ECHIDNA_INSTALLED" ] && (command -v echidna &> /dev/null || command -v echidna-test &> /dev/null); then
    ECHIDNA_INSTALLED="$ECHIDNA_VERSION"
fi

# 如果 Echidna 已安装且不是强制重新安装，则跳过
if [ -n "$ECHIDNA_INSTALLED" ] && [ -z "$FORCE_REINSTALL" ]; then
    if command -v echidna &> /dev/null; then
        ECHIDNA_ACTUAL=$(echidna --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ ${ECHIDNA_ACTUAL} 已安装${NC}"
    elif command -v echidna-test &> /dev/null; then
        ECHIDNA_ACTUAL=$(echidna-test --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ ${ECHIDNA_ACTUAL} 已安装${NC}"
    fi
    echo "  如需重新安装，请运行: FORCE_REINSTALL=1 ./1-setup.sh"
else
    echo "  安装 Echidna..."
    
    ECHIDNA_URL="https://github.com/crytic/echidna/releases/download/v${ECHIDNA_VERSION}/echidna-${ECHIDNA_VERSION}-x86_64-linux.tar.gz"
    
    cd /tmp
    rm -rf echidna_install
    mkdir -p echidna_install
    
    if wget -q "$ECHIDNA_URL" -O echidna.tar.gz 2>/dev/null; then
        if tar -xzf echidna.tar.gz -C echidna_install 2>/dev/null; then
            # 查找可执行文件并安装到用户目录
            mkdir -p $HOME/.local/bin
            
            if [ -f "echidna_install/echidna" ]; then
                # 强制覆盖，避免交互式提示
                rm -f $HOME/.local/bin/echidna 2>/dev/null
                mv echidna_install/echidna $HOME/.local/bin/ 2>/dev/null
                chmod +x $HOME/.local/bin/echidna 2>/dev/null
                echo -e "${GREEN}✓ Echidna 安装到 ~/.local/bin/${NC}"
            elif [ -f "echidna_install/echidna-test" ]; then
                # 强制覆盖，避免交互式提示
                rm -f $HOME/.local/bin/echidna-test 2>/dev/null
                mv echidna_install/echidna-test $HOME/.local/bin/ 2>/dev/null
                chmod +x $HOME/.local/bin/echidna-test 2>/dev/null
                echo -e "${GREEN}✓ Echidna 安装到 ~/.local/bin/${NC}"
            else
                echo -e "${YELLOW}⚠️  Echidna 可执行文件未找到（可选工具）${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Echidna 解压失败（可选工具）${NC}"
        fi
        
        rm -rf echidna_install echidna.tar.gz
    else
        echo -e "${YELLOW}⚠️  Echidna 下载失败（可选工具）${NC}"
    fi
    cd - > /dev/null
    
    # 验证安装
    if command -v echidna &> /dev/null; then
        ECHIDNA_ACTUAL=$(echidna --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ ${ECHIDNA_ACTUAL} 安装完成${NC}"
    elif command -v echidna-test &> /dev/null; then
        ECHIDNA_ACTUAL=$(echidna-test --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ ${ECHIDNA_ACTUAL} 安装完成${NC}"
    else
        echo -e "${YELLOW}⚠️  Echidna 未安装（可选工具，不影响核心功能）${NC}"
    fi
fi
echo ""

# ============================================
# 8. 安装 Surya (可选的可视化工具)
# ============================================
echo -e "${YELLOW}[8/8] 检查并安装 Surya (可视化工具)...${NC}"

# Surya 版本通过 npm 安装
SURYA_VERSION="0.4.11"

# 检查 Surya 是否已安装
SURYA_INSTALLED=$(npm list -g surya 2>/dev/null | grep surya | grep -oP '\d+\.\d+\.\d+' | head -n 1 || echo "")

if [ "$SURYA_INSTALLED" = "$SURYA_VERSION" ] && [ -z "$FORCE_REINSTALL" ]; then
    echo -e "${GREEN}✓ Surya ${SURYA_INSTALLED} 已安装${NC}"
    echo "  如需重新安装，请运行: FORCE_REINSTALL=1 ./1-setup.sh"
else
    if [ -n "$SURYA_INSTALLED" ]; then
        echo "  检测到不同版本的 Surya，重新安装..."
        npm uninstall -g surya > /dev/null 2>&1 || true
    else
        echo "  安装 Surya..."
    fi
    
    npm install -g --silent surya@${SURYA_VERSION} > /dev/null 2>&1 || {
        echo -e "${YELLOW}⚠️  Surya 安装失败（可选工具）${NC}"
    }
    
    if command -v surya &> /dev/null; then
        echo -e "${GREEN}✓ Surya ${SURYA_VERSION} 安装完成${NC}"
    else
        echo -e "${YELLOW}⚠️  Surya 未安装（可选）${NC}"
    fi
fi
echo ""

# ============================================
# 环境验证
# ============================================
echo "=========================================="
echo -e "${BLUE}环境验证${NC}"
echo "=========================================="
echo ""

# 临时添加 ~/.local/bin 到 PATH 用于验证
export PATH="$HOME/.local/bin:$PATH"

echo "=== 核心工具 ==="
echo "  Node.js:  $(node --version)"
echo "  npm:      $(npm --version)"
echo "  Python:   $(python --version 2>&1)"
echo "  Conda:    $(conda --version 2>&1)"
echo ""

echo "=== 审计工具 ==="
echo "  Slither:  $(slither --version 2>&1 | head -n 1)"

# 检查 Echidna
if command -v echidna &> /dev/null; then
    echo "  Echidna:  $(echidna --version 2>&1 | head -n 1)"
elif [ -f "$HOME/.local/bin/echidna" ]; then
    echo "  Echidna:  $($HOME/.local/bin/echidna --version 2>&1 | head -n 1)"
else
    echo "  Echidna:  未安装"
fi

if command -v myth &> /dev/null; then
    echo "  Mythril:  $(myth version 2>&1 | grep -oP "v\d+\.\d+\.\d+" | head -n 1)"
fi
if command -v surya &> /dev/null; then
    echo "  Surya:    已安装"
fi
echo ""

echo "=== Hardhat 检查 ==="
if npx hardhat --version > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Hardhat 可用${NC}"
else
    echo -e "  ${YELLOW}⚠️  Hardhat 需要首次初始化${NC}"
fi
echo ""

# ============================================
# 创建激活脚本
# ============================================
ACTIVATE_SCRIPT="activate-env-${VERSION_TYPE}.sh"
if [ ! -f "$ACTIVATE_SCRIPT" ]; then
    echo "创建环境激活脚本: $ACTIVATE_SCRIPT..."
else
    echo "更新环境激活脚本: $ACTIVATE_SCRIPT..."
fi

cat > "$ACTIVATE_SCRIPT" << ACTIVATE_EOF
#!/bin/bash
# BakerFi 环境激活脚本 (${VERSION_TYPE}版本)
# 使用方法: source ./$ACTIVATE_SCRIPT

# 添加本地 bin 到 PATH
export PATH="\$HOME/.local/bin:\$PATH"

# 激活 nvm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

# 激活 conda 环境
eval "\$(\$HOME/miniconda3/bin/conda shell.bash hook)"
conda activate bakerfi

# 设置版本信息
export BAKERFI_VERSION_TYPE="${VERSION_TYPE}"
export BAKERFI_COMMIT_HASH="${COMMIT_HASH}"

echo "✓ BakerFi 开发环境已激活 (${VERSION_TYPE}版本)"
echo "  版本: ${VERSION_TYPE} (${COMMIT_HASH})"
echo "  Node.js: \$(node --version)"
echo "  Python: \$(python --version 2>&1)"
echo "  工作目录: \$(pwd)"
ACTIVATE_EOF

chmod +x "$ACTIVATE_SCRIPT"

# 创建通用激活脚本链接
if [ ! -f "activate-env.sh" ]; then
    ln -s "$ACTIVATE_SCRIPT" activate-env.sh
    echo "✓ 创建通用激活脚本链接: activate-env.sh -> $ACTIVATE_SCRIPT"
fi

# ============================================
# 创建环境配置文件
# ============================================
if [ ! -f ".env" ]; then
    echo "创建 .env 配置模板..."
    cat > .env << 'ENV_EOF'
# BakerFi 环境变量配置

# 本地开发
WEB3_RPC_LOCAL_URL=http://127.0.0.1:8545

# RPC 节点（留空使用默认）
WEB3_RPC_ETH_MAIN_NET_URL=
WEB3_RPC_ARBITRUM_URL=
WEB3_RPC_OPTIMISM_URL=
WEB3_RPC_BASE_URL=

# API Keys
ANKR_API_KEY=
ETHERSCAN_API_KEY=
BASESCAN_API_KEY=
ARBSCAN_API_KEY=

# 部署私钥（生产环境）
BAKERFI_PRIVATE_KEY=

# Tenderly 开发网络
TENDERLY_DEV_NET_RPC=

# Gas 报告
REPORT_GAS=false
ENV_EOF
fi

# ============================================
# 完成
# ============================================
echo "=========================================="
echo -e "${GREEN}🎉 环境安装完成！${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}已安装版本:${NC}"
echo "  ├─ Node.js ${NODE_VERSION}"
echo "  ├─ Python ${PYTHON_VERSION}"
echo "  ├─ Slither ${SLITHER_VERSION}"
echo "  ├─ Mythril ${MYTHRIL_VERSION}"
echo "  └─ Echidna ${ECHIDNA_VERSION}"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo "  1. 激活环境:"
echo -e "     ${GREEN}source ./activate-env.sh${NC}"
echo ""
echo "  2. 验证项目（推荐）:"
echo -e "     ${GREEN}./verify-project.sh${NC}"
echo ""
echo "  3. 或手动执行:"
echo -e "     ${GREEN}npx hardhat compile${NC}      # 编译合约"
echo -e "     ${GREEN}npx hardhat test${NC}         # 运行测试"
echo -e "     ${GREEN}npx hardhat coverage${NC}     # 生成覆盖率"
echo ""
echo -e "${BLUE}版本特定信息:${NC}"
echo "  当前版本: ${VERSION_TYPE} (${COMMIT_HASH})"
echo "  激活脚本: activate-env-${VERSION_TYPE}.sh"
echo "  版本文件: ${ENV_VERSION_FILE}"
echo ""
echo -e "${YELLOW}注意:${NC} 每次打开新终端需要先运行: ${GREEN}source ./activate-env.sh${NC}"
echo ""

# 保存版本信息
cat > "$ENV_VERSION_FILE" << EOF
# BakerFi 环境版本记录 (${VERSION_TYPE})
# 安装时间: $(date)
# 工作目录: ${PWD}
BAKERFI_VERSION_TYPE=${VERSION_TYPE}
BAKERFI_COMMIT_HASH=${COMMIT_HASH}
NODE_VERSION=${NODE_VERSION}
PYTHON_VERSION=${PYTHON_VERSION}
SLITHER_VERSION=${SLITHER_VERSION}
MYTHRIL_VERSION=${MYTHRIL_VERSION}
ECHIDNA_VERSION=${ECHIDNA_VERSION}
SURYA_VERSION=${SURYA_VERSION}
EOF

echo -e "${GREEN}✓ 版本信息已保存到 $ENV_VERSION_FILE${NC}"
echo ""

