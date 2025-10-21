#!/usr/bin/env node
/**
 * CLS Performance Evaluator
 * Calculates weighted performance scores for CLS agent
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');

class CLSEvaluator {
  constructor(dbPath = 'knowledge/02luka.db') {
    this.db = new sqlite3.Database(dbPath);
    this.weights = {
      reasoning_speed: 0.1,
      memory_utilization: 0.1,
      learning_rate: 0.1,
      decision_quality: 0.1,
      safety: 0.2,
      integration: 0.2,
      self_reflection: 0.2
    };
  }

  /**
   * Calculate overall CLS performance score
   * @param {Object} metrics - Raw performance metrics
   * @returns {number} Overall score (0-100)
   */
  calculateClsScore(metrics) {
    const {
      reasoning_speed = 0,
      memory_utilization = 0,
      learning_rate = 0,
      decision_quality = 0,
      error_rate = 0,
      risk_detection = 0,
      cursor_sync = 0,
      gg_coordination = 0,
      mary_scheduling = 0,
      meta_cognition = 0,
      pattern_recognition = 0
    } = metrics;

    // Cognitive efficiency (40% weight)
    const cognitiveScore = (
      reasoning_speed +
      memory_utilization +
      learning_rate +
      decision_quality
    ) / 4;

    // Safety metrics (20% weight)
    const safetyScore = (error_rate + risk_detection) / 2;

    // Integration performance (20% weight)
    const integrationScore = (
      cursor_sync +
      gg_coordination +
      mary_scheduling
    ) / 3;

    // Self-reflection (20% weight)
    const reflectionScore = (
      meta_cognition +
      pattern_recognition
    ) / 2;

    // Weighted overall score
    const weightedScore = 
      (cognitiveScore * 0.4) +
      (safetyScore * 0.2) +
      (integrationScore * 0.2) +
      (reflectionScore * 0.2);

    return Math.min(100, Math.round(weightedScore * 100));
  }

  /**
   * Insert performance metrics into database
   * @param {Object} metrics - Performance metrics
   * @param {string} timestamp - ISO timestamp
   */
  async insertMetrics(metrics, timestamp = new Date().toISOString()) {
    const overallScore = this.calculateClsScore(metrics);
    
    const sql = `
      INSERT INTO cls_metrics (
        timestamp, reasoning_speed, memory_utilization, learning_rate,
        decision_quality, error_rate, audit_compliance, design_adherence,
        risk_detection, cursor_sync, gg_coordination, mary_scheduling,
        kb_update, telemetry_analysis, pattern_recognition, adaptation_speed,
        meta_cognition, overall_score
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const values = [
      timestamp,
      metrics.reasoning_speed || 0,
      metrics.memory_utilization || 0,
      metrics.learning_rate || 0,
      metrics.decision_quality || 0,
      metrics.error_rate || 0,
      metrics.audit_compliance || 0,
      metrics.design_adherence || 0,
      metrics.risk_detection || 0,
      metrics.cursor_sync || 0,
      metrics.gg_coordination || 0,
      metrics.mary_scheduling || 0,
      metrics.kb_update || 0,
      metrics.telemetry_analysis || 0,
      metrics.pattern_recognition || 0,
      metrics.adaptation_speed || 0,
      metrics.meta_cognition || 0,
      overallScore
    ];

    return new Promise((resolve, reject) => {
      this.db.run(sql, values, function(err) {
        if (err) reject(err);
        else resolve({ id: this.lastID, score: overallScore });
      });
    });
  }

  /**
   * Get performance trends for the last N days
   * @param {number} days - Number of days to analyze
   * @returns {Promise<Array>} Performance trend data
   */
  async getPerformanceTrends(days = 7) {
    return new Promise((resolve, reject) => {
      const sql = `
        SELECT 
          DATE(timestamp) as date,
          AVG(overall_score) as avg_score,
          AVG(reasoning_speed) as avg_reasoning,
          AVG(memory_utilization) as avg_memory,
          AVG(decision_quality) as avg_decision,
          COUNT(*) as evaluation_count
        FROM cls_metrics 
        WHERE timestamp >= date('now', '-${days} days')
        GROUP BY DATE(timestamp)
        ORDER BY date DESC
      `;

      this.db.all(sql, (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
  }

  /**
   * Generate performance summary for GG/Mary
   * @param {number} days - Days to analyze
   * @returns {Promise<Object>} Performance summary
   */
  async generateSummary(days = 7) {
    const trends = await this.getPerformanceTrends(days);
    const latest = trends[0];
    
    return {
      period: `${days} days`,
      overall_score: latest?.avg_score || 0,
      strengths: this.identifyStrengths(latest),
      weaknesses: this.identifyWeaknesses(latest),
      recommendations: this.generateRecommendations(latest)
    };
  }

  identifyStrengths(data) {
    const strengths = [];
    if (data?.avg_reasoning > 0.8) strengths.push("Rapid reasoning");
    if (data?.avg_decision > 0.8) strengths.push("High decision quality");
    if (data?.avg_memory > 0.8) strengths.push("Efficient memory utilization");
    return strengths;
  }

  identifyWeaknesses(data) {
    const weaknesses = [];
    if (data?.avg_reasoning < 0.6) weaknesses.push("Slow reasoning speed");
    if (data?.avg_decision < 0.6) weaknesses.push("Decision quality issues");
    if (data?.avg_memory < 0.6) weaknesses.push("Memory utilization problems");
    return weaknesses;
  }

  generateRecommendations(data) {
    const recommendations = [];
    if (data?.avg_reasoning < 0.7) {
      recommendations.push("Optimize reasoning algorithms");
    }
    if (data?.avg_memory < 0.7) {
      recommendations.push("Improve memory management");
    }
    return recommendations;
  }

  close() {
    this.db.close();
  }
}

// CLI interface
if (require.main === module) {
  const evaluator = new CLSEvaluator();
  
  const command = process.argv[2];
  const days = parseInt(process.argv[3]) || 7;
  
  switch (command) {
    case '--calculate':
      const metrics = JSON.parse(process.argv[4] || '{}');
      const score = evaluator.calculateClsScore(metrics);
      console.log(`CLS Score: ${score}`);
      break;
      
    case '--summary':
      evaluator.generateSummary(days).then(summary => {
        console.log(JSON.stringify(summary, null, 2));
        evaluator.close();
      });
      break;
      
    default:
      console.log('Usage: node knowledge/evaluator.cjs [--calculate|--summary] [days]');
  }
}

module.exports = CLSEvaluator;
