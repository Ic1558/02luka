import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { ToastContainer } from 'react-toastify'
import 'react-toastify/dist/ReactToastify.css'

// Layouts
import MainLayout from './components/layout/MainLayout'
import AuthLayout from './components/layout/AuthLayout'

// Pages
import Dashboard from './pages/Dashboard'
import Projects from './pages/Projects'
import ProjectDetail from './pages/ProjectDetail'
import Tasks from './pages/Tasks'
import Team from './pages/Team'
import Materials from './pages/Materials'
import Documents from './pages/Documents'
import Calendar from './pages/Calendar'
import Reports from './pages/Reports'
import Settings from './pages/Settings'
import Login from './pages/Login'
import Register from './pages/Register'

// Hooks
import { useAuthStore } from './store/authStore'

function App() {
  const { isAuthenticated } = useAuthStore()

  return (
    <>
      <Router>
        <Routes>
          {/* Public routes */}
          <Route element={<AuthLayout />}>
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
          </Route>

          {/* Protected routes */}
          <Route element={<MainLayout />}>
            <Route path="/" element={isAuthenticated ? <Dashboard /> : <Navigate to="/login" />} />
            <Route path="/dashboard" element={isAuthenticated ? <Dashboard /> : <Navigate to="/login" />} />
            <Route path="/projects" element={isAuthenticated ? <Projects /> : <Navigate to="/login" />} />
            <Route path="/projects/:id" element={isAuthenticated ? <ProjectDetail /> : <Navigate to="/login" />} />
            <Route path="/tasks" element={isAuthenticated ? <Tasks /> : <Navigate to="/login" />} />
            <Route path="/team" element={isAuthenticated ? <Team /> : <Navigate to="/login" />} />
            <Route path="/materials" element={isAuthenticated ? <Materials /> : <Navigate to="/login" />} />
            <Route path="/documents" element={isAuthenticated ? <Documents /> : <Navigate to="/login" />} />
            <Route path="/calendar" element={isAuthenticated ? <Calendar /> : <Navigate to="/login" />} />
            <Route path="/reports" element={isAuthenticated ? <Reports /> : <Navigate to="/login" />} />
            <Route path="/settings" element={isAuthenticated ? <Settings /> : <Navigate to="/login" />} />
          </Route>

          {/* 404 */}
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </Router>

      {/* Toast notifications */}
      <ToastContainer
        position="top-right"
        autoClose={3000}
        hideProgressBar={false}
        newestOnTop={true}
        closeOnClick
        rtl={false}
        pauseOnFocusLoss
        draggable
        pauseOnHover
        theme="light"
      />
    </>
  )
}

export default App
