# PD17 AI Formwork Calculator

> **AI-Powered Formwork Calculator** สำหรับงานก่อสร้าง รองรับภาษาไทย ✨

[![PWA](https://img.shields.io/badge/PWA-Enabled-blue)](https://www.theedges.work)
[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare-Workers-orange)](https://workers.cloudflare.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🌟 Features

### Core Features
- 📄 **File Upload Support** - อัปโหลด PDF/Excel/รูปภาพ แล้วแยกข้อมูลอัตโนมัติ
- 🤖 **AI Chatbox** - สนทนากับ AI ด้วยภาษาไทย/อังกฤษ
- 🧠 **Reasoning Engine** - AI + Rule-Based Logic
- 📊 **Gantt Chart** - แสดงแผนงานแบบ Timeline
- 📑 **Export** - ส่งออกเป็น Excel และ PDF
- 💾 **PWA Support** - ใช้งานแบบ Offline ได้
- ⚡ **Cloudflare Workers** - Backend รวดเร็ว Edge Computing

### AI Capabilities
- แยกข้อมูลจากไฟล์ PDF/Excel อัตโนมัติ
- รับข้อมูลด้วยภาษาธรรมชาติ (Natural Language Input)
- วิเคราะห์และให้คำแนะนำตามมาตรฐาน ACI 318 และ TIS
- คำนวณต้นทุนและปริมาณวัสดุอย่างแม่นยำ

### Supported LLM Providers
- ✅ OpenRouter (DeepSeek, Llama, etc.)
- ✅ Kimi (Moonshot AI)
- ✅ GLM-4 (ChatGLM)
- 🔜 GPT-4o (OpenAI)
- 🔜 Claude (Anthropic)
- 🔜 Ollama (Local)

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/formwork-calculator.git
cd formwork-calculator
```

### 2. Run Locally
```bash
# Simple HTTP server
python3 -m http.server 8000

# Or use Node.js
npx http-server -p 8000
```

Visit: `http://localhost:8000`

### 3. Deploy Cloudflare Worker

```bash
# Install Wrangler
npm install -g wrangler

# Login to Cloudflare
wrangler login

# Create KV Namespace
wrangler kv:namespace create "CALCULATIONS_KV"

# Update workers/wrangler.toml with your IDs

# Set API Keys
wrangler secret put OPENROUTER_API_KEY
wrangler secret put KIMI_API_KEY
wrangler secret put GLM_API_KEY

# Deploy
cd workers
wrangler deploy
```

### 4. Deploy Frontend (Cloudflare Pages)

```bash
# Install Wrangler (if not already)
npm install -g wrangler

# Deploy to Cloudflare Pages
wrangler pages deploy . --project-name=formwork-calculator
```

Or use Vercel:
```bash
npm install -g vercel
vercel
```

## 📁 Project Structure

```
formwork-calculator/
├── index.html                 # Main HTML file
├── style.css                  # Styling
├── script.js                  # Main script
├── manifest.json              # PWA manifest
├── sw.js                      # Service Worker
├── src/
│   ├── components/
│   ├── utils/
│   │   ├── file-parser.js    # PDF/Excel parser
│   │   ├── calculations.js   # Core calculations
│   │   ├── gantt-chart.js    # Gantt visualization
│   │   └── export.js         # Excel/PDF export
│   └── services/
│       ├── ai-chatbox.js     # AI chat service
│       ├── reasoning-engine.js # Reasoning logic
│       └── api.js            # API client
├── workers/
│   ├── index.js              # Cloudflare Worker
│   └── wrangler.toml         # Worker config
├── public/
│   ├── icon-192.png
│   └── icon-512.png
└── README.md
```

## 🎯 Usage

### 1. Upload Files
ลากไฟล์ PDF/Excel มาวางที่กล่อง Upload หรือคลิกเพื่อเลือกไฟล์

### 2. Chat with AI
พิมพ์ข้อความ เช่น:
```
ชั้น 1 มีเสา 40x40 สูง 3.5 เมตร 24 ต้น
พื้นที่พื้น 183 ตร.ม. หนา 12 ซม.
คาน 25x50 ความยาวรวม 120 เมตร
```

AI จะแยกข้อมูลและเติมฟอร์มให้อัตโนมัติ

### 3. Manual Input
กรอกข้อมูลด้วยตนเองในฟอร์ม:
- ชื่อโครงการ
- ชั้น
- ข้อมูลเสา (กว้าง × ยาว × สูง × จำนวน)
- ข้อมูลคาน (กว้าง × สูง × ความยาว)
- ข้อมูลพื้น (พื้นที่ × หนา)
- คุณสมบัติวัสดุ (f'c, Reuse, ค้ำยัน)

### 4. Calculate
กดปุ่ม **คำนวณ** เพื่อดูผลลัพธ์:
- ค่าใช้จ่าย (วัสดุ + แรงงาน + เช่า)
- ระยะเวลา (Timeline + Gantt Chart)
- ปริมาณวัสดุ (ไม้อัด, ไม้แปรรูป, ค้ำยัน)
- ปริมาณคอนกรีต (ลบ.ม. + จำนวนรถ)
- AI Insights & Warnings

### 5. Export
กดปุ่ม **Export Excel** หรือ **Export PDF** เพื่อดาวน์โหลดรายงาน

## 🔧 Configuration

### Environment Variables (Cloudflare Workers)

```bash
# OpenRouter API (Free tier available)
wrangler secret put OPENROUTER_API_KEY

# Kimi API (Moonshot AI)
wrangler secret put KIMI_API_KEY

# GLM-4 API (ChatGLM)
wrangler secret put GLM_API_KEY
```

### AI Provider Selection

แก้ไขใน `src/services/ai-chatbox.js`:
```javascript
AIService.config.provider = 'openrouter'; // 'openrouter', 'kimi', 'glm'
```

## 🏗️ Technical Stack

### Frontend
- **HTML5** + **CSS3** + **Vanilla JavaScript**
- **Tailwind CSS** (via CDN)
- **Font Awesome** icons
- **Chart.js** for Gantt charts
- **PDF.js** for PDF parsing
- **SheetJS** (xlsx) for Excel
- **jsPDF** for PDF export

### Backend
- **Cloudflare Workers** (Edge Computing)
- **Cloudflare KV** (Key-Value Storage)
- **Cloudflare D1** (SQLite - optional)

### AI/LLM
- **OpenRouter** (DeepSeek, Llama, etc.)
- **Kimi** (Moonshot AI)
- **GLM-4** (ChatGLM)
- **Ollama** (Local - optional)

## 📊 Calculation Logic

### Cost Calculation
```
Total Cost = Materials + Labor + Rental

Materials:
- Plywood: (Area / 2.98 m²) × ₿320 × (1 - Reuse Discount)
- Lumber: Length × ₿15
- Accessories

Labor:
- Days = Area / 15 m²/day
- Cost = Days × (₿450 carpenter + ₿350 helper)

Rental:
- Props: (Area / 4) × ₿25 × Sets
- Metal forms: Area × ₿80 (if applicable)
```

### Timeline Estimation
```
1. Installation: Area / 15 m²/day
2. Concrete Pour: 1 day
3. Curing: Based on f'c (7-14 days)
4. Formwork Removal: 2 days
```

### Material Quantities
```
Plywood Sheets = Total Area / 2.98 m²
Lumber = Area × 2 (estimate)
Props = Area / 4 m² (1 prop per 4 m²)
```

## 🌐 Deployment

### Option 1: Cloudflare Pages (Recommended)
```bash
# Deploy frontend
wrangler pages deploy . --project-name=formwork-calculator

# Configure custom domain
# Dashboard > Workers & Pages > formwork-calculator > Custom Domains
# Add: www.theedges.work
```

### Option 2: Vercel
```bash
vercel --prod
```

### Option 3: Netlify
```bash
netlify deploy --prod
```

### Backend (Cloudflare Workers)
```bash
cd workers
wrangler deploy
```

Set up custom domain:
- Dashboard > Workers > formwork-calculator-api > Settings > Triggers
- Add route: `formwork-api.theedges.work/*`

## 🔒 Security

- ✅ API keys stored as Cloudflare Secrets (not in code)
- ✅ CORS configured properly
- ✅ Input validation
- ✅ Rate limiting (Cloudflare)
- ✅ HTTPS only

## 📱 PWA Installation

### Desktop
1. Visit website
2. Click "Install" icon in address bar
3. App icon on desktop

### Mobile (iOS/Android)
1. Visit website
2. Tap "Share" button
3. "Add to Home Screen"
4. App icon on home screen

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details

## 👥 Authors

- **PD17 Team** - [www.theedges.work](https://www.theedges.work)

## 🙏 Acknowledgments

- OpenRouter for free LLM access
- Cloudflare for Workers and Pages
- pdf.js by Mozilla
- SheetJS for Excel support
- Chart.js for visualizations

## 📞 Support

- 🌐 Website: [www.theedges.work](https://www.theedges.work)
- 📧 Email: support@theedges.work
- 💬 Issues: [GitHub Issues](https://github.com/yourusername/formwork-calculator/issues)

---

Made with ❤️ in Thailand 🇹🇭
