// BOQ (Bill of Quantities) Management Functions
// Handles editable BOQ table with real-time calculations

const BOQ = {
    // Initialize BOQ
    init() {
        this.calculateBOQ();
    },

    // Add new BOQ row
    addRow() {
        const tbody = document.getElementById('boq-tbody');
        const rowCount = tbody.querySelectorAll('.boq-row').length + 1;

        const newRow = document.createElement('tr');
        newRow.className = 'boq-row hover:bg-gray-50 fade-in';
        newRow.innerHTML = `
            <td class="border border-gray-300 px-3 py-2 text-center row-number">${rowCount}</td>
            <td class="border border-gray-300 px-3 py-2">
                <input type="text" class="w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded" placeholder="ชื่อรายการ..." onchange="updateBOQRow(this)">
            </td>
            <td class="border border-gray-300 px-3 py-2">
                <input type="text" class="w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded" placeholder="รายละเอียด..." onchange="updateBOQRow(this)">
            </td>
            <td class="border border-gray-300 px-3 py-2">
                <input type="number" step="0.01" class="boq-qty w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded text-center" value="0" onchange="updateBOQRow(this)">
            </td>
            <td class="border border-gray-300 px-3 py-2">
                <input type="text" class="w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded text-center" placeholder="หน่วย" onchange="updateBOQRow(this)">
            </td>
            <td class="border border-gray-300 px-3 py-2">
                <input type="number" step="0.01" class="boq-price w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded text-right" value="0" onchange="updateBOQRow(this)">
            </td>
            <td class="border border-gray-300 px-3 py-2 text-right font-semibold boq-amount">0.00</td>
            <td class="border border-gray-300 px-3 py-2 text-center">
                <button onclick="deleteBOQRow(this)" class="text-red-500 hover:text-red-700 transition">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        `;

        tbody.appendChild(newRow);
        this.renumberRows();
    },

    // Update single row calculation
    updateRow(input) {
        const row = input.closest('tr');
        const qtyInput = row.querySelector('.boq-qty');
        const priceInput = row.querySelector('.boq-price');
        const amountCell = row.querySelector('.boq-amount');

        const qty = parseFloat(qtyInput.value) || 0;
        const price = parseFloat(priceInput.value) || 0;
        const amount = qty * price;

        amountCell.textContent = this.formatNumber(amount);

        // Recalculate total
        this.calculateBOQ();
    },

    // Delete row
    deleteRow(button) {
        const row = button.closest('tr');
        row.remove();
        this.renumberRows();
        this.calculateBOQ();
    },

    // Renumber all rows
    renumberRows() {
        const rows = document.querySelectorAll('.boq-row');
        rows.forEach((row, index) => {
            const numberCell = row.querySelector('.row-number');
            if (numberCell) {
                numberCell.textContent = index + 1;
            }
        });
    },

    // Calculate BOQ totals
    calculateBOQ() {
        const rows = document.querySelectorAll('.boq-row');
        let total = 0;

        rows.forEach(row => {
            const qtyInput = row.querySelector('.boq-qty');
            const priceInput = row.querySelector('.boq-price');
            const amountCell = row.querySelector('.boq-amount');

            const qty = parseFloat(qtyInput?.value) || 0;
            const price = parseFloat(priceInput?.value) || 0;
            const amount = qty * price;

            if (amountCell) {
                amountCell.textContent = this.formatNumber(amount);
            }

            total += amount;
        });

        // Calculate VAT and Grand Total
        const vat = total * 0.07;
        const grandTotal = total + vat;

        // Update footer
        const totalCell = document.getElementById('boq-total');
        const vatCell = document.getElementById('boq-vat');
        const grandTotalCell = document.getElementById('boq-grand-total');

        if (totalCell) totalCell.textContent = this.formatNumber(total);
        if (vatCell) vatCell.textContent = this.formatNumber(vat);
        if (grandTotalCell) grandTotalCell.textContent = this.formatNumber(grandTotal);

        return { total, vat, grandTotal };
    },

    // Format number with thousand separators
    formatNumber(num) {
        return new Intl.NumberFormat('th-TH', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(num);
    },

    // Export BOQ data
    exportData() {
        const rows = document.querySelectorAll('.boq-row');
        const data = [];

        rows.forEach(row => {
            const cells = row.querySelectorAll('input');
            data.push({
                item: cells[0]?.value || '',
                description: cells[1]?.value || '',
                quantity: parseFloat(cells[2]?.value) || 0,
                unit: cells[3]?.value || '',
                unitPrice: parseFloat(cells[4]?.value) || 0,
                amount: parseFloat(cells[2]?.value || 0) * parseFloat(cells[4]?.value || 0)
            });
        });

        const totals = this.calculateBOQ();

        return {
            items: data,
            subtotal: totals.total,
            vat: totals.vat,
            grandTotal: totals.grandTotal
        };
    },

    // Import BOQ data (from calculation or AI)
    importData(items) {
        const tbody = document.getElementById('boq-tbody');
        tbody.innerHTML = ''; // Clear existing rows

        items.forEach((item, index) => {
            const row = document.createElement('tr');
            row.className = 'boq-row hover:bg-gray-50';
            row.innerHTML = `
                <td class="border border-gray-300 px-3 py-2 text-center row-number">${index + 1}</td>
                <td class="border border-gray-300 px-3 py-2">
                    <input type="text" class="w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded" value="${item.item || ''}" onchange="updateBOQRow(this)">
                </td>
                <td class="border border-gray-300 px-3 py-2">
                    <input type="text" class="w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded" value="${item.description || ''}" onchange="updateBOQRow(this)">
                </td>
                <td class="border border-gray-300 px-3 py-2">
                    <input type="number" step="0.01" class="boq-qty w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded text-center" value="${item.quantity || 0}" onchange="updateBOQRow(this)">
                </td>
                <td class="border border-gray-300 px-3 py-2">
                    <input type="text" class="w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded text-center" value="${item.unit || ''}" onchange="updateBOQRow(this)">
                </td>
                <td class="border border-gray-300 px-3 py-2">
                    <input type="number" step="0.01" class="boq-price w-full px-2 py-1 border-0 focus:ring-2 focus:ring-blue-500 rounded text-right" value="${item.unitPrice || 0}" onchange="updateBOQRow(this)">
                </td>
                <td class="border border-gray-300 px-3 py-2 text-right font-semibold boq-amount">${this.formatNumber((item.quantity || 0) * (item.unitPrice || 0))}</td>
                <td class="border border-gray-300 px-3 py-2 text-center">
                    <button onclick="deleteBOQRow(this)" class="text-red-500 hover:text-red-700 transition">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(row);
        });

        this.calculateBOQ();
    }
};

// Public functions (called from HTML)
function addBOQRow() {
    BOQ.addRow();
}

function updateBOQRow(input) {
    BOQ.updateRow(input);
}

function deleteBOQRow(button) {
    if (confirm('ต้องการลบรายการนี้?')) {
        BOQ.deleteRow(button);
    }
}

function calculateBOQ() {
    return BOQ.calculateBOQ();
}

// QS Discipline Management
const QSDiscipline = {
    current: 'structural',

    templates: {
        arch: {
            name: 'Architecture',
            items: [
                { item: 'ผนังก่ออิฐบล็อก', description: 'หนา 10 ซม.', quantity: 150, unit: 'ตร.ม.', unitPrice: 280 },
                { item: 'ฉาบปูน', description: 'ฉาบเรียบ 2 ชั้น', quantity: 300, unit: 'ตร.ม.', unitPrice: 120 },
                { item: 'ทาสี', description: 'สีน้ำอะครีลิค', quantity: 300, unit: 'ตร.ม.', unitPrice: 80 }
            ]
        },
        structural: {
            name: 'Structural',
            items: [
                { item: 'ไม้อัดหนา 12 มม.', description: 'ขนาด 1.22x2.44 ม.', quantity: 50, unit: 'แผ่น', unitPrice: 320 },
                { item: 'ไม้แปรรูป 2x4', description: 'ยาว 4 เมตร', quantity: 200, unit: 'ม.', unitPrice: 15 },
                { item: 'ค้ำยัน (Props)', description: 'เหล็กปรับระดับได้', quantity: 45, unit: 'ต้น', unitPrice: 25 }
            ]
        },
        interior: {
            name: 'Interior',
            items: [
                { item: 'ฝ้าเพดาน', description: 'ยิปซั่มบอร์ด 9 มม.', quantity: 120, unit: 'ตร.ม.', unitPrice: 350 },
                { item: 'พื้นไม้ลามิเนต', description: 'Class 32 หนา 8 มม.', quantity: 80, unit: 'ตร.ม.', unitPrice: 450 },
                { item: 'ตู้ครัวบิ้วอิน', description: 'Melamine พร้อมเคาน์เตอร์', quantity: 6, unit: 'ม.', unitPrice: 8500 }
            ]
        },
        mep: {
            name: 'MEP',
            items: [
                { item: 'สายไฟ THW', description: '2.5 ตร.มม.', quantity: 500, unit: 'ม.', unitPrice: 12 },
                { item: 'ท่อน้ำ PVC', description: 'ขนาด 1/2 นิ้ว', quantity: 200, unit: 'ม.', unitPrice: 18 },
                { item: 'แอร์บ้าน', description: '18,000 BTU', quantity: 3, unit: 'เครื่อง', unitPrice: 15000 }
            ]
        }
    },

    select(discipline) {
        this.current = discipline;

        // Update UI - highlight selected button
        document.querySelectorAll('.discipline-btn').forEach(btn => {
            btn.classList.remove('ring-4', 'ring-blue-500', 'bg-blue-100', 'bg-green-100', 'bg-orange-100', 'bg-purple-100');
        });

        const button = document.getElementById(`btn-${discipline}`);
        if (button) {
            button.classList.add('ring-4');
            if (discipline === 'arch') button.classList.add('ring-blue-500', 'bg-blue-100');
            if (discipline === 'structural') button.classList.add('ring-green-500', 'bg-green-100');
            if (discipline === 'interior') button.classList.add('ring-orange-500', 'bg-orange-100');
            if (discipline === 'mep') button.classList.add('ring-purple-500', 'bg-purple-100');
        }

        // Update hidden input
        document.getElementById('selected-discipline').value = discipline;

        // Load template BOQ
        const template = this.templates[discipline];
        if (template) {
            BOQ.importData(template.items);
            showNotification(`เปลี่ยนเป็น ${template.name} แล้ว! โหลด BOQ ตัวอย่าง`, 'success');
        }
    }
};

// Public function
function selectDiscipline(discipline) {
    QSDiscipline.select(discipline);
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    BOQ.init();
    QSDiscipline.select('structural'); // Default
});
