// Main Script - PD17 AI Formwork Calculator
// Coordinates all modules and handles UI interactions

// Global state
const AppState = {
    currentCalculation: null,
    chatHistory: [],
    uploadedFiles: []
};

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 PD17 AI Formwork Calculator initialized');

    // Load last calculation if exists
    loadLastCalculation();

    // Setup event listeners
    setupEventListeners();

    // Check if PDF.js is loaded
    if (typeof pdfjsLib !== 'undefined') {
        pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
    }

    // Welcome message
    showWelcomeMessage();
});

// Setup event listeners
function setupEventListeners() {
    // Enter key in chat input
    const chatInput = document.getElementById('chat-input');
    if (chatInput) {
        chatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
    }

    // Form inputs - auto-save
    const formInputs = document.querySelectorAll('#project-form input');
    formInputs.forEach(input => {
        input.addEventListener('change', () => {
            saveFormData();
        });
    });

    // Prevent form submission
    const form = document.getElementById('project-form');
    if (form) {
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            calculateFormwork();
        });
    }
}

// Load last calculation
function loadLastCalculation() {
    try {
        const lastCalc = localStorage.getItem('lastCalculation');
        if (lastCalc) {
            const results = JSON.parse(lastCalc);
            AppState.currentCalculation = results;

            // Populate form
            if (results.data) {
                populateForm(results.data);
            }

            // Show results
            if (results.costs) {
                Calculations.displayResults(results);
            }

            // Show Gantt chart
            if (results.timeline) {
                updateGanttChart(results.timeline);
            }

            showNotification('โหลดข้อมูลล่าสุด ✓', 'info');
        }
    } catch (error) {
        console.error('Load Error:', error);
    }
}

// Save form data to localStorage
function saveFormData() {
    try {
        const data = getCurrentFormData();
        localStorage.setItem('formData', JSON.stringify(data));
    } catch (error) {
        console.error('Save Form Error:', error);
    }
}

// Show welcome message
function showWelcomeMessage() {
    // Check if first visit
    const hasVisited = localStorage.getItem('hasVisited');

    if (!hasVisited) {
        setTimeout(() => {
            AIService.addMessageToUI('ai', `👋 สวัสดีครับ! ยินดีต้อนรับสู่ PD17 AI Formwork Calculator

ฟีเจอร์หลัก:
• 📄 อัปโหลด PDF/Excel เพื่อแยกข้อมูลอัตโนมัติ
• 🤖 แชทกับ AI เพื่อป้อนข้อมูลด้วยภาษาธรรมชาติ
• 📊 คำนวณแบบหล่อและวิเคราะห์ต้นทุน
• 📈 แสดง Gantt Chart แผนงาน
• 📑 Export รายงาน Excel/PDF

ลองเริ่มต้นด้วยการพิมพ์: "ชั้น 1 มีเสา 40x40 สูง 3.5 เมตร 24 ต้น"
หรืออัปโหลดไฟล์แบบก่อสร้างของคุณ!`);

            localStorage.setItem('hasVisited', 'true');
        }, 1000);
    }
}

// Utility: Show loading overlay
function showLoading(show) {
    const overlay = document.getElementById('loading-overlay');
    if (overlay) {
        if (show) {
            overlay.classList.remove('hidden');
        } else {
            overlay.classList.add('hidden');
        }
    }
}

// Utility: Show notification
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification ${type} fade-in`;

    const icon = type === 'success' ? 'check-circle' :
        type === 'error' ? 'times-circle' :
            type === 'warning' ? 'exclamation-triangle' : 'info-circle';

    notification.innerHTML = `
        <i class="fas fa-${icon} mr-2"></i>
        <span>${message}</span>
    `;

    document.body.appendChild(notification);

    // Auto-remove after 5 seconds
    setTimeout(() => {
        notification.classList.add('slide-out-right');
        setTimeout(() => notification.remove(), 300);
    }, 5000);
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + K: Focus chat input
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        document.getElementById('chat-input').focus();
    }

    // Ctrl/Cmd + Enter: Calculate
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        e.preventDefault();
        calculateFormwork();
    }

    // Ctrl/Cmd + S: Save (Export Excel)
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        exportToExcel();
    }
});

// Error handling
window.addEventListener('error', (event) => {
    console.error('Global Error:', event.error);

    // Log to monitoring service (if available)
    if (window.trackError) {
        window.trackError(event.error);
    }
});

// Unhandled promise rejection
window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled Promise Rejection:', event.reason);
});

// Online/Offline detection
window.addEventListener('online', () => {
    showNotification('กลับมาออนไลน์แล้ว ✓', 'success');
});

window.addEventListener('offline', () => {
    showNotification('ออฟไลน์ - บางฟีเจอร์อาจใช้งานไม่ได้', 'warning');
});

// Analytics (placeholder for future)
function trackEvent(category, action, label) {
    // Google Analytics or other tracking
    if (window.gtag) {
        gtag('event', action, {
            event_category: category,
            event_label: label
        });
    }

    console.log('Track:', category, action, label);
}

// Export app state for debugging
window.AppState = AppState;
window.API = API;
window.AIService = AIService;
window.ReasoningEngine = ReasoningEngine;
window.Calculations = Calculations;

// Log version
console.log('%c PD17 AI Formwork Calculator v1.0.0 ', 'background: #2563eb; color: white; font-size: 14px; padding: 5px 10px; border-radius: 5px;');
console.log('🌐 www.theedges.work');
