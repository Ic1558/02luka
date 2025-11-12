// Gantt Chart Visualization using Chart.js
// Creates timeline visualization for formwork project phases

let ganttChartInstance = null;

function updateGanttChart(timelineData) {
    const canvas = document.getElementById('gantt-chart');
    const ctx = canvas.getContext('2d');

    // Destroy previous chart if exists
    if (ganttChartInstance) {
        ganttChartInstance.destroy();
    }

    if (!timelineData || !timelineData.timeline) {
        return;
    }

    const { timeline, totalDays } = timelineData;

    // Prepare data for Chart.js horizontal bar chart
    const labels = timeline.map(phase => phase.phase);
    const startDays = timeline.map(phase => phase.start);
    const durations = timeline.map(phase => phase.duration);

    // Color scheme for different phases
    const colors = [
        'rgba(59, 130, 246, 0.8)',   // Blue - Installation
        'rgba(16, 185, 129, 0.8)',   // Green - Concrete pour
        'rgba(245, 158, 11, 0.8)',   // Orange - Curing
        'rgba(139, 92, 246, 0.8)'    // Purple - Removal
    ];

    ganttChartInstance = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'เริ่มต้น',
                data: startDays,
                backgroundColor: 'transparent',
                borderWidth: 0
            }, {
                label: 'ระยะเวลา (วัน)',
                data: durations,
                backgroundColor: colors,
                borderColor: colors.map(c => c.replace('0.8', '1')),
                borderWidth: 2,
                borderRadius: 5
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                title: {
                    display: true,
                    text: `แผนงาน ${totalDays} วัน`,
                    font: {
                        size: 16,
                        weight: 'bold'
                    }
                },
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        label: function (context) {
                            if (context.datasetIndex === 0) return null;

                            const phase = timeline[context.dataIndex];
                            return [
                                `ระยะเวลา: ${phase.duration} วัน`,
                                `เริ่ม: วันที่ ${phase.start + 1}`,
                                `สิ้นสุด: วันที่ ${phase.end}`
                            ];
                        }
                    }
                }
            },
            scales: {
                x: {
                    stacked: true,
                    title: {
                        display: true,
                        text: 'วัน'
                    },
                    ticks: {
                        stepSize: 1
                    },
                    max: totalDays + 2
                },
                y: {
                    stacked: true
                }
            }
        }
    });
}

// Alternative: Simple CSS-based Gantt chart (if Chart.js is not available)
function createSimpleGanttChart(timelineData) {
    const container = document.getElementById('gantt-container');

    if (!timelineData || !timelineData.timeline) {
        container.innerHTML = '<p class="text-center text-gray-400">ไม่มีข้อมูล</p>';
        return;
    }

    const { timeline, totalDays } = timelineData;

    const colors = [
        'bg-blue-500',
        'bg-green-500',
        'bg-orange-500',
        'bg-purple-500'
    ];

    const html = `
        <div class="space-y-3">
            <h4 class="font-semibold text-gray-700 text-center mb-4">
                แผนงาน ${totalDays} วัน
            </h4>
            ${timeline.map((phase, index) => {
                const startPercent = (phase.start / totalDays) * 100;
                const widthPercent = (phase.duration / totalDays) * 100;

                return `
                    <div class="relative">
                        <div class="flex items-center justify-between mb-1">
                            <span class="text-sm font-medium text-gray-700">${phase.phase}</span>
                            <span class="text-xs text-gray-500">${phase.duration} วัน</span>
                        </div>
                        <div class="relative h-8 bg-gray-200 rounded-lg overflow-hidden">
                            <div
                                class="${colors[index % colors.length]} h-full rounded-lg flex items-center justify-center text-white text-xs font-semibold transition-all hover:opacity-90"
                                style="margin-left: ${startPercent}%; width: ${widthPercent}%;"
                            >
                                วันที่ ${phase.start + 1}-${phase.end}
                            </div>
                        </div>
                    </div>
                `;
            }).join('')}
        </div>
        <div class="mt-4 flex justify-between text-xs text-gray-500">
            <span>วันที่ 1</span>
            <span>วันที่ ${Math.floor(totalDays / 2)}</span>
            <span>วันที่ ${totalDays}</span>
        </div>
    `;

    container.innerHTML = html;
}

// Enhanced timeline with milestones
function createEnhancedTimeline(timelineData) {
    const { timeline, totalDays } = timelineData;

    const milestones = [
        {
            day: timeline[0].end,
            title: 'แบบหล่อติดตั้งเสร็จ',
            icon: 'fa-check-circle',
            color: 'blue'
        },
        {
            day: timeline[1].end,
            title: 'เทคอนกรีตเสร็จ',
            icon: 'fa-droplet',
            color: 'green'
        },
        {
            day: timeline[2].end,
            title: 'บ่มคอนกรีตครบ',
            icon: 'fa-clock',
            color: 'orange'
        },
        {
            day: timeline[3].end,
            title: 'ถอดแบบเสร็จสิ้น',
            icon: 'fa-flag-checkered',
            color: 'purple'
        }
    ];

    return {
        timeline,
        milestones,
        totalDays
    };
}
