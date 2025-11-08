-- Phase 22.1: Context & Sketch Module Migration
-- Adds support for design contexts and sketch management

-- Design Contexts Table
CREATE TABLE IF NOT EXISTS contexts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    site_name VARCHAR(255),

    -- Location data
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'USA',
    zip_code VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- Zoning & regulatory
    zoning_code VARCHAR(100),
    zoning_description TEXT,
    lot_size DECIMAL(12, 2),
    lot_size_unit VARCHAR(20) DEFAULT 'sqft',
    floor_area_ratio DECIMAL(5, 2),
    max_height DECIMAL(8, 2),
    max_height_unit VARCHAR(20) DEFAULT 'ft',
    setback_front DECIMAL(8, 2),
    setback_rear DECIMAL(8, 2),
    setback_side DECIMAL(8, 2),

    -- Site characteristics
    topography VARCHAR(100),
    soil_type VARCHAR(100),
    water_table_depth DECIMAL(8, 2),
    flood_zone VARCHAR(50),
    seismic_zone VARCHAR(50),

    -- Environmental
    solar_orientation VARCHAR(50),
    prevailing_wind VARCHAR(50),
    climate_zone VARCHAR(50),
    vegetation_type TEXT,

    -- Documentation
    description TEXT,
    notes TEXT,
    files TEXT[], -- Array of file paths/URLs
    images TEXT[], -- Site photos

    -- Metadata
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sketches Table
CREATE TABLE IF NOT EXISTS sketches (
    id SERIAL PRIMARY KEY,
    context_id INTEGER REFERENCES contexts(id) ON DELETE CASCADE,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,

    -- Sketch metadata
    title VARCHAR(255) NOT NULL,
    description TEXT,
    sketch_type VARCHAR(100) CHECK (sketch_type IN ('site_plan', 'floor_plan', 'elevation', 'section', 'detail', 'concept', 'freehand', 'annotation')),

    -- Drawing data
    canvas_data JSONB NOT NULL, -- Fabric.js canvas JSON
    thumbnail_url TEXT,
    full_image_url TEXT,

    -- Dimensions
    width INTEGER DEFAULT 1920,
    height INTEGER DEFAULT 1080,
    scale VARCHAR(50),
    units VARCHAR(20) DEFAULT 'ft',

    -- Versioning
    version INTEGER DEFAULT 1,
    parent_sketch_id INTEGER REFERENCES sketches(id),
    is_latest BOOLEAN DEFAULT TRUE,

    -- Collaboration
    created_by INTEGER REFERENCES users(id),
    modified_by INTEGER REFERENCES users(id),

    -- Status
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'review', 'approved', 'archived')),

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sketch Revisions (for version history)
CREATE TABLE IF NOT EXISTS sketch_revisions (
    id SERIAL PRIMARY KEY,
    sketch_id INTEGER REFERENCES sketches(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    canvas_data JSONB NOT NULL,
    thumbnail_url TEXT,
    created_by INTEGER REFERENCES users(id),
    change_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sketch_id, version)
);

-- Task-Sketch Links (connect sketches to project tasks)
CREATE TABLE IF NOT EXISTS task_sketch_links (
    id SERIAL PRIMARY KEY,
    task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE,
    sketch_id INTEGER REFERENCES sketches(id) ON DELETE CASCADE,
    link_type VARCHAR(50) DEFAULT 'reference' CHECK (link_type IN ('reference', 'deliverable', 'annotation')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(task_id, sketch_id)
);

-- Context-Project Association (update projects table)
ALTER TABLE projects
ADD COLUMN IF NOT EXISTS context_id INTEGER REFERENCES contexts(id);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_contexts_created_by ON contexts(created_by);
CREATE INDEX IF NOT EXISTS idx_contexts_location ON contexts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_sketches_context ON sketches(context_id);
CREATE INDEX IF NOT EXISTS idx_sketches_project ON sketches(project_id);
CREATE INDEX IF NOT EXISTS idx_sketches_type ON sketches(sketch_type);
CREATE INDEX IF NOT EXISTS idx_sketches_status ON sketches(status);
CREATE INDEX IF NOT EXISTS idx_sketch_revisions_sketch ON sketch_revisions(sketch_id);
CREATE INDEX IF NOT EXISTS idx_task_sketch_links_task ON task_sketch_links(task_id);
CREATE INDEX IF NOT EXISTS idx_task_sketch_links_sketch ON task_sketch_links(sketch_id);

-- Function to auto-increment version on sketch save
CREATE OR REPLACE FUNCTION increment_sketch_version()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id IS NOT NULL AND OLD.canvas_data IS DISTINCT FROM NEW.canvas_data THEN
        -- Archive old version
        INSERT INTO sketch_revisions (sketch_id, version, canvas_data, thumbnail_url, created_by, created_at)
        VALUES (OLD.id, OLD.version, OLD.canvas_data, OLD.thumbnail_url, OLD.modified_by, OLD.updated_at);

        -- Increment version
        NEW.version := OLD.version + 1;
        NEW.updated_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for sketch versioning
DROP TRIGGER IF EXISTS sketch_version_trigger ON sketches;
CREATE TRIGGER sketch_version_trigger
    BEFORE UPDATE ON sketches
    FOR EACH ROW
    EXECUTE FUNCTION increment_sketch_version();

-- Comments: Migration adds full context and sketch management system
-- Contexts store site data, zoning, environmental factors
-- Sketches use JSONB for Fabric.js canvas data with versioning
-- Auto-versioning trigger maintains revision history
-- Links allow attaching sketches to tasks for traceability
