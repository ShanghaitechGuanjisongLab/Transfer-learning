/**
 * Bing 搜索结果质量测试。
 *
 * 验证 Bing 搜索能正确理解查询语义，而不是将 "MCP" 等缩写
 * 错误地解读为 "Microsoft Certified Professional" 等无关含义。
 *
 * 背景：cn.bing.com 对直接 URL 导航返回降级的搜索结果，
 * 必须通过搜索框表单提交（带 form=QBLH 参数）才能获得正确结果。
 * 此外，headless 模式下 Bing 搜索框提交返回 0 结果，
 * 必须使用 GUI 模式（窗口隐藏）的浏览器。
 */
import { searchBing } from '../engines/bing/index.js';
import { destroySharedBrowser } from '../engines/shared/browser.js';

const rand = () => Math.random().toString(36).slice(2, 6);

async function testBingSearchQuality() {
    let passed = 0;
    let failed = 0;

    async function assertRelevant(query: string, relevancePattern: RegExp, minRelevant: number) {
        // 追加随机后缀确保每次搜索都是全新查询，避免缓存
        const suffix = rand();
        const fullQuery = `${query} ${suffix}`;
        console.log(`\n🔍 Query: "${fullQuery}"`);

        const results = await searchBing(fullQuery, 10);
        const relevant = results.filter(r => relevancePattern.test(r.title));

        console.log(`   Results: ${results.length}, Relevant: ${relevant.length}/${results.length}`);
        results.slice(0, 5).forEach((r, i) => {
            const mark = relevancePattern.test(r.title) ? '✓' : '✗';
            console.log(`   ${mark} ${i + 1}. ${r.title}`);
        });

        if (relevant.length >= minRelevant) {
            console.log(`   ✅ PASS (>= ${minRelevant} relevant)`);
            passed++;
        } else {
            console.log(`   ❌ FAIL (expected >= ${minRelevant} relevant, got ${relevant.length})`);
            failed++;
        }
    }

    console.log('=== Bing 搜索结果质量测试 ===\n');

    // 测试1: "MCP" 应被理解为 Model Context Protocol，而非 Microsoft Certified Professional
    await assertRelevant(
        'MCP tool rename duplicate tool names proxy wrapper',
        /tool|FastMCP|collision|wrapper|proxy|duplicate|mcp.*server|rename|spring.*ai/i,
        3
    );

    // 测试2: 常规英文技术搜索
    await assertRelevant(
        'TypeScript generic type inference guide',
        /typescript|generic|type|inference|guide/i,
        3
    );

    console.log(`\n=== 结果: ${passed} passed, ${failed} failed ===`);
    if (failed > 0) process.exitCode = 1;
}

testBingSearchQuality()
    .catch(err => { console.error('❌ Test error:', err); process.exitCode = 1; })
    .finally(() => { destroySharedBrowser(); process.exit(); });
