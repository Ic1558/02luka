#!/usr/bin/env node
/**
 * Self-Reflection Engine (Phase 7.1 Full Implementation)
 *
 * Analyzes recent telemetry and memory to generate insights about
 * system performance, patterns, and areas for improvement.
 *
 * Usage:
 *   node agents/reflection/self_review.cjs [--days=7] [--output=report.md]
 *
 * Output:
 *   - Generates markdown report in g/reports/self_review_[timestamp].md
 *   - Records insights as memory entries (kind: 'insight', importance >= 0.65)
 *
 * Phase 7.1: Full implementation with real telemetry parsing, trend detection,
 * p95 metrics, failure analysis, and actionable recommendations.
 */

const fs = require('fs');
const path = require('path');
const { writeArtifacts } = require('../../packages/io/atomicExport.cjs');

if (!process.env.EXPORT_DIRECT) {
  process.env.EXPORT_DIRECT = '1';
}

// Configuration
const REPO_ROOT = process.env.REPO_ROOT || path.resolve(__dirname, '../..');
const REPORTS_DIR = path.join(REPO_ROOT, 'g', 'reports');
const TELEMETRY_DIR = path.join(REPO_ROOT, 'g', 'telemetry');

const REQUIRED_DIRS = [
  path.join(REPO_ROOT, 'g'),
  REPORTS_DIR,
  TELEMETRY_DIR,
  path.join(REPO_ROOT, 'g', 'memory')
];

for (const dir of REQUIRED_DIRS) {
  try {
    fs.mkdirSync(dir, { recursive: true });
  } catch (err) {
    if (err.code !== 'EEXIST') {
      console.warn(`⚠️  Failed to create directory ${dir}: ${err.message}`);
    }
  }
}

// Load dependencies
const memoryModule = require(path.join(REPO_ROOT, 'memory', 'index.cjs'));
const telemetryModule = require(path.join(REPO_ROOT, 'boss-api', 'telemetry.cjs'));

function toArray(value) {
  if (Array.isArray(value)) {
    return value;
  }
  if (value === null || value === undefined) {
    return [];
  }
  return [value].flat().filter(Boolean);
}

// ============================================================================
// Core Reflection Functions (FULL IMPLEMENTATION)
// ============================================================================

/**
 * Analyze recent telemetry runs
 *
 * Phase 7.1: Full implementation - parses real telemetry, computes metrics,
 * detects trends, identifies top failures and slow tasks.
 *
 * @param {number} days - Number of days to analyze
 * @returns {Object} Telemetry analysis summary
 */
function analyzeTelemetry(days = 7) {
  console.log(`📊 Analyzing telemetry for last ${days} days...`);

  try {
    // Read current period
    const currentEntries = telemetryModule.readRange({ days });
    const currentAnalysis = telemetryModule.analyze(currentEntries);

    // Read previous period (for trend comparison)
    const endDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const previousEntries = telemetryModule.readRange({ days, endDate });
    const previousAnalysis = telemetryModule.analyze(previousEntries);

    // Compare trends
    const trends = telemetryModule.compareTrends(currentAnalysis, previousAnalysis);

    // Compute additional insights
    const lowSampleSize = currentAnalysis.totalRuns < 3;
    const recommendations = generateTelemetryRecommendations(currentAnalysis, trends);

    return {
      days,
      lowSampleSize,
      current: currentAnalysis,
      previous: previousAnalysis,
      trends,
      recommendations
    };
  } catch (error) {
    console.error('⚠️  Telemetry analysis failed:', error.message);
    return {
      days,
      lowSampleSize: true,
      current: {
        totalRuns: 0,
        successRate: 0,
        failRate: 0,
        avgDuration: 0,
        p95Duration: 0,
        topFailures: [],
        slowTasks: []
      },
      previous: null,
      trends: { trending: 'insufficient_data' },
      recommendations: ['Unable to analyze telemetry - check logs exist']
    };
  }
}

/**
 * Generate telemetry-based recommendations
 *
 * @param {Object} analysis - Current telemetry analysis
 * @param {Object} trends - Trend comparison
 * @returns {Array<string>} Recommendations
 */
