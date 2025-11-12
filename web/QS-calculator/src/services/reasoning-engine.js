// Reasoning Engine - Combines LLM AI + Rule-Based Logic
// Provides intelligent analysis and recommendations for formwork calculations

const ReasoningEngine = {
    // Construction standards and rules
    standards: {
        ACI318: {
            minConcreteStrength: 17, // MPa
            maxColumnHeight: 4.0, // meters per floor
            minCuringTime: {
                17: 14, // MPa: days
                28: 7,
                35: 5
            }
        },
        TIS: {
            woodReuse: 3, // standard reuse rate
            metalReuse: 50,
            maxLoadCapacity: 6000 // kg/m²
        },
        pricing: {
            plywood: {
                cost: 320, // baht per sheet (1.22x2.44m)
                area: 2.98 // m²
            },
            lumber: {
                cost: 15, // baht per meter
            },
            labor: {
                carpenter: 450, // baht per day
                helper: 350,
                hoursPerDay: 8
            },
            rental: {
                metalForm: 80, // baht per m² per month
                props: 25 // baht per piece per month
            }
        }
    },

    // Analyze input data and provide reasoning
    async analyze(data) {
        const insights = [];
        const warnings = [];
        const recommendations = [];

        // Rule 1: Check column height
        if (data.columnHeight > this.standards.ACI318.maxColumnHeight) {
            warnings.push({
                level: 'warning',
                message: `⚠️ เสาสูง ${data.columnHeight} ม. เกินมาตรฐาน ${this.standards.ACI318.maxColumnHeight} ม.`,
                recommendation: 'ควรเพิ่มค้ำยันเสริมหรือใช้แบบโลหะที่แข็งแรงกว่า'
            });
            recommendations.push('พิจารณาใช้ค้ำยันเพิ่มทุก 2 เมตร');
        } else {
            insights.push({
                level: 'success',
                message: `✓ ความสูงเสา ${data.columnHeight} ม. อยู่ในมาตรฐาน ACI 318`
            });
        }

        // Rule 2: Check concrete strength and curing time
        if (data.concreteFc) {
            const curingDays = this.standards.ACI318.minCuringTime[data.concreteFc] || 7;
            insights.push({
                level: 'info',
                message: `ℹ️ คอนกรีต f'c ${data.concreteFc} MPa ควรถอดแบบพื้นหลัง ${curingDays} วัน`,
                data: { curingDays }
            });

            if (data.concreteFc < this.standards.ACI318.minConcreteStrength) {
                warnings.push({
                    level: 'error',
                    message: `❌ f'c ${data.concreteFc} MPa ต่ำกว่ามาตรฐาน ${this.standards.ACI318.minConcreteStrength} MPa`
                });
            }
        }

        // Rule 3: Reuse rate optimization
        if (data.reuseRate) {
            if (data.reuseRate > this.standards.TIS.woodReuse) {
                recommendations.push(`💡 Reuse ${data.reuseRate} รอบ สูงกว่ามาตรฐาน (${this.standards.TIS.woodReuse} รอบ) - ลดราคาวัสดุ ${Math.round((data.reuseRate / this.standards.TIS.woodReuse - 1) * 100)}%`);
            } else {
                insights.push({
                    level: 'info',
                    message: `Reuse rate ${data.reuseRate} รอบอยู่ในเกณฑ์มาตรฐาน`
                });
            }
        }

        // Rule 4: Check column dimensions
        if (data.columnWidth && data.columnLength) {
            const columnArea = data.columnWidth * data.columnLength;
            if (columnArea < 900) { // 30x30 cm = 900 cm²
                warnings.push({
                    level: 'warning',
                    message: `⚠️ เสา ${data.columnWidth}x${data.columnLength} ซม. มีพื้นที่หน้าตัดเล็ก อาจไม่เพียงพอสำหรับโหลดโครงสร้าง`
                });
            }
        }

        // Rule 5: Estimate material efficiency
        if (data.slabArea && data.columnCount) {
            const efficiency = data.slabArea / data.columnCount;
            if (efficiency > 10) {
                insights.push({
                    level: 'success',
                    message: `✓ การกระจายเสา (${efficiency.toFixed(2)} ตร.ม./ต้น) มีประสิทธิภาพดี`
                });
            } else if (efficiency < 5) {
                warnings.push({
                    level: 'warning',
                    message: `⚠️ เสาหนาแน่นเกินไป (${efficiency.toFixed(2)} ตร.ม./ต้น) อาจเพิ่มต้นทุน`
                });
                recommendations.push('พิจารณาลดจำนวนเสาหรือเพิ่มขนาดเสา');
            }
        }

        // Rule 6: Safety factor check
        if (data.supportSets < 2) {
            warnings.push({
                level: 'warning',
                message: '⚠️ ชุดค้ำยันน้อยกว่า 2 ชุด อาจไม่ปลอดภัยเพียงพอ',
                recommendation: 'แนะนำให้ใช้อย่างน้อย 2 ชุดค้ำยัน'
            });
        }

        // Call LLM for additional insights (if available)
        const llmInsights = await this.getLLMInsights(data, insights, warnings);

        return {
            insights,
            warnings,
            recommendations,
            llmInsights,
            summary: this.generateSummary(insights, warnings, recommendations)
        };
    },

    // Get additional insights from LLM
    async getLLMInsights(data, insights, warnings) {
        try {
            const prompt = `วิเคราะห์ข้อมูลแบบหล่อนี้และให้คำแนะนำเพิ่มเติม:

ข้อมูล:
${JSON.stringify(data, null, 2)}

ข้อมูลเชิงลึกที่พบแล้ว:
${JSON.stringify(insights, null, 2)}

คำเตือน:
${JSON.stringify(warnings, null, 2)}

กรุณาให้คำแนะนำเพิ่มเติม 2-3 ข้อที่เป็นประโยชน์`;

            const response = await AIService.sendMessage(prompt, data);

            if (response && response.insights) {
                return response.insights;
            }

            return [];
        } catch (error) {
            console.error('LLM Insights Error:', error);
            return [];
        }
    },

    // Generate summary
    generateSummary(insights, warnings, recommendations) {
        const total = insights.length + warnings.length;
        const safetyLevel = warnings.length === 0 ? 'ปลอดภัย' :
            warnings.length <= 2 ? 'ควรปรับปรุง' : 'ต้องแก้ไข';

        return {
            total,
            safetyLevel,
            status: warnings.length === 0 ? 'good' : warnings.length <= 2 ? 'warning' : 'danger'
        };
    },

    // Calculate cost with reasoning
    calculateCostWithReasoning(data) {
        const costs = {
            materials: 0,
            labor: 0,
            rental: 0,
            total: 0,
            breakdown: []
        };

        // Column formwork area
        if (data.columnWidth && data.columnLength && data.columnHeight && data.columnCount) {
            const columnPerimeter = 2 * (data.columnWidth + data.columnLength) / 100; // convert to meters
            const columnArea = columnPerimeter * data.columnHeight * data.columnCount;

            const plywoodSheets = Math.ceil(columnArea / this.standards.pricing.plywood.area);
            const plywoodCost = plywoodSheets * this.standards.pricing.plywood.cost;

            // Apply reuse discount
            const reuseDiscount = data.reuseRate ? Math.min(data.reuseRate / 3, 0.6) : 0;
            const adjustedPlywoodCost = plywoodCost * (1 - reuseDiscount);

            costs.materials += adjustedPlywoodCost;
            costs.breakdown.push({
                item: 'ไม้อัด (เสา)',
                quantity: plywoodSheets,
                unit: 'แผ่น',
                unitPrice: this.standards.pricing.plywood.cost,
                subtotal: plywoodCost,
                discount: reuseDiscount * 100,
                total: adjustedPlywoodCost
            });

            // Lumber for bracing
            const lumberLength = columnArea * 2; // estimate
            const lumberCost = lumberLength * this.standards.pricing.lumber.cost;

            costs.materials += lumberCost;
            costs.breakdown.push({
                item: 'ไม้แปรรูป (ค้ำ)',
                quantity: Math.round(lumberLength),
                unit: 'ม.',
                unitPrice: this.standards.pricing.lumber.cost,
                total: lumberCost
            });
        }

        // Beam formwork
        if (data.beamWidth && data.beamHeight && data.beamLength) {
            const beamPerimeter = (2 * data.beamHeight + data.beamWidth) / 100;
            const beamArea = beamPerimeter * data.beamLength;

            const beamPlywood = Math.ceil(beamArea / this.standards.pricing.plywood.area);
            const beamCost = beamPlywood * this.standards.pricing.plywood.cost;

            costs.materials += beamCost;
            costs.breakdown.push({
                item: 'ไม้อัด (คาน)',
                quantity: beamPlywood,
                unit: 'แผ่น',
                unitPrice: this.standards.pricing.plywood.cost,
                total: beamCost
            });
        }

        // Slab formwork
        if (data.slabArea) {
            const slabPlywood = Math.ceil(data.slabArea / this.standards.pricing.plywood.area);
            const slabCost = slabPlywood * this.standards.pricing.plywood.cost;

            costs.materials += slabCost;
            costs.breakdown.push({
                item: 'ไม้อัด (พื้น)',
                quantity: slabPlywood,
                unit: 'แผ่น',
                unitPrice: this.standards.pricing.plywood.cost,
                total: slabCost
            });

            // Props/supports
            const propsNeeded = Math.ceil(data.slabArea / 4); // 1 prop per 4 m²
            const propsCost = propsNeeded * this.standards.pricing.rental.props * (data.supportSets || 1);

            costs.rental += propsCost;
            costs.breakdown.push({
                item: 'ค้ำยัน',
                quantity: propsNeeded,
                unit: 'ต้น',
                unitPrice: this.standards.pricing.rental.props,
                total: propsCost
            });
        }

        // Labor costs
        const totalArea = (data.slabArea || 0) +
            ((data.columnWidth * data.columnLength / 10000) * (data.columnCount || 0));

        // Estimate: 15 m² per day per team (1 carpenter + 1 helper)
        const laborDays = Math.ceil(totalArea / 15);
        const laborCost = laborDays * (this.standards.pricing.labor.carpenter + this.standards.pricing.labor.helper);

        costs.labor = laborCost;
        costs.breakdown.push({
            item: 'ค่าแรง',
            quantity: laborDays,
            unit: 'วัน',
            unitPrice: this.standards.pricing.labor.carpenter + this.standards.pricing.labor.helper,
            total: laborCost
        });

        // Total
        costs.total = costs.materials + costs.labor + costs.rental;

        return costs;
    },

    // Estimate timeline
    estimateTimeline(data) {
        const timeline = [];

        const totalArea = (data.slabArea || 0) +
            ((data.columnWidth * data.columnLength / 10000) * (data.columnCount || 0));

        // Installation
        const installDays = Math.ceil(totalArea / 15);
        timeline.push({
            phase: 'ติดตั้งแบบหล่อ',
            duration: installDays,
            start: 0,
            end: installDays
        });

        // Concrete pouring
        timeline.push({
            phase: 'เทคอนกรีต',
            duration: 1,
            start: installDays,
            end: installDays + 1
        });

        // Curing
        const curingDays = this.standards.ACI318.minCuringTime[data.concreteFc || 28] || 7;
        timeline.push({
            phase: 'บ่มคอนกรีต',
            duration: curingDays,
            start: installDays + 1,
            end: installDays + 1 + curingDays
        });

        // Formwork removal
        timeline.push({
            phase: 'ถอดแบบ',
            duration: 2,
            start: installDays + 1 + curingDays,
            end: installDays + 3 + curingDays
        });

        return {
            timeline,
            totalDays: installDays + 3 + curingDays
        };
    }
};

// Show insights in UI
function showInsights(insights) {
    const container = document.getElementById('ai-insights');
    const content = document.getElementById('insights-content');

    if (!insights || insights.length === 0) {
        container.classList.add('hidden');
        return;
    }

    container.classList.remove('hidden');
    content.innerHTML = insights.map(insight => `
        <div class="flex items-start gap-2 p-2 bg-white rounded border-l-4 border-${insight.level === 'warning' ? 'yellow' : insight.level === 'error' ? 'red' : 'green'}-500">
            <i class="fas fa-${insight.level === 'warning' ? 'exclamation-triangle' : insight.level === 'error' ? 'times-circle' : 'check-circle'} text-${insight.level === 'warning' ? 'yellow' : insight.level === 'error' ? 'red' : 'green'}-500 mt-1"></i>
            <div>
                <p class="font-medium">${insight.message}</p>
                ${insight.recommendation ? `<p class="text-sm text-gray-600 mt-1">💡 ${insight.recommendation}</p>` : ''}
            </div>
        </div>
    `).join('');
}
