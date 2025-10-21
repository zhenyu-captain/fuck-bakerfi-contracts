/**
 * BKR-195 外部攻击面演示
 * 
 * 基于潜在外部攻击面.md 中描述的3类攻击场景：
 * A. 重复/超额赎回（最典型、最危险）
 * B. 绩效费/pricePerShare 操作被操纵（较隐蔽但高影响）
 * C. 清算/借贷阈值操纵（间接链式风险）
 * 
 * 使用方法：
 * node attackdemo.js --attack A
 * node attackdemo.js --attack B
 * node attackdemo.js --attack C
 * node attackdemo.js --attack all
 */

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

// 配置
const CONFIG = {
    attacks: {
        "A": {
            name: "重复/超额赎回攻击",
            description: "利用_deployedAmount未更新进行重复提取"
        },
        "B": {
            name: "绩效费操纵攻击", 
            description: "利用错误的_deployedAmount计算费用"
        },
        "C": {
            name: "清算阈值操纵攻击",
            description: "利用错误的_deployedAmount影响安全阈值"
        },
        "all": {
            name: "所有攻击场景",
            description: "依次演示所有攻击类型"
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
    const attack = args.find(arg => arg.startsWith('--attack='))?.split('=')[1] || 
                   args[args.indexOf('--attack') + 1] || 'A';
    
    return { attack };
}

// 检查攻击类型
function checkAttackType(attack) {
    if (!CONFIG.attacks[attack]) {
        log('red', `❌ 错误：不支持的攻击类型 "${attack}"`);
        log('yellow', '支持的攻击类型：');
        Object.keys(CONFIG.attacks).forEach(a => {
            log('cyan', `  - ${a}: ${CONFIG.attacks[a].name}`);
        });
        process.exit(1);
    }
    
    return attack;
}

// 模拟StrategyLeverageAAVEv3合约（包含攻击场景）
class StrategyLeverageAAVEv3AttackMock {
    constructor() {
        this.deployedAmount = 0n;
        this.totalSupply = 1000000000000000000000000n; // 100万代币 (18位小数)
        this.balance = 1000000000000000000000000n;
        this.attackerBalance = 0n; // 攻击者余额
        this.performanceFee = 0n; // 累计性能费用
        this.pricePerShare = 1000000000000000000n; // 1.0 (18位小数)
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
        
        // ✅ 修复：正确更新 deployedAmount
        this.deployedAmount -= withdrawalValue;
        this.totalSupply -= withdrawalValue;
        
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
    
    // 计算pricePerShare
    calculatePricePerShare() {
        if (this.totalSupply === 0n) return 0n;
        const price = (this.deployedAmount + this.balance) * 1000000000000000000n / this.totalSupply;
        log('blue', `📈 PricePerShare 计算:`);
        log('cyan', `   基于 deployedAmount: ${ethers.formatEther(this.deployedAmount)}`);
        log('cyan', `   基于 balance: ${ethers.formatEther(this.balance)}`);
        log('cyan', `   基于 totalSupply: ${ethers.formatEther(this.totalSupply)}`);
        log('cyan', `   计算价格: ${ethers.formatEther(price)}`);
        return price;
    }
    
    // 检查清算阈值
    checkLiquidationThreshold() {
        const collateralRatio = this.deployedAmount * 100n / this.totalSupply;
        const isSafe = collateralRatio >= 80n; // 80% 安全阈值
        
        log('blue', `🛡️ 清算阈值检查:`);
        log('cyan', `   抵押率: ${collateralRatio}%`);
        log('cyan', `   安全阈值: 80%`);
        
        if (isSafe) {
            log('green', `✅ 抵押率安全`);
        } else {
            log('red', `❌ 抵押率不足，可能触发清算`);
        }
        
        return isSafe;
    }
}

// 攻击场景A：重复/超额赎回
async function attackA() {
    log('purple', '='.repeat(60));
    log('purple', '          攻击场景A：重复/超额赎回攻击');
    log('purple', '='.repeat(60));
    
    const strategy = new StrategyLeverageAAVEv3AttackMock();
    const attacker = "0xAttacker123456789012345678901234567890";
    
    // 初始状态
    log('blue', '\n🎯 初始状态设置');
    await strategy.deploy("100000000000000000000000"); // 部署10万代币
    strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 第一次攻击：提取5万代币
    log('blue', '\n🎯 第一次攻击：提取5万代币');
    log('cyan', '   攻击者调用 withdraw(50000, attacker)');
    await strategy.withdrawVulnerable("50000000000000000000000", attacker);
    strategy.attackerBalance += 50000000000000000000000n;
    log('red', `   攻击者余额: ${ethers.formatEther(strategy.attackerBalance)}`);
    strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 第二次攻击：再次提取5万代币（利用未更新的deployedAmount）
    log('blue', '\n🎯 第二次攻击：再次提取5万代币');
    log('cyan', '   攻击者再次调用 withdraw(50000, attacker)');
    log('red', '   ❌ 由于deployedAmount未更新，系统认为攻击者仍有10万可提取额度');
    await strategy.withdrawVulnerable("50000000000000000000000", attacker);
    strategy.attackerBalance += 50000000000000000000000n;
    log('red', `   攻击者余额: ${ethers.formatEther(strategy.attackerBalance)}`);
    strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 第三次攻击：继续提取剩余资金
    log('blue', '\n🎯 第三次攻击：提取剩余资金');
    log('cyan', '   攻击者继续调用 withdraw(50000, attacker)');
    await strategy.withdrawVulnerable("50000000000000000000000", attacker);
    strategy.attackerBalance += 50000000000000000000000n;
    log('red', `   攻击者余额: ${ethers.formatEther(strategy.attackerBalance)}`);
    strategy.checkStateConsistency();
    
    // 攻击结果
    log('purple', '\n' + '='.repeat(60));
    log('purple', '                   攻击结果');
    log('purple', '='.repeat(60));
    log('red', `💰 攻击者总共提取: ${ethers.formatEther(strategy.attackerBalance)} 代币`);
    log('red', `💸 策略剩余资金: ${ethers.formatEther(strategy.balance)} 代币`);
    log('red', `📊 攻击成功: 偷走总资产的 ${(Number(strategy.attackerBalance) / Number(1000000000000000000000000n) * 100).toFixed(1)}%`);
}

// 攻击场景B：绩效费操纵
async function attackB() {
    log('purple', '='.repeat(60));
    log('purple', '          攻击场景B：绩效费操纵攻击');
    log('purple', '='.repeat(60));
    
    const strategy = new StrategyLeverageAAVEv3AttackMock();
    
    // 初始状态
    log('blue', '\n🎯 初始状态设置');
    await strategy.deploy("100000000000000000000000"); // 部署10万代币
    strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 攻击：提取资金但deployedAmount未更新
    log('blue', '\n🎯 攻击：提取资金');
    log('cyan', '   攻击者调用 withdraw(50000, attacker)');
    await strategy.withdrawVulnerable("50000000000000000000000", "0xAttacker123456789012345678901234567890");
    strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 错误的绩效费计算
    log('blue', '\n🎯 错误的绩效费计算');
    log('cyan', '   系统基于错误的deployedAmount计算绩效费');
    const wrongFee = strategy.calculatePerformanceFee();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 正确的绩效费计算（基于实际状态）
    log('blue', '\n🎯 正确的绩效费计算');
    log('cyan', '   基于实际deployedAmount计算绩效费');
    const actualDeployedAmount = 50000000000000000000000n; // 实际应该是5万
    const correctFee = actualDeployedAmount * 1n / 100n;
    log('green', `   正确费用: ${ethers.formatEther(correctFee)}`);
    
    // 费用差异
    const feeDifference = wrongFee - correctFee;
    log('red', `💰 费用差异: ${ethers.formatEther(feeDifference)}`);
    log('red', `📊 多收费用比例: ${(Number(feeDifference) / Number(correctFee) * 100).toFixed(1)}%`);
}

// 攻击场景C：清算阈值操纵
async function attackC() {
    log('purple', '='.repeat(60));
    log('purple', '          攻击场景C：清算阈值操纵攻击');
    log('purple', '='.repeat(60));
    
    const strategy = new StrategyLeverageAAVEv3AttackMock();
    
    // 初始状态
    log('blue', '\n🎯 初始状态设置');
    await strategy.deploy("100000000000000000000000"); // 部署10万代币
    strategy.checkStateConsistency();
    strategy.checkLiquidationThreshold();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 攻击：提取资金但deployedAmount未更新
    log('blue', '\n🎯 攻击：提取资金');
    log('cyan', '   攻击者调用 withdraw(50000, attacker)');
    await strategy.withdrawVulnerable("50000000000000000000000", "0xAttacker123456789012345678901234567890");
    strategy.checkStateConsistency();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 错误的清算阈值检查
    log('blue', '\n🎯 错误的清算阈值检查');
    log('cyan', '   系统基于错误的deployedAmount检查清算阈值');
    strategy.checkLiquidationThreshold();
    
    log('purple', '\n' + '-'.repeat(50));
    
    // 正确的清算阈值检查（基于实际状态）
    log('blue', '\n🎯 正确的清算阈值检查');
    log('cyan', '   基于实际deployedAmount检查清算阈值');
    const actualDeployedAmount = 50000000000000000000000n; // 实际应该是5万
    const actualCollateralRatio = actualDeployedAmount * 100n / strategy.totalSupply;
    log('green', `   实际抵押率: ${actualCollateralRatio}%`);
    
    if (actualCollateralRatio < 80n) {
        log('red', `❌ 实际抵押率不足，应该触发清算！`);
        log('red', `💥 系统被攻击者利用，未触发应有的保护机制`);
    } else {
        log('green', `✅ 实际抵押率仍然安全`);
    }
}

// 主函数
async function main() {
    try {
        const { attack } = parseArgs();
        const attackType = checkAttackType(attack);
        
        log('green', `🚀 开始运行 BKR-195 外部攻击面演示`);
        log('cyan', `   攻击类型: ${attackType} (${CONFIG.attacks[attackType].name})`);
        log('cyan', `   描述: ${CONFIG.attacks[attackType].description}`);
        
        if (attackType === 'A' || attackType === 'all') {
            await attackA();
        }
        
        if (attackType === 'B' || attackType === 'all') {
            if (attackType === 'all') {
                log('purple', '\n' + '='.repeat(80));
            }
            await attackB();
        }
        
        if (attackType === 'C' || attackType === 'all') {
            if (attackType === 'all') {
                log('purple', '\n' + '='.repeat(80));
            }
            await attackC();
        }
        
        log('green', '\n🎉 攻击演示完成！');
        
    } catch (error) {
        log('red', `❌ 攻击演示失败: ${error.message}`);
        console.error(error);
        process.exit(1);
    }
}

// 如果直接运行此文件
if (require.main === module) {
    main();
}

module.exports = { attackA, attackB, attackC, StrategyLeverageAAVEv3AttackMock };