function generateTelemetryRecommendations(analysis, trends) {
  const recs = [];

  // Success rate recommendations
  if (analysis.successRate < 0.8) {
    recs.push(`Success rate is low (${(analysis.successRate * 100).toFixed(1)}%) - investigate top failures`);
  } else if (trends.successRateDelta < -0.1) {
    recs.push(`Success rate declining (${(trends.successRateDelta * 100).toFixed(1)}% drop) - check recent changes`);
  }

  // Duration recommendations
  if (trends.p95DurationPct > 20) {
    recs.push(`p95 duration up ${trends.p95DurationPct.toFixed(0)}% - performance degradation detected`);
  }

  // Flakiness recommendations
  if (analysis.flakiness > 0.2) {
    recs.push(`High flakiness detected (${(analysis.flakiness * 100).toFixed(0)}%) - stabilize flaky tasks`);
  }

  // Top failures
  if (analysis.topFailures.length > 0) {
    const topFailure = analysis.topFailures[0];
    recs.push(`Top failure: '${topFailure.task}' (${topFailure.totalFails} fails) - prioritize fix`);
  }

  // Slow tasks
  if (analysis.slowTasks.length > 0) {
    const slowest = analysis.slowTasks[0];
    if (slowest.p95 > 5000) {
      recs.push(`Slow task: '${slowest.task}' (p95=${Math.round(slowest.p95)}ms) - consider optimization`);
    }
  }

  // Default if all good
  if (recs.length === 0) {
    recs.push('System performance is stable - continue monitoring');
  }

  return recs;
}

/**
 * Query memory for similar past experiences
 *
 * Phase 7.1: Query memories related to system performance, failures, optimizations
 *
 * @param {Object} context - Analysis context from telemetry
 * @returns {Array} Relevant memories
 */
async function queryRelevantMemories(context) {
  console.log(`🧠 Querying memories for context...`);

  try {
    const { analysis, recommendations } = context;

    // Build semantic query from current state
    let query = 'system performance';
    if (analysis && analysis.current) {
      if (analysis.current.topFailures.length > 0) {
        const topTask = analysis.current.topFailures[0].task;
        query = `${topTask} failure optimization`;
      } else if (analysis.current.successRate < 0.9) {
        query = 'improve success rate reliability';
      } else if (analysis.current.p95Duration > 3000) {
        query = 'reduce duration optimize performance';
      }
    }

    // Query memory for relevant solutions and insights
    const solutionMemories = toArray(await memoryModule.recall({
      query,
      kind: 'solution',
      topK: 3
    }));

    const insightMemories = toArray(await memoryModule.recall({
      query,
      kind: 'insight',
      topK: 2
    }));

    const allMemories = [...solutionMemories, ...insightMemories]
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, 5);

    return allMemories.map(m => ({
      id: m.id,
      kind: m.kind,
      text: m.text,
      similarity: m.similarity,
      importance: m.importance
    }));
  } catch (error) {
    console.error('⚠️  Memory query failed:', error.message);
    return [];
  }
}

/**
 * Generate insights from analysis
 *
 * Phase 7.1: Create data-driven insights with confidence scores
 *
 * @param {Object} telemetryAnalysis - Telemetry analysis results
 * @param {Array} memories - Relevant memories
 * @returns {Array} Generated insights
 */
