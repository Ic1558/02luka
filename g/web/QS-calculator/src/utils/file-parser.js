// File Parser for PDF, Excel, and Images
// Supports extraction of construction data from uploaded files

const FileParser = {
    // Parse PDF files using PDF.js
    async parsePDF(file) {
        try {
            showLoading(true);
            const arrayBuffer = await file.arrayBuffer();
            const loadingTask = pdfjsLib.getDocument({ data: arrayBuffer });
            const pdf = await loadingTask.promise;

            let fullText = '';

            // Extract text from all pages
            for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
                const page = await pdf.getPage(pageNum);
                const textContent = await page.getTextContent();
                const pageText = textContent.items.map(item => item.str).join(' ');
                fullText += pageText + '\n';
            }

            // Extract data using patterns
            const extractedData = this.extractConstructionData(fullText);

            showLoading(false);
            showNotification('PDF parsed successfully! ✓', 'success');

            return {
                text: fullText,
                data: extractedData,
                fileName: file.name
            };
        } catch (error) {
            showLoading(false);
            showNotification('Error parsing PDF: ' + error.message, 'error');
            console.error('PDF parsing error:', error);
            return null;
        }
    },

    // Parse Excel files using SheetJS
    async parseExcel(file) {
        try {
            showLoading(true);
            const arrayBuffer = await file.arrayBuffer();
            const workbook = XLSX.read(arrayBuffer, { type: 'array' });

            const sheetName = workbook.SheetNames[0];
            const worksheet = workbook.Sheets[sheetName];

            // Convert to JSON
            const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

            // Extract construction data
            const extractedData = this.extractFromExcelData(jsonData);

            showLoading(false);
            showNotification('Excel parsed successfully! ✓', 'success');

            return {
                data: extractedData,
                rawData: jsonData,
                fileName: file.name
            };
        } catch (error) {
            showLoading(false);
            showNotification('Error parsing Excel: ' + error.message, 'error');
            console.error('Excel parsing error:', error);
            return null;
        }
    },

    // Parse images (for future OCR integration)
    async parseImage(file) {
        try {
            showLoading(true);
            const reader = new FileReader();

            return new Promise((resolve, reject) => {
                reader.onload = (e) => {
                    const imageData = e.target.result;

                    // For now, just preview the image
                    // In the future, integrate Tesseract.js for OCR
                    showLoading(false);
                    showNotification('Image uploaded! OCR coming soon...', 'warning');

                    resolve({
                        imageData,
                        fileName: file.name
                    });
                };

                reader.onerror = (error) => {
                    showLoading(false);
                    reject(error);
                };

                reader.readAsDataURL(file);
            });
        } catch (error) {
            showLoading(false);
            showNotification('Error parsing image: ' + error.message, 'error');
            return null;
        }
    },

    // Extract construction data from text using regex patterns
    extractConstructionData(text) {
        const data = {};

        // Extract floor level: "ชั้น 1", "Floor 1", "F1", etc.
        const floorMatch = text.match(/ชั้น\s*(\d+)|Floor\s*(\d+)|F(\d+)/i);
        if (floorMatch) {
            data.floorLevel = parseInt(floorMatch[1] || floorMatch[2] || floorMatch[3]);
        }

        // Extract column dimensions: "40x40", "40 x 40", "0.4x0.4 m"
        const columnMatch = text.match(/เสา.*?(\d+)\s*[xX×]\s*(\d+)|Column.*?(\d+)\s*[xX×]\s*(\d+)/i);
        if (columnMatch) {
            data.columnWidth = parseInt(columnMatch[1] || columnMatch[3]);
            data.columnLength = parseInt(columnMatch[2] || columnMatch[4]);
        }

        // Extract column height: "สูง 3.5 ม.", "H=3.5m", "height 3.5"
        const heightMatch = text.match(/สูง\s*([\d.]+)\s*ม|H\s*=\s*([\d.]+)|height\s*([\d.]+)/i);
        if (heightMatch) {
            data.columnHeight = parseFloat(heightMatch[1] || heightMatch[2] || heightMatch[3]);
        }

        // Extract column count: "24 ต้น", "24 columns"
        const countMatch = text.match(/(\d+)\s*ต้น|(\d+)\s*columns/i);
        if (countMatch) {
            data.columnCount = parseInt(countMatch[1] || countMatch[2]);
        }

        // Extract beam dimensions: "25x50", "B=25x50"
        const beamMatch = text.match(/คาน.*?(\d+)\s*[xX×]\s*(\d+)|Beam.*?(\d+)\s*[xX×]\s*(\d+)/i);
        if (beamMatch) {
            data.beamWidth = parseInt(beamMatch[1] || beamMatch[3]);
            data.beamHeight = parseInt(beamMatch[2] || beamMatch[4]);
        }

        // Extract slab area: "183 ตร.ม.", "183 sqm"
        const areaMatch = text.match(/([\d.]+)\s*ตร\.?ม|area\s*([\d.]+)/i);
        if (areaMatch) {
            data.slabArea = parseFloat(areaMatch[1] || areaMatch[2]);
        }

        // Extract concrete grade: "f'c 28 MPa", "fc28"
        const fcMatch = text.match(/f'?c\s*(\d+)|fc(\d+)/i);
        if (fcMatch) {
            data.concreteFc = parseInt(fcMatch[1] || fcMatch[2]);
        }

        return data;
    },

    // Extract data from Excel rows
    extractFromExcelData(rows) {
        const data = {};

        // Look for specific keywords in cells
        rows.forEach((row, rowIndex) => {
            row.forEach((cell, colIndex) => {
                if (!cell) return;

                const cellStr = cell.toString().toLowerCase();

                // Floor
                if (cellStr.includes('floor') || cellStr.includes('ชั้น')) {
                    const nextCell = row[colIndex + 1];
                    if (nextCell && !isNaN(nextCell)) {
                        data.floorLevel = parseInt(nextCell);
                    }
                }

                // Column dimensions
                if (cellStr.includes('column') || cellStr.includes('เสา')) {
                    const dimensionMatch = cellStr.match(/(\d+)\s*[xX×]\s*(\d+)/);
                    if (dimensionMatch) {
                        data.columnWidth = parseInt(dimensionMatch[1]);
                        data.columnLength = parseInt(dimensionMatch[2]);
                    }
                }

                // Slab area
                if (cellStr.includes('area') || cellStr.includes('พื้นที่')) {
                    const nextCell = row[colIndex + 1];
                    if (nextCell && !isNaN(nextCell)) {
                        data.slabArea = parseFloat(nextCell);
                    }
                }
            });
        });

        return data;
    }
};

