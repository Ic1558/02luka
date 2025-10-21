// packages/skills/resolveShell.js
const fs = require('fs');

function exists(p) { 
    try { 
        return p && fs.existsSync(p); 
    } catch { 
        return false; 
    } 
}

// Resolution order (left→right). You can override with env CLS_SHELL.
const CANDIDATES = [
    process.env.CLS_SHELL,     // explicit override
    process.env.SHELL,         // user shell
    '/bin/bash',
    '/usr/bin/bash',
    '/bin/zsh',
    '/usr/bin/zsh',
    '/bin/sh'
];

function resolveShell() {
    for (const p of CANDIDATES) {
        if (exists(p)) return p;
    }
    // Last resort: rely on system PATH
    return 'sh';
}

module.exports = { resolveShell };