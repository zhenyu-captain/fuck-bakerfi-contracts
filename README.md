# BakerFi 合约安全编号分析报告

## 服务目标
* 利用pre/post哈希的精确定位，开始自主审计的能力评估，复现真实的审计发现过程和实施流程。

## 版本时间线和安全状态

## 版本信息
- **zero-tests-version**: 223faa2 (初始版本，无测试)
- **a-pre-mitigation**: v1.0.0-alpha.1 (第一轮审计前版本，漏洞存在)
- **a-post-mitigation**: v1.0.0-beta.2 (第一轮审计修复版本)
- **c-pre-mitigation**: 1af20ca (持续开发阶段，漏洞存在)
- **c-post-mitigation**: 6fef399 (持续开发修复版本，漏洞修复)
- **b-pre-mitigation**: 81485a9 (第二轮审计前版本，新漏洞存在)
- **b-post-mitigation**: f99edb1 (第二轮审计修复版本，修复所有漏洞)

### 1. zero-tests-version (223faa2) - 2023年7月
- **版本性质**: 初始版本
- **安全状态**: 无已知安全问题
- **包含的安全编号**: 无

---

### 2. a-pre-mitigation (v1.0.0-alpha.1) - 2023年10月
- **版本性质**: 第一轮审计前版本 - **包含14个未修复的BKR问题**
- **安全状态**: ❌ **包含14个未修复的BKR安全问题**
- **重要说明**: 
  - 这是真正的"审计前"版本，包含所有已知的BKR安全漏洞
  - 从v1.0.0-alpha.1到v1.0.0-alpha.6期间，逐步修复了14个BKR问题
  - 版本名称中的"pre-mitigation"指的是漏洞修复前的状态
- **包含的BKR漏洞** (未修复):
  - BKR-13: Chainlink - Deprecated Integration And Lax Validation
  - BKR-15: Balancer - No Hardcoded Fee
  - BKR-16: Calculations On Stale Price Data During Withdrawal
  - BKR-17: Boring License Inclusion
  - BKR-18: Not allowed to deposit funds directly to vault
  - BKR-19: Uninitialized Implementation, Vault using revert instead of requires
  - BKR-20: Check effects interaction
  - BKR-22: Remove Unused code
  - BKR-23: Inconsistent Use Of UseServiceRegistry
  - BKR-24: Separring Boring Library Tests from Boring Library
  - BKR-25: 2step ownable for Vault
  - BKR-26: Balancer - No Hardcoded Fee
  - BKR-29: Upgrade to compiler 0.8.20
  - BKR-30: Refactor settings to support independent strategy parameters

---

### 3. a-post-mitigation (v1.0.0-beta.2) - 2024年6月
- **版本性质**: 第一轮审计后版本 - **第一轮审计修复完成版本，修复了27个BKR安全问题**
- **安全状态**: ✅ **基于v1.0.0-alpha.6（已修复14个BKR问题）继续开发，额外修复了13个新的BKR问题，总计修复27个BKR安全问题。相比真正的审计前版本v1.0.0-alpha.1，这是一个完全修复的版本**
- **修复状态**:
  - ✅ **继承了a-pre-mitigation的14个BKR修复** (BKR-13 到 BKR-30)
  - ✅ **审计期间新发现并修复的13个BKR问题**:
    - BKR-43: Pyth Oracle Updates and Rebalance Daily
    - BKR-53: Price takes into account chainlink oracle decimals
    - BKR-55: Slippage protection on Strategy Swaps
    - BKR-57: Supply the swap single output back to AAVE
    - BKR-58: Deadline on swap and using UniswapRouter
    - BKR-59: Deadline on swap and using UniswapRouter
    - BKR-60: Supply the swap single output back to AAVE
    - BKR-62: Configurable Circuit breaker for chainlink oracle prices
    - BKR-66: Avoid Round Down on Withdrawal Fees
    - BKR-67: roundup on performance fee calculation
    - BKR-68: Returning ETH excess after a pyth price update
    - BKR-69: Wrong withdraw value
    - BKR-70: Pyth answers Sanity Checks
    - BKR-71: price outdated on latest update

---

### 4. c-pre-mitigation (1af20ca) - 持续开发阶段
- **版本性质**: 第一轮审计修复后的持续开发阶段，发现新问题但未修复
- **提交时间**: 2024年7月30日
- **安全状态**: ❌ **基于v1.0.0-beta.2继续开发，发现了13个新的BKR问题但未修复**
- **发现的BKR问题** (13个，未修复):
  - BKR-46: Hook functions internal
  - BKR-81: Validate contracts on Base Scan
  - BKR-83: Using prices for swap slippage instead of onchain quoters
  - BKR-88: Change oracles
  - BKR-89: Vault ERC4626 Standard
  - BKR-99: Pause/Pause by Multiple EOA
  - BKR-106: Leverage Strategy with Morpho Blue
  - BKR-111: Debt token could be a generic Token and not only WETH
  - BKR-116: Fixed Round issues on Withdraw
  - BKR-122: Support For Multiple Strategy per chain + Lido AAVE v3 Markets
  - BKR-143: Ethereum deployment
  - BKR-144: Morpho Blue Strategy on Base
  - BKR-145: Get Position returns values in USD

