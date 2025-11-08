-- ProBuild: Architecture & Construction Project Management Database Schema
-- Designed for architects, interior designers, contractors, and project managers

-- Users and Authentication
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'architect', 'interior_designer', 'contractor', 'project_manager', 'client')),
    phone VARCHAR(50),
    avatar_url TEXT,
    company VARCHAR(255),
    specialization VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Projects
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    project_name VARCHAR(255) NOT NULL,
    project_code VARCHAR(50) UNIQUE NOT NULL,
    project_type VARCHAR(100) CHECK (project_type IN ('residential', 'commercial', 'industrial', 'renovation', 'interior', 'landscape')),
    description TEXT,
    client_id INTEGER REFERENCES users(id),
    project_manager_id INTEGER REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'planning' CHECK (status IN ('planning', 'design', 'approval', 'construction', 'finishing', 'completed', 'on_hold', 'cancelled')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),

    -- Location details
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    zip_code VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Timeline
    start_date DATE,
    estimated_completion DATE,
    actual_completion DATE,

    -- Financial
    total_budget DECIMAL(15, 2),
    spent_amount DECIMAL(15, 2) DEFAULT 0,
    currency VARCHAR(10) DEFAULT 'USD',

    -- Metadata
    floor_area DECIMAL(10, 2),
    floor_area_unit VARCHAR(10) DEFAULT 'sqft',
    floors_count INTEGER,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Project Team Members
CREATE TABLE project_team (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    role VARCHAR(100) NOT NULL,
    assigned_date DATE DEFAULT CURRENT_DATE,
    is_lead BOOLEAN DEFAULT FALSE,
    UNIQUE(project_id, user_id, role)
);

-- Tasks
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    task_name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) CHECK (category IN ('design', 'procurement', 'construction', 'inspection', 'documentation', 'client_approval', 'other')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'review', 'completed', 'blocked', 'cancelled')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),

    -- Assignment
    assigned_to INTEGER REFERENCES users(id),
    created_by INTEGER REFERENCES users(id),

    -- Timeline
    start_date DATE,
    due_date DATE,
    completed_date DATE,
    estimated_hours DECIMAL(6, 2),
    actual_hours DECIMAL(6, 2),

    -- Dependencies
    depends_on INTEGER REFERENCES tasks(id),

    -- Progress
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Materials Catalog
CREATE TABLE materials (
    id SERIAL PRIMARY KEY,
    material_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    supplier VARCHAR(255),
    unit VARCHAR(50) NOT NULL,
    unit_price DECIMAL(10, 2),
    currency VARCHAR(10) DEFAULT 'USD',
    description TEXT,
    specs TEXT,
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Project Materials & Budget
CREATE TABLE project_materials (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    material_id INTEGER REFERENCES materials(id),
    quantity DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_cost DECIMAL(12, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    status VARCHAR(50) DEFAULT 'estimated' CHECK (status IN ('estimated', 'ordered', 'delivered', 'used')),
    ordered_date DATE,
    delivered_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Documents & Files
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    document_type VARCHAR(100) CHECK (document_type IN ('blueprint', 'contract', '3d_model', 'photo', 'report', 'permit', 'invoice', 'other')),
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT,
    file_type VARCHAR(50),
    version INTEGER DEFAULT 1,
    uploaded_by INTEGER REFERENCES users(id),
    description TEXT,
    tags TEXT[],
    is_approved BOOLEAN DEFAULT FALSE,
    approved_by INTEGER REFERENCES users(id),
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Progress Photos
CREATE TABLE progress_photos (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    photo_url TEXT NOT NULL,
    thumbnail_url TEXT,
    photo_type VARCHAR(50) DEFAULT 'progress' CHECK (photo_type IN ('before', 'progress', 'after', 'issue', 'milestone')),
    location VARCHAR(255),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    description TEXT,
    annotations TEXT, -- JSON format for markup annotations
    taken_by INTEGER REFERENCES users(id),
    taken_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tags TEXT[]
);

-- Comments & Communication
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    comment_text TEXT NOT NULL,
    parent_comment_id INTEGER REFERENCES comments(id),
    attachments TEXT[], -- Array of file URLs
    is_edited BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notifications
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    notification_type VARCHAR(100) NOT NULL CHECK (notification_type IN ('task_assigned', 'deadline_approaching', 'budget_alert', 'weather_warning', 'approval_required', 'status_change', 'comment_mention', 'document_uploaded')),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    related_project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    related_task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    is_read BOOLEAN DEFAULT FALSE,
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Milestones
CREATE TABLE milestones (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    milestone_name VARCHAR(255) NOT NULL,
    description TEXT,
    target_date DATE NOT NULL,
    completed_date DATE,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'delayed')),
    completion_percentage INTEGER DEFAULT 0,
    is_critical BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Weather Alerts (for construction planning)
CREATE TABLE weather_alerts (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    alert_type VARCHAR(100) NOT NULL,
    severity VARCHAR(50) CHECK (severity IN ('low', 'medium', 'high', 'extreme')),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    description TEXT,
    recommended_action TEXT,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Client Approvals
CREATE TABLE approvals (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    approval_type VARCHAR(100) NOT NULL CHECK (approval_type IN ('design', 'budget', 'material', 'change_order', 'milestone', 'final')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    document_id INTEGER REFERENCES documents(id),
    requested_by INTEGER REFERENCES users(id),
    requested_from INTEGER REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'revision_required')),
    feedback TEXT,
    signature_url TEXT,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP
);

-- Activity Log
CREATE TABLE activity_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    action VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100),
    entity_id INTEGER,
    details TEXT, -- JSON format
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_client ON projects(client_id);
CREATE INDEX idx_projects_manager ON projects(project_manager_id);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_documents_project ON documents(project_id);
CREATE INDEX idx_photos_project ON progress_photos(project_id);
CREATE INDEX idx_comments_project ON comments(project_id);
CREATE INDEX idx_comments_task ON comments(task_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read);
CREATE INDEX idx_activity_project ON activity_log(project_id);
CREATE INDEX idx_activity_user ON activity_log(user_id);
