# BakerFi 合约安全编号分析报告

## 版本时间线和安全状态

## 版本信息
- **zero-tests-version**: 223faa2 (初始版本，无测试)
- **a-pre-mitigation**: v1.0.0-alpha.1 (第一轮审计前版本，漏洞存在)
- **a-post-mitigation**: v1.0.0-beta.2 (第一轮审计修复版本)
- **b-pre-mitigation**: 81485a9 (第二轮审计前版本)
- **b-post-mitigation**: f99edb1 (第二轮审计修复版本)

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

### 4. b-pre-mitigation (81485a9) - 2024年11月
- **版本性质**: 第二轮审计前版本 - **新漏洞引入阶段**
- **安全状态**: 
  - ✅ **继承了第一轮的所有修复** (BKR-13 到 BKR-71)
  - ❌ **新引入了4个漏洞**:
    - BKR-46: Hook functions internal
    - BKR-81: Validate contracts on Base Scan  
    - BKR-83: Using prices for swap slippage instead of onchain quoters
    - CK-209/F11: _handleSweepTokens function lacks ability to withdraw native ETH

---

### 5. b-post-mitigation (f99edb1) - 2025年2月
- **版本性质**: 第二轮审计后版本 - **最终修复阶段**
- **安全状态**: 修复了所有已知漏洞，当前最安全版本
- **修复状态**:
  - ✅ **保持第一轮所有修复** (BKR-13 到 BKR-71)
  - ✅ **修复第二轮新漏洞**:
    - BKR-46: Hook functions internal
    - BKR-81: Validate contracts on Base Scan
    - BKR-83: Using prices for swap slippage instead of onchain quoters
    - CK-209/F11: _handleSweepTokens function lacks ability to withdraw native ETH

## 漏洞详细信息

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

| 编号类型 | 总数 | 第一轮 | 第二轮 | 外部审计 |
|---------|------|--------|--------|----------|
| BKR     | 33   | 30     | 3      | 0        |
| CK      | 1    | 0      | 1      | 1        |
| F       | 1    | 0      | 1      | 1        |

## 版本安全建议

### 🟢 推荐使用的版本
- **b-post-mitigation (f99edb1)**: 最新稳定版本，修复了所有已知安全问题

### 🟡 相对安全的版本
- **a-post-mitigation (v1.0.0-beta.2)**: 修复了27个BKR问题，第一轮审计修复完成版本

### 🔴 不建议使用的版本
- **zero-tests-version (223faa2)**: 初始版本，无测试覆盖
- **a-pre-mitigation (v1.0.0-alpha.1)**: 包含14个未修复的BKR安全问题
- **b-pre-mitigation (81485a9)**: 包含新引入的安全漏洞

### 📊 测试基准版本
- **漏洞检测基准**: 使用 a-pre-mitigation (v1.0.0-alpha.1) 和 b-pre-mitigation (81485a9) 作为漏洞存在的基准版本
- **修复验证基准**: 使用 a-post-mitigation (v1.0.0-beta.2) 和 b-post-mitigation (f99edb1) 验证漏洞修复效果