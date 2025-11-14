// Export Utilities - Export to Excel and PDF
// Generates downloadable reports from calculation results

const ExportUtils = {
    // Export to Excel using SheetJS
    async exportToExcel() {
        try {
            // Get last calculation results
            const results = JSON.parse(localStorage.getItem('lastCalculation'));

            if (!results) {
                showNotification('ไม่พบข้อมูล กรุณาคำนวณก่อน', 'warning');
                return;
            }

            showLoading(true);

            const { data, costs, timeline, materials, concreteVolume } = results;

            // Create workbook
            const wb = XLSX.utils.book_new();

            // Sheet 1: Summary
            const summaryData = [
                ['PD17 AI Formwork Calculator'],
                ['รายงานการคำนวณแบบหล่อ'],
                [],
                ['โครงการ:', data.projectName],
                ['ชั้น:', data.floorLevel],
                ['วันที่:', new Date().toLocaleDateString('th-TH')],
                [],
                ['สรุปค่าใช้จ่าย'],
                ['รายการ', 'จำนวนเงิน (บาท)'],
                ['ค่าวัสดุ', costs.materials],
                ['ค่าแรง', costs.labor],
                ['ค่าเช่า', costs.rental],
                ['รวม', costs.total],
                ['รวม VAT 7%', costs.total * 1.07],
                [],
                ['ระยะเวลา'],
                ['รวมทั้งหมด', timeline.totalDays + ' วัน']
            ];

            const ws1 = XLSX.utils.aoa_to_sheet(summaryData);
            XLSX.utils.book_append_sheet(wb, ws1, 'สรุป');

            // Sheet 2: Cost Breakdown
            const breakdownData = [
                ['รายละเอียดค่าใช้จ่าย'],
                [],
                ['รายการ', 'จำนวน', 'หน่วย', 'ราคา/หน่วย', 'ส่วนลด %', 'รวม'],
                ...costs.breakdown.map(item => [
                    item.item,
                    item.quantity,
                    item.unit,
                    item.unitPrice,
                    item.discount || 0,
                    item.total
                ]),
                [],
                ['รวมค่าวัสดุ', '', '', '', '', costs.materials],
                ['รวมค่าแรง', '', '', '', '', costs.labor],
                ['รวมค่าเช่า', '', '', '', '', costs.rental],
                ['รวมทั้งหมด', '', '', '', '', costs.total]
            ];

            const ws2 = XLSX.utils.aoa_to_sheet(breakdownData);
            XLSX.utils.book_append_sheet(wb, ws2, 'รายละเอียด');

            // Sheet 3: Materials
            const materialsData = [
                ['วัสดุที่ใช้'],
                [],
                ['ไม้อัด (รวม)', materials.totalPlywoodSheets + ' แผ่น'],
                ['ไม้แปรรูป', materials.totalLumberMeters + ' ม.'],
                ['ค้ำยัน', materials.props + ' ต้น'],
                [],
                ['รายละเอียดแยกตามส่วน'],
                ['ส่วน', 'พื้นที่', 'ไม้อัด'],
                ...materials.accessories.map(acc => [
                    acc.name,
                    acc.area,
                    acc.plywood
                ])
            ];

            const ws3 = XLSX.utils.aoa_to_sheet(materialsData);
            XLSX.utils.book_append_sheet(wb, ws3, 'วัสดุ');

            // Sheet 4: Timeline
            const timelineData = [
                ['แผนงาน'],
                [],
                ['ขั้นตอน', 'ระยะเวลา (วัน)', 'เริ่มต้น (วัน)', 'สิ้นสุด (วัน)'],
                ...timeline.timeline.map(phase => [
                    phase.phase,
                    phase.duration,
                    phase.start + 1,
                    phase.end
                ]),
                [],
                ['รวมทั้งหมด', timeline.totalDays + ' วัน']
            ];

            const ws4 = XLSX.utils.aoa_to_sheet(timelineData);
            XLSX.utils.book_append_sheet(wb, ws4, 'แผนงาน');

            // Sheet 5: Concrete
            const concreteData = [
                ['ปริมาณคอนกรีต'],
                [],
                ['ปริมาตร (ลบ.ม.)', concreteVolume.cubic_meters],
                ['จำนวนรถ', concreteVolume.truckLoads + ' คัน'],
                [],
                ['คุณสมบัติคอนกรีต'],
                ["f'c", data.concreteFc + ' MPa'],
                ['Slump', '10-15 ซม. (แนะนำ)']
            ];

            const ws5 = XLSX.utils.aoa_to_sheet(concreteData);
            XLSX.utils.book_append_sheet(wb, ws5, 'คอนกรีต');

            // Generate Excel file
            const filename = `Formwork_${data.projectName}_${Date.now()}.xlsx`;
            XLSX.writeFile(wb, filename);

            showLoading(false);
            showNotification('Export Excel สำเร็จ! ✓', 'success');
        } catch (error) {
            showLoading(false);
            showNotification('Export Excel ล้มเหลว: ' + error.message, 'error');
            console.error('Excel Export Error:', error);
        }
    },

    // Export to PDF using jsPDF
    async exportToPDF() {
        try {
            // Get last calculation results
            const results = JSON.parse(localStorage.getItem('lastCalculation'));

            if (!results) {
                showNotification('ไม่พบข้อมูล กรุณาคำนวณก่อน', 'warning');
                return;
            }

            showLoading(true);

            const { data, costs, timeline, materials, concreteVolume } = results;

            // Create PDF with jsPDF
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF();

            // Thai font (requires font file - for now use default)
            doc.setFont('helvetica');

            // Title
            doc.setFontSize(20);
            doc.text('PD17 AI Formwork Calculator', 105, 20, { align: 'center' });

            doc.setFontSize(16);
            doc.text('Formwork Calculation Report', 105, 30, { align: 'center' });

            // Project info
            doc.setFontSize(12);
            doc.text(`Project: ${data.projectName}`, 20, 45);
            doc.text(`Floor: ${data.floorLevel}`, 20, 52);
            doc.text(`Date: ${new Date().toLocaleDateString('en-US')}`, 20, 59);

            // Line separator
            doc.setLineWidth(0.5);
            doc.line(20, 65, 190, 65);

            // Cost Summary
            doc.setFontSize(14);
            doc.setFont('helvetica', 'bold');
            doc.text('Cost Summary', 20, 75);

            doc.setFont('helvetica', 'normal');
            doc.setFontSize(11);

            let y = 85;
            doc.text(`Materials:`, 30, y);
            doc.text(`${this.formatNumber(costs.materials)} THB`, 150, y, { align: 'right' });

            y += 7;
            doc.text(`Labor:`, 30, y);
            doc.text(`${this.formatNumber(costs.labor)} THB`, 150, y, { align: 'right' });

            y += 7;
            doc.text(`Rental:`, 30, y);
            doc.text(`${this.formatNumber(costs.rental)} THB`, 150, y, { align: 'right' });

            y += 10;
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(13);
            doc.text(`Total:`, 30, y);
            doc.text(`${this.formatNumber(costs.total)} THB`, 150, y, { align: 'right' });

            y += 7;
            doc.setFontSize(10);
            doc.text(`Total with VAT (7%):`, 30, y);
            doc.text(`${this.formatNumber(costs.total * 1.07)} THB`, 150, y, { align: 'right' });

            // Materials
            y += 15;
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(14);
            doc.text('Materials', 20, y);

            y += 10;
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(11);

            doc.text(`Plywood sheets: ${materials.totalPlywoodSheets}`, 30, y);
            y += 7;
            doc.text(`Lumber: ${materials.totalLumberMeters} m`, 30, y);
            y += 7;
            doc.text(`Props: ${materials.props}`, 30, y);

            // Timeline
            y += 15;
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(14);
            doc.text('Timeline', 20, y);

            y += 10;
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(11);

            timeline.timeline.forEach(phase => {
                doc.text(`${phase.phase}: ${phase.duration} days`, 30, y);
                y += 7;
            });

            y += 5;
            doc.setFont('helvetica', 'bold');
            doc.text(`Total Duration: ${timeline.totalDays} days`, 30, y);

            // Concrete Volume
            y += 15;
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(14);
            doc.text('Concrete Volume', 20, y);

            y += 10;
            doc.setFont('helvetica', 'normal');
            doc.setFontSize(11);
            doc.text(`${concreteVolume.cubic_meters} cubic meters`, 30, y);
            y += 7;
            doc.text(`(${concreteVolume.truckLoads} truck loads)`, 30, y);

            // Footer
            doc.setFontSize(8);
            doc.setTextColor(128, 128, 128);
            doc.text('Generated by PD17 AI Formwork Calculator - www.theedges.work', 105, 285, { align: 'center' });

            // Save PDF
            const filename = `Formwork_${data.projectName}_${Date.now()}.pdf`;
            doc.save(filename);

            showLoading(false);
            showNotification('Export PDF สำเร็จ! ✓', 'success');
        } catch (error) {
            showLoading(false);
            showNotification('Export PDF ล้มเหลว: ' + error.message, 'error');
            console.error('PDF Export Error:', error);
        }
    },

    // Format number with thousand separators
    formatNumber(num) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(num);
    }
};

// Public functions
async function exportToExcel() {
    await ExportUtils.exportToExcel();
}

async function exportToPDF() {
    await ExportUtils.exportToPDF();
}
