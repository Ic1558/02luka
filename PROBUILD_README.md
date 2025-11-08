# ProBuild - Architecture & Construction Project Management

A comprehensive web application for architects, interior designers, contractors, and project managers to collaborate and manage construction projects efficiently.

## Features

### Core Features
- **Project Management** - Create, track, and manage multiple construction projects
- **Task Assignment & Tracking** - Assign tasks to team members with deadlines and progress tracking
- **Team Collaboration** - Real-time updates and communication via WebSockets
- **Budget Tracking** - Monitor project budgets and expenses in real-time
- **Document Management** - Upload and organize blueprints, contracts, and project files
- **Progress Photos** - Timeline of before/after photos with annotations
- **Client Portal** - Allow clients to view project progress and approve milestones
- **Mobile Responsive** - Full functionality on both desktop and mobile devices

### Smart Features
- **Real-time Notifications** - Instant alerts for deadlines, budget warnings, and updates
- **Weather Alerts** - Construction delay warnings based on weather forecasts
- **Interactive Dashboard** - Visual overview with charts and statistics
- **Role-Based Access** - Different permissions for architects, contractors, clients, etc.
- **Activity Timeline** - Track all project activities and changes
- **Smart Search** - Quick search across projects, tasks, and materials

## Tech Stack

### Frontend
- **React 18** - Modern UI framework
- **React Router** - Client-side routing
- **Tailwind CSS** - Utility-first CSS framework
- **Vite** - Fast build tool and dev server
- **Recharts** - Data visualization charts
- **Socket.IO Client** - Real-time communication
- **Zustand** - State management
- **React Toastify** - Notifications

### Backend
- **Node.js** - JavaScript runtime
- **Express** - Web application framework
- **PostgreSQL** - Relational database
- **Sequelize** - ORM for database
- **Redis** - Caching and pub/sub messaging
- **Socket.IO** - WebSocket server
- **JWT** - Authentication
- **bcryptjs** - Password hashing

## Project Structure

```
02luka/
├── webapp/                 # React frontend application
│   ├── src/
│   │   ├── components/    # React components
│   │   │   └── layout/    # Layout components
│   │   ├── pages/         # Page components
│   │   ├── store/         # State management
│   │   ├── App.jsx        # Main app component
│   │   └── main.jsx       # Entry point
│   ├── public/            # Static assets
│   └── package.json
│
├── api/                   # Node.js backend API
│   ├── routes/            # API routes
│   │   ├── auth.js
│   │   ├── projects.js
│   │   ├── tasks.js
│   │   └── ...
│   ├── middleware/        # Express middleware
│   ├── services/          # Business logic services
│   ├── config/            # Configuration files
│   ├── server.js          # API server entry point
│   └── package.json
│
└── database/              # Database schema
    └── schema.sql         # PostgreSQL schema
```

## Installation & Setup

### Prerequisites
- Node.js >= 18.0.0
- PostgreSQL >= 14
- Redis >= 7
- npm or yarn

### 1. Clone the Repository
```bash
git clone <repository-url>
cd 02luka
```

### 2. Database Setup
```bash
# Create PostgreSQL database
createdb probuild

# Run schema
psql -d probuild -f database/schema.sql
```

### 3. Backend Setup
```bash
cd api

# Install dependencies
npm install

# Create .env file
cp .env.example .env

# Edit .env with your configuration
# DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET, etc.

# Start backend server
npm run dev
```

The API server will start on `http://localhost:4000`

### 4. Frontend Setup
```bash
cd webapp

# Install dependencies
npm install

# Start development server
npm run dev
```

The web app will start on `http://localhost:3000`

### 5. Start Redis (required for real-time features)
```bash
# Using Docker
docker run -d -p 6379:6379 redis:7-alpine

# Or using local Redis installation
redis-server
```

## Docker Deployment