function generateInsights(telemetryAnalysis, memories) {
  console.log(`💡 Generating insights...`);

  const insights = [];
  const { current, trends, lowSampleSize } = telemetryAnalysis;

  // Insight 1: Overall health assessment
  if (!lowSampleSize) {
    const healthScore = current.successRate;
    let healthText = '';
    let confidence = 0.8;

    if (healthScore >= 0.95) {
      healthText = `System health excellent (${(healthScore * 100).toFixed(1)}% success rate over ${telemetryAnalysis.days}d)`;
      confidence = 0.9;
    } else if (healthScore >= 0.85) {
      healthText = `System health good (${(healthScore * 100).toFixed(1)}% success rate over ${telemetryAnalysis.days}d)`;
      confidence = 0.85;
    } else if (healthScore >= 0.7) {
      healthText = `System health fair (${(healthScore * 100).toFixed(1)}% success rate over ${telemetryAnalysis.days}d) - improvement needed`;
      confidence = 0.75;
    } else {
      healthText = `System health poor (${(healthScore * 100).toFixed(1)}% success rate over ${telemetryAnalysis.days}d) - urgent attention required`;
      confidence = 0.9;
    }

    insights.push({
      type: 'observation',
      text: healthText,
      confidence,
      actionable: healthScore < 0.85,
      meta: {
        successRate: healthScore,
        totalRuns: current.totalRuns,
        windowDays: telemetryAnalysis.days
      }
    });
  }

  // Insight 2: Trend detection
  if (trends && trends.trending !== 'insufficient_data') {
    let trendText = '';
    let confidence = 0.75;
    let actionable = false;

    if (trends.trending === 'improving') {
      trendText = `Positive trend detected (success rate ${trends.successRateDelta > 0 ? '+' : ''}${(trends.successRateDelta * 100).toFixed(1)}% vs previous period)`;
      confidence = 0.8;
    } else if (trends.trending === 'declining') {
      trendText = `Declining trend detected (success rate ${(trends.successRateDelta * 100).toFixed(1)}% vs previous period)`;
      confidence = 0.85;
      actionable = true;
    } else {
      trendText = 'Performance stable compared to previous period';
      confidence = 0.7;
    }

    // Add p95 duration context
    if (trends.p95DurationPct && Math.abs(trends.p95DurationPct) > 10) {
      trendText += `. p95 duration ${trends.p95DurationPct > 0 ? '+' : ''}${trends.p95DurationPct.toFixed(0)}%`;
      if (trends.p95DurationPct > 15) {
        actionable = true;
        confidence = Math.max(confidence, 0.8);
      }
    }

    insights.push({
      type: 'trend',
      text: trendText,
      confidence,
      actionable,
      meta: {
        trending: trends.trending,
        successRateDelta: trends.successRateDelta,
        p95DurationDelta: trends.p95DurationDelta,
        p95DurationPct: trends.p95DurationPct
      }
    });
  }

  // Insight 3: Failure pattern
  if (current.topFailures && current.topFailures.length > 0) {
    const topFailure = current.topFailures[0];
    const failureText = `Top failure: '${topFailure.task}' failed ${topFailure.totalFails} times (${topFailure.count} runs)`;

    insights.push({
      type: 'failure_pattern',
      text: failureText,
      confidence: 0.9,
      actionable: true,
      action: `Investigate '${topFailure.task}' failures and add retry logic or fix root cause`,
      meta: {
        task: topFailure.task,
        failCount: topFailure.totalFails,
        runCount: topFailure.count
      }
    });
  }

  // Insight 4: Performance bottleneck
  if (current.slowTasks && current.slowTasks.length > 0) {
    const slowest = current.slowTasks[0];
    if (slowest.p95 > 3000) {
      const perfText = `Performance bottleneck: '${slowest.task}' (p95=${Math.round(slowest.p95)}ms, avg=${Math.round(slowest.avg)}ms)`;

      insights.push({
        type: 'performance',
        text: perfText,
        confidence: 0.8,
        actionable: slowest.p95 > 5000,
        action: slowest.p95 > 5000 ? `Optimize '${slowest.task}' - consider caching, parallelization, or timeout adjustments` : undefined,
        meta: {
          task: slowest.task,
          p95: slowest.p95,
          avg: slowest.avg
        }
      });
    }
  }

  // Insight 5: Low sample size warning
  if (lowSampleSize) {
    insights.push({
      type: 'warning',
      text: `Low sample size (${current.totalRuns} runs in ${telemetryAnalysis.days}d) - increase test frequency for better insights`,
      confidence: 0.95,
      actionable: true,
      action: 'Schedule more frequent telemetry runs for accurate trend detection',
      meta: {
        totalRuns: current.totalRuns,
        windowDays: telemetryAnalysis.days
      }
    });
  }

  return insights;
}

/**
 * Generate markdown report
 *
 * Phase 7.1: Enhanced report with all metrics and recommendations
 *
 * @param {Object} analysis - Complete analysis results
 * @returns {Object} Report content and timestamp
 */
