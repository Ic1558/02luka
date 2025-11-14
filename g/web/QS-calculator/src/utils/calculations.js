// Formwork Calculations Utility
// Core calculation logic for formwork materials and costs

const Calculations = {
    // Main calculation function
    async calculate(data) {
        try {
            showLoading(true);

            // Validate data
            const validation = this.validate(data);
            if (!validation.valid) {
                showNotification('กรุณากรอกข้อมูลให้ครบถ้วน: ' + validation.errors.join(', '), 'error');
                showLoading(false);
                return null;
            }

            // Run reasoning engine analysis
            const reasoning = await ReasoningEngine.analyze(data);

            // Calculate costs
            const costs = ReasoningEngine.calculateCostWithReasoning(data);

            // Estimate timeline
            const timeline = ReasoningEngine.estimateTimeline(data);

            // Calculate material quantities
            const materials = this.calculateMaterials(data);

            // Calculate concrete volume
            const concreteVolume = this.calculateConcreteVolume(data);

            showLoading(false);

            const results = {
                data,
                reasoning,
                costs,
                timeline,
                materials,
                concreteVolume,
                timestamp: new Date().toISOString()
            };

            // Display results
            this.displayResults(results);

            // Update Gantt chart
            updateGanttChart(timeline);

            // Show AI insights
            if (reasoning.insights.length > 0 || reasoning.warnings.length > 0) {
                showInsights([...reasoning.insights, ...reasoning.warnings]);
            }

            // Save to local storage for later
            this.saveResults(results);

            showNotification('คำนวณเสร็จสิ้น! ✓', 'success');

            return results;
        } catch (error) {
            showLoading(false);
            showNotification('เกิดข้อผิดพลาดในการคำนวณ: ' + error.message, 'error');
            console.error('Calculation Error:', error);
            return null;
        }
    },

    // Validate input data
    validate(data) {
        const errors = [];

        if (!data.projectName) errors.push('ชื่อโครงการ');
        if (!data.floorLevel) errors.push('ชั้น');

        // At least one element should be defined
        const hasColumn = data.columnWidth && data.columnHeight && data.columnCount;
        const hasBeam = data.beamWidth && data.beamHeight && data.beamLength;
        const hasSlab = data.slabArea;

        if (!hasColumn && !hasBeam && !hasSlab) {
            errors.push('กรุณากรอกข้อมูลอย่างน้อย 1 รายการ (เสา/คาน/พื้น)');
        }

        return {
            valid: errors.length === 0,
            errors
        };
    },

    // Calculate materials breakdown
    calculateMaterials(data) {
        const materials = {
            plywood: 0,
            lumber: 0,
            props: 0,
            accessories: []
        };

        // Column materials
        if (data.columnWidth && data.columnLength && data.columnHeight && data.columnCount) {
            const columnPerimeter = 2 * (parseFloat(data.columnWidth) + parseFloat(data.columnLength)) / 100; // to meters
            const columnArea = columnPerimeter * parseFloat(data.columnHeight) * parseInt(data.columnCount);

            materials.plywood += columnArea;
            materials.lumber += columnArea * 2; // estimate

            materials.accessories.push({
                name: 'แบบเสา',
                area: columnArea.toFixed(2) + ' ตร.ม.',
                plywood: Math.ceil(columnArea / 2.98) + ' แผ่น'
            });
        }

        // Beam materials
        if (data.beamWidth && data.beamHeight && data.beamLength) {
            const beamPerimeter = (2 * parseFloat(data.beamHeight) + parseFloat(data.beamWidth)) / 100;
            const beamArea = beamPerimeter * parseFloat(data.beamLength);

            materials.plywood += beamArea;
            materials.lumber += beamArea * 1.5;

            materials.accessories.push({
                name: 'แบบคาน',
                area: beamArea.toFixed(2) + ' ตร.ม.',
                plywood: Math.ceil(beamArea / 2.98) + ' แผ่น'
            });
        }

        // Slab materials
        if (data.slabArea) {
            const slabArea = parseFloat(data.slabArea);

            materials.plywood += slabArea;
            materials.props = Math.ceil(slabArea / 4); // 1 prop per 4 m²

            materials.accessories.push({
                name: 'แบบพื้น',
                area: slabArea.toFixed(2) + ' ตร.ม.',
                plywood: Math.ceil(slabArea / 2.98) + ' แผ่น',
                props: materials.props + ' ต้น'
            });
        }

        // Total plywood sheets
        materials.totalPlywoodSheets = Math.ceil(materials.plywood / 2.98);
        materials.totalLumberMeters = Math.ceil(materials.lumber);

        return materials;
    },

    // Calculate concrete volume
    calculateConcreteVolume(data) {
        let volume = 0;

        // Column volume
        if (data.columnWidth && data.columnLength && data.columnHeight && data.columnCount) {
            const columnVol = (parseFloat(data.columnWidth) / 100) *
                (parseFloat(data.columnLength) / 100) *
                parseFloat(data.columnHeight) *
                parseInt(data.columnCount);
            volume += columnVol;
        }

        // Beam volume
        if (data.beamWidth && data.beamHeight && data.beamLength) {
            const beamVol = (parseFloat(data.beamWidth) / 100) *
                (parseFloat(data.beamHeight) / 100) *
                parseFloat(data.beamLength);
            volume += beamVol;
        }

        // Slab volume
        if (data.slabArea && data.slabThickness) {
            const slabVol = parseFloat(data.slabArea) * (parseFloat(data.slabThickness) / 100);
            volume += slabVol;
        }

        return {
            cubic_meters: volume.toFixed(2),
            cubic_yards: (volume * 1.30795).toFixed(2),
            truckLoads: Math.ceil(volume / 6) // assume 6 m³ per truck
        };
    },

    // Display results in UI
    displayResults(results) {
        const container = document.getElementById('results-container');

        const { costs, timeline, materials, concreteVolume, reasoning } = results;

        container.innerHTML = `
            <!-- Summary Cards -->
            <div class="grid grid-cols-2 gap-3 mb-4">
                <div class="bg-gradient-to-br from-blue-500 to-blue-600 text-white p-4 rounded-lg">
                    <p class="text-sm opacity-90">ค่าวัสดุ</p>
                    <p class="text-2xl font-bold">${this.formatCurrency(costs.materials)}</p>
                </div>
                <div class="bg-gradient-to-br from-green-500 to-green-600 text-white p-4 rounded-lg">
                    <p class="text-sm opacity-90">ค่าแรง</p>
                    <p class="text-2xl font-bold">${this.formatCurrency(costs.labor)}</p>
                </div>
            </div>

            <!-- Total Cost -->
            <div class="bg-gradient-to-br from-purple-500 to-purple-600 text-white p-5 rounded-lg mb-4">
                <p class="text-sm opacity-90">รวมทั้งหมด</p>
                <p class="text-3xl font-bold">${this.formatCurrency(costs.total)}</p>
                <p class="text-xs opacity-80 mt-2">รวม VAT 7%: ${this.formatCurrency(costs.total * 1.07)}</p>
            </div>

            <!-- Timeline -->
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                <h3 class="font-semibold text-blue-900 mb-2 flex items-center gap-2">
                    <i class="fas fa-clock"></i>
                    ระยะเวลา
                </h3>
                <p class="text-2xl font-bold text-blue-700">${timeline.totalDays} วัน</p>
                <div class="mt-3 space-y-1 text-sm text-gray-700">
                    ${timeline.timeline.map(phase => `
                        <div class="flex justify-between">
                            <span>${phase.phase}</span>
                            <span class="font-medium">${phase.duration} วัน</span>
                        </div>
                    `).join('')}
                </div>
            </div>

            <!-- Materials -->
            <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                <h3 class="font-semibold text-green-900 mb-2 flex items-center gap-2">
                    <i class="fas fa-box"></i>
                    วัสดุ
                </h3>
                <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                        <span>ไม้อัด</span>
                        <span class="font-medium">${materials.totalPlywoodSheets} แผ่น</span>
                    </div>
                    <div class="flex justify-between">
                        <span>ไม้แปรรูป</span>
                        <span class="font-medium">${materials.totalLumberMeters} ม.</span>
                    </div>
                    <div class="flex justify-between">
                        <span>ค้ำยัน</span>
                        <span class="font-medium">${materials.props} ต้น</span>
                    </div>
                </div>
            </div>

            <!-- Concrete Volume -->
            <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
                <h3 class="font-semibold text-orange-900 mb-2 flex items-center gap-2">
                    <i class="fas fa-cube"></i>
                    ปริมาณคอนกรีต
                </h3>
                <p class="text-2xl font-bold text-orange-700">${concreteVolume.cubic_meters} ลบ.ม.</p>
                <p class="text-sm text-gray-600 mt-1">(${concreteVolume.truckLoads} คันรถ)</p>
            </div>

            <!-- Cost Breakdown -->
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <h3 class="font-semibold text-gray-900 mb-3 flex items-center justify-between">
                    <span><i class="fas fa-list"></i> รายละเอียด</span>
                    <button onclick="toggleBreakdown()" class="text-blue-600 text-sm">
                        <i class="fas fa-chevron-down" id="breakdown-icon"></i>
                    </button>
                </h3>
                <div id="cost-breakdown" class="hidden space-y-2 text-sm">
                    ${costs.breakdown.map(item => `
                        <div class="border-b border-gray-200 pb-2">
                            <div class="flex justify-between font-medium">
                                <span>${item.item}</span>
                                <span>${this.formatCurrency(item.total)}</span>
                            </div>
                            <div class="text-xs text-gray-600 mt-1">
                                ${item.quantity} ${item.unit} × ${this.formatCurrency(item.unitPrice)}
                                ${item.discount ? `<span class="text-green-600"> (-${item.discount.toFixed(0)}%)</span>` : ''}
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>

            <!-- Safety Status -->
            <div class="mt-4 p-4 rounded-lg ${reasoning.summary.status === 'good' ? 'bg-green-100 border border-green-300' : reasoning.summary.status === 'warning' ? 'bg-yellow-100 border border-yellow-300' : 'bg-red-100 border border-red-300'}">
                <p class="font-semibold ${reasoning.summary.status === 'good' ? 'text-green-800' : reasoning.summary.status === 'warning' ? 'text-yellow-800' : 'text-red-800'}">
                    <i class="fas fa-${reasoning.summary.status === 'good' ? 'check-circle' : 'exclamation-triangle'}"></i>
                    สถานะ: ${reasoning.summary.safetyLevel}
                </p>
            </div>
        `;
    },

    // Format currency
    formatCurrency(amount) {
        return new Intl.NumberFormat('th-TH', {
            style: 'currency',
            currency: 'THB',
            minimumFractionDigits: 0
        }).format(amount);
    },

    // Save results to local storage
    saveResults(results) {
        try {
            localStorage.setItem('lastCalculation', JSON.stringify(results));
            localStorage.setItem('calculationHistory', JSON.stringify([
                ...this.getCalculationHistory(),
                {
                    id: Date.now(),
                    projectName: results.data.projectName,
                    timestamp: results.timestamp,
                    total: results.costs.total
                }
            ]));
        } catch (error) {
            console.error('Save Error:', error);
        }
    },

    // Get calculation history
    getCalculationHistory() {
        try {
            return JSON.parse(localStorage.getItem('calculationHistory') || '[]');
        } catch {
            return [];
        }
    }
};

// Public function to calculate
async function calculateFormwork() {
    const data = {
        projectName: document.getElementById('project-name').value,
        floorLevel: document.getElementById('floor-level').value,
        columnWidth: document.getElementById('column-width').value,
        columnLength: document.getElementById('column-length').value,
        columnHeight: document.getElementById('column-height').value,
        columnCount: document.getElementById('column-count').value,
        beamWidth: document.getElementById('beam-width').value,
        beamHeight: document.getElementById('beam-height').value,
        beamLength: document.getElementById('beam-length').value,
        slabArea: document.getElementById('slab-area').value,
        slabThickness: document.getElementById('slab-thickness').value,
        concreteFc: document.getElementById('concrete-fc').value,
        reuseRate: document.getElementById('reuse-rate').value,
        supportSets: document.getElementById('support-sets').value
    };

    return await Calculations.calculate(data);
}

// Toggle cost breakdown
function toggleBreakdown() {
    const breakdown = document.getElementById('cost-breakdown');
    const icon = document.getElementById('breakdown-icon');

    if (breakdown.classList.contains('hidden')) {
        breakdown.classList.remove('hidden');
        icon.classList.remove('fa-chevron-down');
        icon.classList.add('fa-chevron-up');
    } else {
        breakdown.classList.add('hidden');
        icon.classList.remove('fa-chevron-up');
        icon.classList.add('fa-chevron-down');
    }
}

// Populate form with data
function populateForm(data) {
    if (data.projectName) document.getElementById('project-name').value = data.projectName;
    if (data.floorLevel) document.getElementById('floor-level').value = data.floorLevel;
    if (data.columnWidth) document.getElementById('column-width').value = data.columnWidth;
    if (data.columnLength) document.getElementById('column-length').value = data.columnLength;
    if (data.columnHeight) document.getElementById('column-height').value = data.columnHeight;
    if (data.columnCount) document.getElementById('column-count').value = data.columnCount;
    if (data.beamWidth) document.getElementById('beam-width').value = data.beamWidth;
    if (data.beamHeight) document.getElementById('beam-height').value = data.beamHeight;
    if (data.beamLength) document.getElementById('beam-length').value = data.beamLength;
    if (data.slabArea) document.getElementById('slab-area').value = data.slabArea;
    if (data.slabThickness) document.getElementById('slab-thickness').value = data.slabThickness;
    if (data.concreteFc) document.getElementById('concrete-fc').value = data.concreteFc;
    if (data.reuseRate) document.getElementById('reuse-rate').value = data.reuseRate;
    if (data.supportSets) document.getElementById('support-sets').value = data.supportSets;

    showNotification('ข้อมูลถูกเติมอัตโนมัติแล้ว ✓', 'success');
}