---

### 5. c-post-mitigation (6fef399) - 持续开发修复版本
- **版本性质**: 持续开发阶段的修复版本，修复了新发现的问题
- **提交时间**: 2024年10月3日
- **安全状态**: ✅ **修复了c-pre-mitigation中发现的13个BKR问题**
- **修复的BKR问题** (13个):
  - BKR-46: Make the Hook functions internal (2024-07-30)
  - BKR-81: Validate contracts on Base Scan (2024-07-23)
  - BKR-83: Using prices for swap slippage instead of onchain quoters (2024-07-22)
  - BKR-88: Change oracles (2024-07-30)
  - BKR-89: Vault ERC4626 Standard (2024-07-30)
  - BKR-99: Pause/Pause by Multiple EOA (2024-10-09)
  - BKR-106: Leverage Strategy with Morpho Blue (2024-09-04)
  - BKR-111: Debt token could be a generic Token and not only WETH (2024-09-03)
  - BKR-116: Fixed Round issues on Withdraw (2024-08-13)
  - BKR-122: Support For Multiple Strategy per chain + Lido AAVE v3 Markets (2024-09-23)
  - BKR-143: Ethereum deployment (2024-10-14)
  - BKR-144: Morpho Blue Strategy on Base (2024-10-21)
  - BKR-145: Get Position returns values in USD (2024-10-03)

---

### 6. b-pre-mitigation (81485a9) - 2024年11月
- **版本性质**: 第二轮审计前版本 - **新漏洞引入阶段**
- **安全状态**: 
  - ✅ **继承了所有之前的修复** (BKR-13 到 BKR-145)
  - ❌ **新引入了14个漏洞** (BKR-200单独分类):
    - BKR-157: Vault with support for N Strategies (2024-11-20)
    - BKR-159: Morpho Supply Strategy (2024-12-04)
    - BKR-169: Multiple strategies (2025-01-27)
    - BKR-178: swapper multiple implementations (2024-11-26)
    - BKR-179: vault router support for aerodrome swaps (2024-11-27)
    - BKR-195: _deployedAmount not updated on StrategySupplyBase.undeploy, preventing performance fees from being collected - F6 (2025-01-09)
    - BKR-197: decimals conversions There are multiple issues with the decimal conversions between the vault and the strategy - F13 (2025-01-16)
    - BKR-199: Malicious actors can exploit user-approved allowances on VaultRouter to drain their ERC20 tokens - F18 (2025-01-14)
    - BKR-206: VaultBase is not ERC4626 compliant - F3 (2025-01-14)
    - BKR-207: Even when the Vault contract is paused, the rebalance function is not paused - F12 (2025-01-07)
    - BKR-208: The interaction between the router and the ERC4626 vault lacks slippage control - F14 (2025-01-15)
    - BKR-255: Remove ERC20 approve zero (2025-02-05)
    - BKR-256: harvest before change perf (2025-02-05)
    - CK-209/F11: _handleSweepTokens function lacks ability to withdraw native ETH

---

### 6.5. BKR-200 特殊时间线 - 2024年12月-2025年1月
- **版本性质**: **特殊功能引入和修复阶段** - **ERC4626策略功能开发**
- **安全状态**: 
  - **功能引入阶段 (dfcf463)**: 2024年12月4日 - 首次创建StrategySupplyERC4626.sol，但存在漏洞
  - **漏洞修复阶段 (ce9d853)**: 2025年1月14日 - 修复ERC4626标准理解错误
- **特殊说明**: 
  - BKR-200不属于传统的"审计前/审计后"分类
  - 它是新功能开发过程中发现并修复的漏洞
  - 在81485a9版本中，StrategySupplyERC4626.sol文件不存在
  - 在dfcf463版本中，文件被创建但存在ERC4626标准使用错误
  - 在ce9d853版本中，漏洞被修复
- **漏洞详情**:
  - **漏洞根因**: ERC4626标准理解错误，直接使用shares数量而不是实际资产数量
  - **修复方式**: 添加`convertToAssets()`调用确保资产数量计算正确
  - **影响**: 用户存入和提取的资产数量计算错误，可能导致损失

---

