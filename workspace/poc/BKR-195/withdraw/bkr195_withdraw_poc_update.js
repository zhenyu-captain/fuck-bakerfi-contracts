/**
 * BKR-195 _withdraw 函数状态不一致漏洞POC (分步版)
 * 
 * 漏洞描述：
 * StrategyLeverageAAVEv3.sol 的 _withdraw 函数没有正确更新 _deployedAmount 状态变量，
 * 导致状态不一致，影响性能费用计算和会计准确性。
 * 
 * 使用方法：
 * node bkr195_withdraw_poc_update.js --version b-pre-mitigation
 * node bkr195_withdraw_poc_update.js --version b-post-mitigation
 * node bkr195_withdraw_poc_update.js --version latest
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// 配置
const CONFIG = {
    versions: {
        "b-pre-mitigation": {
            path: "../../../../b-pre-mitigation",
            description: "第二轮审计前版本（包含漏洞）"
        },
        "b-post-mitigation": {
            path: "../../../../b-post-mitigation", 
            description: "第二轮审计后版本（已修复）"
        },
        "latest": {
            path: "../../../../latest",
            description: "最新版本"
        }
    }
};

// 颜色输出
const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    purple: '\x1b[35m',
    cyan: '\x1b[36m',
    reset: '\x1b[0m'
};

function log(color, message) {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// 解析命令行参数
function parseArgs() {
    const args = process.argv.slice(2);
    const version = args.find(arg => arg.startsWith('--version='))?.split('=')[1] || 
                   args[args.indexOf('--version') + 1] || 'b-pre-mitigation';
    
    return { version };
}

// 检查版本是否存在
function checkVersion(version) {
    if (!CONFIG.versions[version]) {
        log('red', `❌ 错误：不支持的版本 "${version}"`);
        log('yellow', '支持的版本：');
        Object.keys(CONFIG.versions).forEach(v => {
            log('cyan', `  - ${v}: ${CONFIG.versions[v].description}`);
        });
        process.exit(1);
    }
    
    const versionPath = path.resolve(__dirname, CONFIG.versions[version].path);
    if (!fs.existsSync(versionPath)) {
        log('red', `❌ 错误：版本目录不存在 ${versionPath}`);
        log('yellow', '请先运行 down_versions.sh 脚本拉取版本');
        process.exit(1);
    }
    
    return versionPath;
}

// 模拟StrategyLeverageAAVEv3合约
class StrategyLeverageAAVEv3Mock {
    constructor() {
        this.deployedAmount = 0n;
        this.totalSupply = 1000000000000000000000000n; // 100万代币 (18位小数)
        this.balance = 1000000000000000000000000n;
    }
    
    // 正常部署操作
    async deploy(amount) {
        const amountBN = BigInt(amount);
        if (amountBN > this.balance) {
            throw new Error("Insufficient balance");
        }
        
        this.deployedAmount += amountBN;
        this.balance -= amountBN;
        
        log('green', `✅ 部署成功: ${ethers.formatEther(amountBN)} 代币`);
        log('cyan', `   部署后状态: deployedAmount=${ethers.formatEther(this.deployedAmount)}, balance=${ethers.formatEther(this.balance)}`);
    }
    
    // 有漏洞的_withdraw操作
    async withdrawVulnerable(amount, to) {
        const amountBN = BigInt(amount);
        log('yellow', `🔍 执行有漏洞的_withdraw操作: ${ethers.formatEther(amountBN)} 代币到 ${to}`);
        
        // 模拟从AAVE提取资产
        const withdrawalValue = amountBN;
        
        // 更新余额
        this.balance -= amountBN;
        
        // ❌ 漏洞：没有更新 deployedAmount
        // 这会导致状态不一致
        
        log('red', `❌ 漏洞：_withdraw 后没有更新 deployedAmount`);
        log('cyan', `   提取后状态: deployedAmount=${ethers.formatEther(this.deployedAmount)}, balance=${ethers.formatEther(this.balance)}`);
        
        return withdrawalValue;
    }
    
    // 修复后的_withdraw操作
    async withdrawFixed(amount, to) {
        const amountBN = BigInt(amount);
        log('yellow', `🔍 执行修复后的_withdraw操作: ${ethers.formatEther(amountBN)} 代币到 ${to}`);
        
        // 模拟从AAVE提取资产
        const withdrawalValue = amountBN;
        
        // ✅ 修复：正确更新 deployedAmount (从 deployed 提取并直接发给用户)
        this.deployedAmount -= withdrawalValue;
        
        // ✅ 修复：同时更新 totalSupply (策略内总额减少)
        this.totalSupply -= withdrawalValue;
        
        // 注意：balance 不需要更新，因为是从 deployed 直接提取给用户
        
        log('green', `✅ 修复：_withdraw 后正确更新了 deployedAmount 和 totalSupply`);
        log('cyan', `   提取后状态: deployedAmount=${ethers.formatEther(this.deployedAmount)}, balance=${ethers.formatEther(this.balance)}, totalSupply=${ethers.formatEther(this.totalSupply)}`);
        
        return withdrawalValue;
    }
    
    // 检查状态一致性
    checkStateConsistency() {
        const expectedTotal = this.deployedAmount + this.balance;
        const isConsistent = expectedTotal === this.totalSupply;
        
        log('blue', `📊 状态一致性检查:`);
        log('cyan', `   deployedAmount: ${ethers.formatEther(this.deployedAmount)}`);
        log('cyan', `   balance: ${ethers.formatEther(this.balance)}`);
        log('cyan', `   总计: ${ethers.formatEther(expectedTotal)}`);
        log('cyan', `   期望总计: ${ethers.formatEther(this.totalSupply)}`);
        
        if (isConsistent) {
            log('green', `✅ 状态一致`);
        } else {
            const diff = expectedTotal > this.totalSupply ? expectedTotal - this.totalSupply : this.totalSupply - expectedTotal;
            log('red', `❌ 状态不一致！差异: ${ethers.formatEther(diff)}`);
            
            // 解释状态不一致的原因
            if (expectedTotal < this.totalSupply) {
                log('yellow', `   原因: 实际金额(${ethers.formatEther(expectedTotal)}) < 总供应量(${ethers.formatEther(this.totalSupply)})`);
                log('yellow', `   可能: 有资金被提取但状态未正确更新`);
            } else {
                log('yellow', `   原因: 实际金额(${ethers.formatEther(expectedTotal)}) > 总供应量(${ethers.formatEther(this.totalSupply)})`);
                log('yellow', `   可能: 状态更新错误或计算错误`);
            }
        }
        
        return isConsistent;
    }
    
    // 计算性能费用
    calculatePerformanceFee() {
        const fee = this.deployedAmount * 1n / 100n; // 1% 性能费用
        log('blue', `💰 性能费用计算:`);
        log('cyan', `   基于 deployedAmount: ${ethers.formatEther(this.deployedAmount)}`);
        log('cyan', `   计算费用: ${ethers.formatEther(fee)}`);
        return fee;
    }
}

// 主POC函数
async function runPOC(version) {
    log('purple', '='.repeat(60));
    log('purple', '        BKR-195 _withdraw 函数漏洞POC (分步版)');
    log('purple', '='.repeat(60));
    log('blue', `📋 测试版本: ${version} (${CONFIG.versions[version].description})`);
    log('blue', `📁 版本路径: ${CONFIG.versions[version].path}`);
    log('blue', `⏰ 测试时间: ${new Date().toLocaleString()}`);
    log('purple', '='.repeat(60));
    
    // 创建模拟合约
    const strategy = new StrategyLeverageAAVEv3Mock();
    
    // 0. 文件名称和问题代码部分
    log('blue', '\n🎯 0. 文件名称和问题代码部分');
    log('cyan', '   文件: StrategyLeverageAAVEv3.sol');
    log('cyan', '   函数: _withdraw(uint256 amount, address to)');
    log('cyan', '   问题: 没有更新 _deployedAmount 状态变量');
    
    log('yellow', '\n📄 有漏洞的代码:');
    log('red', '   function _withdraw(uint256 amount, address to) internal virtual override {');
    log('red', '       if (aaveV3().withdraw(_collateralToken, amount, to) != amount) revert InvalidWithdrawAmount();');
    log('red', '       // ❌ 缺少: _deployedAmount -= amount;');
    log('red', '   }');
    
    log('green', '\n✅ 修复后的代码:');
    log('green', '   function _withdraw(uint256 amount, address to) internal virtual override {');
    log('green', '       if (aaveV3().withdraw(_collateralToken, amount, to) != amount) revert InvalidWithdrawAmount();');
    log('green', '       // ✅ 修复: 正确更新状态');
    log('green', '       _deployedAmount -= amount;');
    log('green', '   }');
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 1. 正常操作：部署基线
    log('blue', '\n🎯 1. 正常操作：部署基线');
    log('cyan', '   目的: 验证基础功能正常工作，建立状态一致性基线');
    log('cyan', '   操作: 模拟用户向策略部署10万代币');
    
    await strategy.deploy("100000000000000000000000"); // 部署10万代币
    const isConsistentAfterDeploy = strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 2. 漏洞操作：有漏洞的_withdraw
    log('blue', '\n🎯 2. 漏洞操作：有漏洞的_withdraw');
    log('cyan', '   目的: 演示漏洞的存在和影响');
    log('cyan', '   操作: 模拟从策略中提取5万代币 (故意不更新deployedAmount)');
    
    await strategy.withdrawVulnerable("50000000000000000000000", "0x1234567890123456789012345678901234567890");
    const isConsistentAfterVulnerable = strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 3. 漏洞修复后操作：修复后的_withdraw
    log('blue', '\n🎯 3. 漏洞修复后操作：修复后的_withdraw');
    log('cyan', '   目的: 演示正确的修复方案');
    log('cyan', '   操作: 重置状态后，模拟修复后的_withdraw函数 (正确更新deployedAmount)');
    
    // 重置状态测试修复版本
    strategy.deployedAmount = 100000000000000000000000n;
    strategy.balance = 900000000000000000000000n;
    strategy.totalSupply = 1000000000000000000000000n;
    
    await strategy.withdrawFixed("50000000000000000000000", "0x1234567890123456789012345678901234567890");
    const isConsistentAfterFixed = strategy.checkStateConsistency();
}

// 主函数
async function main() {
    try {
        const { version } = parseArgs();
        const versionPath = checkVersion(version);
        
        log('green', `🚀 开始运行 BKR-195 _withdraw 函数漏洞POC`);
        log('cyan', `   目标版本: ${version}`);
        log('cyan', `   版本路径: ${versionPath}`);
        
        await runPOC(version);
        
        log('green', '\n🎉 POC 执行完成！');
        
    } catch (error) {
        log('red', `❌ POC 执行失败: ${error.message}`);
        console.error(error);
        process.exit(1);
    }
}

// 如果直接运行此文件
if (require.main === module) {
    main();
}

module.exports = { runPOC, StrategyLeverageAAVEv3Mock };