function generateReport(analysis) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const now = new Date().toISOString();

  const { telemetry, memories, insights, days } = analysis;
  const { current, previous, trends, lowSampleSize, recommendations } = telemetry;

  // Helper to format duration
  const formatDuration = (ms) => {
    if (ms < 1000) return `${Math.round(ms)}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
  };

  // Helper to format percentage
  const formatPct = (decimal) => `${(decimal * 100).toFixed(1)}%`;

  // Helper to format delta
  const formatDelta = (delta) => {
    const sign = delta >= 0 ? '+' : '';
    return `${sign}${(delta * 100).toFixed(1)}%`;
  };

  const report = `# Self-Review Report

**Generated:** ${now}
**Period:** Last ${days} days
**Status:** ${lowSampleSize ? 'LOW SAMPLE SIZE ⚠️' : 'COMPLETE ✅'}

---

## Summary

**Total Runs:** ${current.totalRuns}
**Success Rate:** ${formatPct(current.successRate)}
**Fail Rate:** ${formatPct(current.failRate)}
**Warn Rate:** ${formatPct(current.warnRate)}
**Total Tests:** ${current.totalTests}

**Performance:**
- Average Duration: ${formatDuration(current.avgDuration)}
- p95 Duration: ${formatDuration(current.p95Duration)}
- p99 Duration: ${formatDuration(current.p99Duration)}

${current.flakiness > 0 ? `**Flakiness Score:** ${formatPct(current.flakiness)}` : ''}

---

## Trends

${trends.trending !== 'insufficient_data' ? `
**Status:** ${trends.trending === 'improving' ? '📈 IMPROVING' : trends.trending === 'declining' ? '📉 DECLINING' : '➡️  STABLE'}

**Comparison with Previous ${days}d:**
- Success Rate: ${formatDelta(trends.successRateDelta)} (was ${formatPct(previous.successRate)})
- Fail Rate: ${formatDelta(trends.failRateDelta)} (was ${formatPct(previous.failRate)})
- p95 Duration: ${formatDelta(trends.p95DurationPct / 100)} (${formatDuration(previous.p95Duration)} → ${formatDuration(current.p95Duration)})
` : `
**Status:** ⚠️  INSUFFICIENT DATA

Not enough data in previous period for trend comparison.
Run more telemetry tasks to enable trend detection.
`}

---

## Top Failures

${current.topFailures.length > 0 ? current.topFailures.map((f, i) =>
  `${i + 1}. **${f.task}**
   - Total Failures: ${f.totalFails}
   - Failed Runs: ${f.count}
   - Failure Rate: ${formatPct(f.totalFails / (current.byTask[f.task]?.pass + current.byTask[f.task]?.warn + current.byTask[f.task]?.fail || 1))}`
).join('\n\n') : '_No failures detected ✅_'}

---

## Slow Tasks (p95 Duration)

${current.slowTasks.length > 0 ? current.slowTasks.map((t, i) =>
  `${i + 1}. **${t.task}**
   - p95: ${formatDuration(t.p95)}
   - Average: ${formatDuration(t.avg)}
   - Runs: ${t.runs}`
).join('\n\n') : '_All tasks performing well ✅_'}

${current.flakyTasks && current.flakyTasks.length > 0 ? `
---

## Flaky Tasks

${current.flakyTasks.map((f, i) =>
  `${i + 1}. **${f.task}**
   - Failure Rate: ${formatPct(f.failureRate)}
   - Runs: ${f.runs}`
).join('\n\n')}
` : ''}

---

## Relevant Memories

${memories.length > 0 ? `Found ${memories.length} relevant memories:

${memories.map((m, i) =>
  `${i + 1}. **[${m.kind || 'memory'}]** ${m.text.slice(0, 120)}${m.text.length > 120 ? '...' : ''}
   - Similarity: ${(m.similarity || 0).toFixed(3)}
   - Importance: ${(m.importance || 0.5).toFixed(2)}`
).join('\n\n')}` : '_No relevant memories found_'}

---

## Insights

${insights.map((insight, i) =>
  `### ${i + 1}. ${insight.type.toUpperCase()}: ${insight.text}

- **Confidence:** ${(insight.confidence * 100).toFixed(0)}%
- **Actionable:** ${insight.actionable ? 'Yes ⚡' : 'No'}
${insight.action ? `- **Action:** ${insight.action}` : ''}`
).join('\n\n')}

---

## Recommended Actions

${recommendations.map((rec, i) => `${i + 1}. ${rec}`).join('\n')}

---

## Task Breakdown

${Object.entries(current.byTask).length > 0 ? `
| Task | Runs | Pass | Warn | Fail | Success % | Avg Duration |
|------|------|------|------|------|-----------|--------------|
${Object.entries(current.byTask).map(([task, stats]) =>
  `| ${task} | ${stats.runs} | ${stats.pass} | ${stats.warn} | ${stats.fail} | ${formatPct(stats.successRate)} | ${formatDuration(stats.avgDuration)} |`
).join('\n')}
` : '_No task data available_'}

---

**Report Generated:** ${now}
**Next Review:** Recommended in 7 days
**Automation:** Run \`bash scripts/run_self_review.sh --days 7\` weekly
`;

  return { content: report, timestamp };
}