### 7. b-post-mitigation (f99edb1) - 2025年2月
- **版本性质**: 第二轮审计后版本 - **最终修复阶段**
- **安全状态**: 修复了所有已知漏洞，当前最安全版本
- **修复状态**:
  - ✅ **保持所有之前的修复** (BKR-13 到 BKR-208 + CK-209/F11)
  - ✅ **修复第二轮新漏洞**:
    - BKR-157: Vault with support for N Strategies
    - BKR-159: Morpho Supply Strategy
    - BKR-169: Multiple strategies
    - BKR-178: swapper multiple implementations
    - BKR-179: vault router support for aerodrome swaps
    - BKR-195: _deployedAmount not updated on StrategySupplyBase.undeploy, preventing performance fees from being collected - F6
    - BKR-197: decimals conversions There are multiple issues with the decimal conversions between the vault and the strategy - F13
    - BKR-199: Malicious actors can exploit user-approved allowances on VaultRouter to drain their ERC20 tokens - F18
    - BKR-206: VaultBase is not ERC4626 compliant - F3
    - BKR-207: Even when the Vault contract is paused, the rebalance function is not paused - F12
    - BKR-208: The interaction between the router and the ERC4626 vault lacks slippage control - F14
    - BKR-255: Remove ERC20 approve zero (2025-02-05)
    - BKR-256: harvest before change perf (2025-02-05)
    - CK-209/F11: _handleSweepTokens function lacks ability to withdraw native ETH
  - ✅ **修复特殊时间线漏洞**:
    - BKR-200: Users may encounter losses on assets deposited through StrategySupplyERC4626 - F1 (已在6.5节单独处理)
  - ✅ **新增最终修复**:
    - (暂无)

## 漏洞详细信息

### BKR-200 漏洞详情
- **漏洞名称**: Users may encounter losses on assets deposited through StrategySupplyERC4626 - F1
- **发现来源**: 模糊测试 (F1)
- **漏洞存在版本**: dfcf463 (2024-12-04) - 功能引入但存在漏洞
- **漏洞修复版本**: ce9d853 (2025-01-14)
- **特殊说明**: 
  - 在81485a9版本中，StrategySupplyERC4626.sol文件不存在
  - 在dfcf463版本中，文件被创建但存在ERC4626标准理解错误
  - 在ce9d853版本中，漏洞被修复
- **修复内容**: 
  - 添加`convertToAssets()`调用确保资产数量计算正确
  - 修复ERC4626标准使用错误，避免用户资产损失
  - 详细分析报告: `/home/mi/fuck-bakerfi-contracts/BKR/BKR-200.md`

### CK-209/F11 漏洞详情
- **漏洞名称**: The _handleSweepTokens function lacks the ability to withdraw native ETH
- **发现来源**: Cantina 外部审计
- **漏洞存在版本**: b-pre-mitigation 及之前所有版本
- **漏洞修复版本**: b-post-mitigation
- **修复内容**: 
  - 在 VaultRouterMock.sol 中添加了 sweepNative 功能
  - 添加了 test__sweepNative 测试函数
  - 实现了原生 ETH 的提取能力

## 安全编号统计

| 编号类型 | 总数 | 第一轮审计 | 持续开发 | 第二轮审计 | 特殊时间线 | 最终修复 | 外部审计 |
|---------|------|-----------|----------|-----------|------------|----------|----------|
| BKR     | 55   | 27        | 13       | 14        | 1          | 0        | 0        |
| CK      | 1    | 0         | 0        | 1         | 0          | 0        | 1        |
| F       | 1    | 0         | 0        | 1         | 0          | 0        | 1        |

### 详细分布说明：
- **第一轮审计 (2023年10月-2024年6月)**: 27个BKR问题 (BKR-13到BKR-71)
- **持续开发 (2024年7月-11月)**: 13个BKR问题 (BKR-46, BKR-81, BKR-83, BKR-88, BKR-89, BKR-99, BKR-106, BKR-111, BKR-116, BKR-122, BKR-143, BKR-144, BKR-145)
- **第二轮审计 (2024年11月-2025年2月)**: 14个BKR问题 (BKR-157, BKR-159, BKR-169, BKR-178, BKR-179, BKR-195, BKR-197, BKR-199, BKR-206, BKR-207, BKR-208, BKR-255, BKR-256) + 1个CK问题
- **特殊时间线 (2024年12月-2025年1月)**: 1个BKR问题 (BKR-200: ERC4626策略功能开发过程中的漏洞)
- **最终修复 (2025年2月)**: 0个BKR问题

## 版本安全建议

### 🟢 推荐使用的版本
- **b-post-mitigation (f99edb1)**: 最新稳定版本，修复了所有已知安全问题

### 🟡 相对安全的版本
- **c-post-mitigation (6fef399)**: 修复了持续开发阶段发现的13个BKR问题
- **a-post-mitigation (v1.0.0-beta.2)**: 修复了27个BKR问题，第一轮审计修复完成版本

### 🔴 不建议使用的版本
- **zero-tests-version (223faa2)**: 初始版本，无测试覆盖
- **a-pre-mitigation (v1.0.0-alpha.1)**: 包含14个未修复的BKR安全问题
- **c-pre-mitigation (1af20ca)**: 包含13个新发现但未修复的BKR问题
- **b-pre-mitigation (81485a9)**: 包含13个新引入的BKR安全漏洞和1个CK问题

### 📊 测试基准版本
- **漏洞检测基准**: 使用 a-pre-mitigation (v1.0.0-alpha.1) 和 b-pre-mitigation (81485a9) 作为漏洞存在的基准版本
- **修复验证基准**: 使用 a-post-mitigation (v1.0.0-beta.2) 和 b-post-mitigation (f99edb1) 验证漏洞修复效果
- **开发测试基准**: 使用 c-pre-mitigation (1af20ca) 和 c-post-mitigation (6fef399) 版本进行新功能开发和测试