// File upload event handlers
function setupFileUpload() {
    const fileInput = document.getElementById('file-upload');
    const dropZone = document.getElementById('drop-zone');

    // File input change event
    fileInput.addEventListener('change', handleFileSelect);

    // Drag and drop events
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('drag-over');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('drag-over');
    });

    dropZone.addEventListener('drop', async (e) => {
        e.preventDefault();
        dropZone.classList.remove('drag-over');

        const files = e.dataTransfer.files;
        await processFiles(files);
    });

    // Click to select
    dropZone.addEventListener('click', () => {
        fileInput.click();
    });
}

async function handleFileSelect(event) {
    const files = event.target.files;
    await processFiles(files);
}

async function processFiles(files) {
    const preview = document.getElementById('file-preview');
    preview.innerHTML = '';

    for (const file of files) {
        const fileExt = file.name.split('.').pop().toLowerCase();

        // Add file to preview
        addFileToPreview(file);

        // Parse based on file type
        let result;
        if (fileExt === 'pdf') {
            result = await FileParser.parsePDF(file);
        } else if (fileExt === 'xlsx' || fileExt === 'xls') {
            result = await FileParser.parseExcel(file);
        } else if (['jpg', 'jpeg', 'png'].includes(fileExt)) {
            result = await FileParser.parseImage(file);
        } else {
            showNotification('Unsupported file type: ' + fileExt, 'error');
            continue;
        }

        // Populate form with extracted data
        if (result && result.data) {
            populateForm(result.data);

            // Send to AI for analysis
            await sendToAI(`ไฟล์ ${file.name} ถูกอัปโหลด. ข้อมูลที่แยกได้: ${JSON.stringify(result.data, null, 2)}`);
        }
    }
}

function addFileToPreview(file) {
    const preview = document.getElementById('file-preview');
    const fileItem = document.createElement('div');
    fileItem.className = 'file-item';

    const fileSize = (file.size / 1024).toFixed(2) + ' KB';
    const fileExt = file.name.split('.').pop().toUpperCase();

    fileItem.innerHTML = `
        <div class="flex items-center gap-2">
            <i class="fas fa-file-${getFileIcon(fileExt)} text-blue-600"></i>
            <div>
                <p class="text-sm font-medium text-gray-800">${file.name}</p>
                <p class="text-xs text-gray-500">${fileSize}</p>
            </div>
        </div>
        <button onclick="this.parentElement.remove()" class="remove-btn">
            <i class="fas fa-times"></i>
        </button>
    `;

    preview.appendChild(fileItem);
}

function getFileIcon(ext) {
    const icons = {
        'PDF': 'pdf',
        'XLSX': 'excel',
        'XLS': 'excel',
        'JPG': 'image',
        'JPEG': 'image',
        'PNG': 'image'
    };
    return icons[ext] || 'alt';
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    setupFileUpload();
});