/**
 * Record insights as memories
 *
 * Phase 7.1: Record high-confidence insights (>= 0.65) as memories
 *
 * @param {Array} insights - Generated insights
 */
async function recordInsights(insights) {
  console.log(`💾 Recording ${insights.length} insights as memories...`);

  let recorded = 0;
  for (const insight of insights) {
    if (insight.confidence >= 0.65) {
      try {
        await memoryModule.remember({
          kind: 'insight',
          text: `[Self-Review] ${insight.text}`,
          meta: {
            confidence: insight.confidence,
            actionable: insight.actionable,
            generatedBy: 'self_review.cjs',
            type: insight.type,
            ...insight.meta
          },
          importance: Math.min(1.0, 0.5 + insight.confidence * 0.5) // Scale to 0.5-1.0
        });
        recorded++;
      } catch (error) {
        console.error('⚠️  Failed to record insight:', error.message);
      }
    }
  }

  console.log(`✅ Recorded ${recorded}/${insights.length} high-confidence insights`);
}

// ============================================================================
// Main Execution
// ============================================================================

async function main() {
  console.log('=== Self-Review Engine (Phase 7.1 Full Implementation) ===\n');

  // Parse command-line arguments
  const args = process.argv.slice(2);
  const daysArg = args.find(a => a.startsWith('--days='));
  const outputArg = args.find(a => a.startsWith('--output='));

  const days = daysArg ? parseInt(daysArg.split('=')[1], 10) : 7;
  const customOutput = outputArg ? outputArg.split('=')[1] : null;

  console.log(`📅 Analyzing last ${days} days...\n`);

  // Run analysis
  const telemetryAnalysis = analyzeTelemetry(days);
  const relevantMemories = await queryRelevantMemories({ analysis: telemetryAnalysis });
  const insights = generateInsights(telemetryAnalysis, relevantMemories);

  // Generate report
  const { content: report, timestamp } = generateReport({
    days,
    telemetry: telemetryAnalysis,
    memories: relevantMemories,
    insights
  });

  // Save report
  const reportPath = customOutput ||
    path.join(REPORTS_DIR, `self_review_${timestamp}.md`);

  await writeArtifacts({
    targetDir: path.dirname(reportPath),
    artifacts: [{ name: path.basename(reportPath), data: report }],
    log: { log: (msg) => console.log(msg) } // Show progress for reports
  });
  console.log(`\n✅ Report saved: ${reportPath}`);

  // Record insights
  await recordInsights(insights);

  // Summary
  console.log('\n=== Self-Review Complete ===');
  console.log(`Period: ${days} days`);
  console.log(`Total Runs: ${telemetryAnalysis.current.totalRuns}`);
  console.log(`Success Rate: ${(telemetryAnalysis.current.successRate * 100).toFixed(1)}%`);
  console.log(`Insights Generated: ${insights.length}`);
  console.log(`High-Confidence Insights: ${insights.filter(i => i.confidence >= 0.65).length}`);
  console.log(`Trend: ${telemetryAnalysis.trends.trending}`);
}

// Run if executed directly
if (require.main === module) {
  main().catch(err => {
    console.error('Error:', err.message);
    console.error(err.stack);
    process.exit(1);
  });
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  analyzeTelemetry,
  queryRelevantMemories,
  generateInsights,
  generateReport,
  recordInsights
};