### Quick Start with Docker Compose
```bash
# Build and start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Services
- **webapp** - Frontend (port 3000)
- **api** - Backend API (port 4000)
- **postgres** - Database (port 5432)
- **redis** - Cache & messaging (port 6379)

## API Documentation

### Authentication Endpoints
```
POST   /api/auth/register      - Register new user
POST   /api/auth/login         - Login user
GET    /api/auth/me            - Get current user
```

### Project Endpoints
```
GET    /api/projects           - Get all projects
POST   /api/projects           - Create new project
GET    /api/projects/:id       - Get project by ID
PUT    /api/projects/:id       - Update project
DELETE /api/projects/:id       - Delete project
GET    /api/projects/:id/stats - Get project statistics
```

### Task Endpoints
```
GET    /api/tasks              - Get all tasks
POST   /api/tasks              - Create new task
GET    /api/tasks/:id          - Get task by ID
PUT    /api/tasks/:id          - Update task
DELETE /api/tasks/:id          - Delete task
```

### Team Endpoints
```
GET    /api/team               - Get all team members
POST   /api/team               - Add team member
```

### Notification Endpoints
```
GET    /api/notifications      - Get user notifications
PATCH  /api/notifications/:id/read - Mark as read
```

## Real-time Events

The application uses Socket.IO for real-time updates:

### Client-side Connection
```javascript
import io from 'socket.io-client'

const socket = io('http://localhost:4000', {
  auth: {
    token: 'your-jwt-token'
  }
})

// Join project room
socket.emit('join_project', projectId)

// Listen for updates
socket.on('task_updated', (data) => {
  console.log('Task updated:', data)
})
```

### Available Events
- `project_created` - New project created
- `project_updated` - Project updated
- `task_created` - New task created
- `task_updated` - Task updated
- `comment_added` - New comment added
- `user_typing` - User is typing
- `user_presence` - User presence update

## User Roles

### Admin
- Full system access
- Manage all projects and users
- System configuration

### Architect
- Create and manage projects
- Assign tasks
- Upload blueprints and designs
- Review and approve work

### Interior Designer
- Collaborate on design aspects
- Upload mood boards and materials
- Track interior-specific tasks

### Contractor
- View project plans
- Update construction progress
- Upload progress photos
- Manage construction tasks

### Project Manager
- Overall project coordination
- Budget tracking
- Timeline management
- Team communication

### Client
- View project progress
- Approve designs and milestones
- Communicate with team
- View documents and photos

## Development

### Frontend Development
```bash
cd webapp
npm run dev     # Start dev server
npm run build   # Build for production
npm run preview # Preview production build
```

### Backend Development
```bash
cd api
npm run dev     # Start with nodemon
npm start       # Start production server
```

## Environment Variables

### Backend (.env)
```env
PORT=4000
NODE_ENV=development

DB_HOST=localhost
DB_PORT=5432
DB_NAME=probuild
DB_USER=postgres
DB_PASSWORD=your_password

JWT_SECRET=your-secret-key
JWT_EXPIRE=7d

REDIS_HOST=localhost
REDIS_PORT=6379

CORS_ORIGIN=http://localhost:3000
```

### Frontend
Vite automatically loads env variables from `.env` files. Prefix with `VITE_` to expose to client:
```env
VITE_API_URL=http://localhost:4000
```

## Features Roadmap

### Phase 1 (Complete)
- ✅ Database schema design
- ✅ React frontend with responsive design
- ✅ API server with authentication
- ✅ Project & task management
- ✅ Real-time updates via WebSocket

### Phase 2 (In Progress)
- 🔄 Gantt chart timeline view
- 🔄 File upload and management
- 🔄 Budget tracking calculator
- 🔄 Progress photo gallery
- 🔄 Client approval workflow

### Phase 3 (Planned)
- 📋 AI-powered project insights
- 📋 Weather integration
- 📋 Material cost database
- 📋 AR blueprint viewer (mobile)
- 📋 Advanced reporting
- 📋 Email notifications
- 📋 Calendar integration

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is proprietary and confidential.

## Support

For support, please contact the development team or create an issue in the repository.

## Screenshots

### Dashboard
View project overview with statistics, charts, and recent activity.

### Projects
Manage all projects with grid or list view, filtering, and search.

### Project Detail
Detailed project view with tasks, team, files, photos, and progress tracking.

### Mobile View
Fully responsive design works seamlessly on mobile devices with touch-optimized interface.

## Security

- JWT-based authentication
- Password hashing with bcrypt
- Rate limiting on API endpoints
- Helmet.js for security headers
- Input validation on all endpoints
- CORS configuration
- SQL injection prevention via Sequelize ORM

## Performance

- Redis caching for frequently accessed data
- Database query optimization
- Lazy loading of components
- Image optimization
- Gzip compression
- CDN-ready static assets

## Monitoring

- Health check endpoint: `/healthz`
- Request logging with Morgan
- Error tracking and logging
- Performance metrics

---

Built with ❤️ for the architecture and construction industry
