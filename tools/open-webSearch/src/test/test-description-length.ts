import { searchBing } from '../engines/bing/index.js';
import { SearchResult } from '../types.js';
import { config } from '../config.js';

// 与 setupTools.ts 中相同的截断逻辑
function truncateDescriptions(results: SearchResult[], descLimit?: number): SearchResult[] {
    if (!descLimit) return results;
    return results.map(r => ({
        ...r,
        description: r.description.length > descLimit
            ? r.description.slice(0, descLimit) + '...'
            : r.description
    }));
}

async function testDescriptionLength() {
    console.log('🔍 Starting description length truncation test...\n');

    let passed = 0;
    let failed = 0;

    function assert(condition: boolean, message: string) {
        if (condition) {
            console.log(`  ✅ ${message}`);
            passed++;
        } else {
            console.error(`  ❌ ${message}`);
            failed++;
        }
    }

    // ===== 单元测试：截断逻辑 =====
    console.log('--- 单元测试：截断逻辑 ---');

    const mockResults: SearchResult[] = [
        { title: 'A', url: 'http://a.com', description: 'Short', source: 'bing', engine: 'bing' },
        { title: 'B', url: 'http://b.com', description: 'This is a much longer description that exceeds the limit', source: 'bing', engine: 'bing' },
        { title: 'C', url: 'http://c.com', description: '', source: 'bing', engine: 'bing' },
    ];

    // 测试1：无限制时不截断
    const noLimit = truncateDescriptions(mockResults, undefined);
    assert(noLimit[0].description === 'Short', '无限制时短描述不变');
    assert(noLimit[1].description === 'This is a much longer description that exceeds the limit', '无限制时长描述不变');
    assert(noLimit[2].description === '', '无限制时空描述不变');

    // 测试2：设置限制后截断
    const limited = truncateDescriptions(mockResults, 10);
    assert(limited[0].description === 'Short', '短于限制的描述不变');
    assert(limited[1].description === 'This is a ...', '超过限制的描述被截断并加省略号');
    assert(limited[1].description.length === 13, `截断后长度为 10+3=13 (实际: ${limited[1].description.length})`);
    assert(limited[2].description === '', '空描述保持为空');

    // 测试3：限制恰好等于描述长度时不截断
    const exact = truncateDescriptions(mockResults, 5);
    assert(exact[0].description === 'Short', '长度恰好等于限制时不截断');

    // 测试4：限制为1
    const one = truncateDescriptions(mockResults, 1);
    assert(one[1].description === 'T...', '限制为1时只保留1个字符加省略号');

    // 测试5：全局配置默认值
    console.log('\n--- 全局配置检查 ---');
    assert(config.maxDescriptionLength === undefined, `默认全局配置为 undefined (实际: ${config.maxDescriptionLength})`);

    // ===== 集成测试：实际搜索 + 截断 =====
    console.log('\n--- 集成测试：实际搜索 + 截断 ---');
    try {
        const results = await searchBing('typescript', 3);
        assert(results.length > 0, `Bing 搜索返回了 ${results.length} 条结果`);

        const truncated = truncateDescriptions(results, 20);
        for (const r of truncated) {
            const ok = r.description.length <= 23; // 20 + '...'
            assert(ok, `"${r.title}" 描述长度 ${r.description.length} <= 23`);
        }
    } catch (error) {
        console.error(`  ⚠️ 集成测试跳过 (搜索失败): ${error instanceof Error ? error.message : error}`);
    }

    // ===== 结果汇总 =====
    console.log(`\n📊 结果: ${passed} 通过, ${failed} 失败`);
    if (failed > 0) process.exit(1);
}

testDescriptionLength().catch(e => {
    console.error('❌ 测试异常:', e);
    process.exit(1);
});
