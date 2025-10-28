#!/usr/bin/env node
/**
 * Circuit Breaker Pattern Implementation
 * Prevents cascading failures by opening circuit after threshold failures
 * 
 * States:
 * - CLOSED: Normal operation, requests pass through
 * - OPEN: Circuit tripped, fast-fail without trying
 * - HALF_OPEN: Testing if service recovered
 */

const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(process.env.HOME, 'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo/g/state/circuit_breakers.json');

class CircuitBreaker {
  constructor(name, options = {}) {
    this.name = name;
    this.failureThreshold = options.failureThreshold || 5;
    this.successThreshold = options.successThreshold || 2;
    this.timeout = options.timeout || 60000; // 1 minute
    this.state = 'CLOSED';
    this.failures = 0;
    this.successes = 0;
    this.nextAttempt = Date.now();
    
    this.loadState();
  }

  loadState() {
    try {
      if (fs.existsSync(STATE_FILE)) {
        const allStates = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
        if (allStates[this.name]) {
          Object.assign(this, allStates[this.name]);
        }
      }
    } catch (err) {
      // Ignore load errors, start fresh
    }
  }

  saveState() {
    try {
      const dir = path.dirname(STATE_FILE);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      
      let allStates = {};
      if (fs.existsSync(STATE_FILE)) {
        allStates = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
      }
      
      allStates[this.name] = {
        state: this.state,
        failures: this.failures,
        successes: this.successes,
        nextAttempt: this.nextAttempt,
        lastUpdate: new Date().toISOString()
      };
      
      fs.writeFileSync(STATE_FILE, JSON.stringify(allStates, null, 2));
    } catch (err) {
      console.error(`Circuit breaker save failed: ${err.message}`);
    }
  }

  async call(fn) {
    // Check if circuit is OPEN
    if (this.state === 'OPEN') {
      if (Date.now() < this.nextAttempt) {
        throw new Error(`Circuit breaker OPEN for ${this.name}`);
      }
      // Timeout elapsed, try HALF_OPEN
      this.state = 'HALF_OPEN';
      this.saveState();
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (err) {
      this.onFailure();
      throw err;
    }
  }

  onSuccess() {
    this.failures = 0;
    
    if (this.state === 'HALF_OPEN') {
      this.successes++;
      if (this.successes >= this.successThreshold) {
        this.state = 'CLOSED';
        this.successes = 0;
        console.log(`[CircuitBreaker] ${this.name}: HALF_OPEN → CLOSED (recovered)`);
      }
    }
    
    this.saveState();
  }

  onFailure() {
    this.failures++;
    this.successes = 0;
    
    if (this.failures >= this.failureThreshold) {
      this.state = 'OPEN';
      this.nextAttempt = Date.now() + this.timeout;
      console.log(`[CircuitBreaker] ${this.name}: Circuit OPEN (${this.failures} failures)`);
    }
    
    this.saveState();
  }

  getState() {
    return {
      name: this.name,
      state: this.state,
      failures: this.failures,
      successes: this.successes,
      nextAttempt: this.nextAttempt
    };
  }

  reset() {
    this.state = 'CLOSED';
    this.failures = 0;
    this.successes = 0;
    this.nextAttempt = Date.now();
    this.saveState();
  }
}

module.exports = CircuitBreaker;
