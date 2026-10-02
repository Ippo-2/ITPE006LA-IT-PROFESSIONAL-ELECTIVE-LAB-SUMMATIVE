-- ==============================================================================
-- Database DDL Script: Online Campus Event Management System
-- Lead: Member 3 (Database Engineer)
-- Normalization Level: 3rd Normal Form (3NF)
-- Dialect: ANSI SQL / Microsoft SQL Server Compatible (Transact-SQL)
-- Features: Foreign Key Cascades/Restraints, CHECK Constraints, Non-Clustered Indexes
-- ==============================================================================

-- Initial provisioning only. Refuse to overwrite existing tables or data.
IF OBJECT_ID('dbo.Registrations', 'U') IS NOT NULL
    OR OBJECT_ID('dbo.Events', 'U') IS NOT NULL
    OR OBJECT_ID('dbo.Venues', 'U') IS NOT NULL
    OR OBJECT_ID('dbo.Users', 'U') IS NOT NULL
BEGIN
    THROW 51000, 'Schema objects already exist. Run this setup script against a clean database; existing data will not be dropped.', 1;
END;

-- ------------------------------------------------------------------------------
-- 1. USERS TABLE
-- Stores students, organizers, and campus administrators.
-- 3NF: All user profile attributes are atomic and depend solely on user_id.
-- ------------------------------------------------------------------------------
CREATE TABLE dbo.Users (
    user_id INT IDENTITY(1,1) NOT NULL,
    full_name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL,
    role NVARCHAR(20) NOT NULL CONSTRAINT DF_Users_Role DEFAULT 'student',
    created_at DATETIME2(7) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
    
    -- Primary Key Constraint
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (user_id),
    
    -- Unique Email Constraint
    CONSTRAINT UQ_Users_Email UNIQUE (email),
    
    -- CHECK Constraints for Data Validation
    CONSTRAINT CK_Users_FullName_NotEmpty CHECK (LEN(LTRIM(RTRIM(full_name))) > 0),
    CONSTRAINT CK_Users_Email_Format CHECK (email LIKE '%_@__%.__%'),
    CONSTRAINT CK_Users_Role_Valid CHECK (role IN ('student', 'admin', 'organizer'))
);

-- ------------------------------------------------------------------------------
-- 2. VENUES TABLE
-- Separates physical location attributes to satisfy 3NF (eliminating transitive
-- dependencies between events and venue characteristics like building/capacity).
-- ------------------------------------------------------------------------------
CREATE TABLE dbo.Venues (
    venue_id INT IDENTITY(1,1) NOT NULL,
    venue_name NVARCHAR(150) NOT NULL,
    building NVARCHAR(100) NOT NULL,
    max_capacity INT NOT NULL,
    created_at DATETIME2(7) NOT NULL CONSTRAINT DF_Venues_CreatedAt DEFAULT SYSUTCDATETIME(),
    
    -- Primary Key Constraint
    CONSTRAINT PK_Venues PRIMARY KEY CLUSTERED (venue_id),
    
    -- CHECK Constraints
    CONSTRAINT CK_Venues_Name_NotEmpty CHECK (LEN(LTRIM(RTRIM(venue_name))) > 0),
    CONSTRAINT CK_Venues_MaxCapacity_Positive CHECK (max_capacity > 0)
);

-- ------------------------------------------------------------------------------
-- 3. EVENTS TABLE
-- Holds event metadata. References Venues and Users (organizer).
-- 3NF: Depends strictly on event_id; venue details are isolated and available
-- seats are derived from capacity and active registrations.
-- ------------------------------------------------------------------------------
CREATE TABLE dbo.Events (
    event_id INT IDENTITY(1,1) NOT NULL,
    event_code NVARCHAR(50) NOT NULL,
    title NVARCHAR(200) NOT NULL,
    description NVARCHAR(MAX) NULL,
    venue_id INT NOT NULL,
    organizer_id INT NOT NULL,
    event_date DATE NOT NULL,
    start_time TIME(0) NOT NULL,
    end_time TIME(0) NOT NULL,
    capacity INT NOT NULL,
    image_color NVARCHAR(10) NOT NULL CONSTRAINT DF_Events_ImageColor DEFAULT '#183532',
    image_description NVARCHAR(255) NULL,
    status NVARCHAR(20) NOT NULL CONSTRAINT DF_Events_Status DEFAULT 'published',
    created_at DATETIME2(7) NOT NULL CONSTRAINT DF_Events_CreatedAt DEFAULT SYSUTCDATETIME(),
    
    -- Primary Key Constraint
    CONSTRAINT PK_Events PRIMARY KEY CLUSTERED (event_id),
    
    -- Unique Identifier Constraint
    CONSTRAINT UQ_Events_EventCode UNIQUE (event_code),
    
    -- Foreign Key Constraints with Referential Actions
    CONSTRAINT FK_Events_Venues FOREIGN KEY (venue_id)
        REFERENCES dbo.Venues (venue_id)
        ON UPDATE CASCADE
        ON DELETE NO ACTION, -- Prevent accidental deletion of venues hosting events
        
    CONSTRAINT FK_Events_Users_Organizer FOREIGN KEY (organizer_id)
        REFERENCES dbo.Users (user_id)
        ON UPDATE CASCADE
        ON DELETE NO ACTION, -- Prevent accidental deletion of event organizer
        
    -- CHECK Constraints
    CONSTRAINT CK_Events_Capacity_Positive CHECK (capacity > 0),
    CONSTRAINT CK_Events_TimeOrder CHECK (end_time > start_time),
    CONSTRAINT CK_Events_Status_Valid CHECK (status IN ('draft', 'published', 'cancelled', 'completed'))
);

-- ------------------------------------------------------------------------------
-- 4. REGISTRATIONS TABLE (Intersection / Associative Entity)
-- Connects Users and Events. Represents student registrations.
-- 3NF: Represents M:N relationship with individual surrogate PK and compound unique key.
-- ------------------------------------------------------------------------------
CREATE TABLE dbo.Registrations (
    registration_id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    event_id INT NOT NULL,
    registration_date DATETIME2(7) NOT NULL CONSTRAINT DF_Registrations_Date DEFAULT SYSUTCDATETIME(),
    status NVARCHAR(20) NOT NULL CONSTRAINT DF_Registrations_Status DEFAULT 'registered',
    remarks NVARCHAR(500) NULL,
    created_at DATETIME2(7) NOT NULL CONSTRAINT DF_Registrations_CreatedAt DEFAULT SYSUTCDATETIME(),
    
    -- Primary Key Constraint
    CONSTRAINT PK_Registrations PRIMARY KEY CLUSTERED (registration_id),
    
    -- Unique Constraint: Prevent duplicate registration for the same event by one user
    CONSTRAINT UQ_Registrations_User_Event UNIQUE (user_id, event_id),
    
    -- Foreign Key Constraints with Referential Actions
    CONSTRAINT FK_Registrations_Users FOREIGN KEY (user_id)
        REFERENCES dbo.Users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE, -- If user is deleted, their event registrations cascade
        
    CONSTRAINT FK_Registrations_Events FOREIGN KEY (event_id)
        REFERENCES dbo.Events (event_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE, -- If an event is removed, corresponding registrations cascade
        
    -- CHECK Constraints
    CONSTRAINT CK_Registrations_Status_Valid CHECK (status IN ('registered', 'attended', 'cancelled', 'waitlisted'))
);

-- ==============================================================================
-- NON-CLUSTERED INDEXES
-- Optimize join performance and index all foreign key columns as required
-- ==============================================================================

-- Non-clustered indexes on Events Foreign Keys
CREATE NONCLUSTERED INDEX IX_Events_VenueId
    ON dbo.Events (venue_id)
    INCLUDE (title, event_date, status);

CREATE NONCLUSTERED INDEX IX_Events_OrganizerId
    ON dbo.Events (organizer_id);

-- Non-clustered indexes on Registrations Foreign Keys
CREATE NONCLUSTERED INDEX IX_Registrations_UserId
    ON dbo.Registrations (user_id)
    INCLUDE (event_id, status);

CREATE NONCLUSTERED INDEX IX_Registrations_EventId
    ON dbo.Registrations (event_id)
    INCLUDE (user_id, status);

-- Composite / Search optimization indexes for frequent query patterns
CREATE NONCLUSTERED INDEX IX_Events_Status_Date
    ON dbo.Events (status, event_date)
    INCLUDE (event_code, title, capacity);

CREATE NONCLUSTERED INDEX IX_Registrations_Status
    ON dbo.Registrations (status);

-- ==============================================================================
-- SEED DATA
-- Populates the schema with initial records matching the frontend prototype
-- ==============================================================================

-- Seed Users (Admin, Organizer, and Students)
INSERT INTO dbo.Users (full_name, email, role)
VALUES 
    (N'Dr. Jane Smith', N'admin@campus.edu', 'admin'),
    (N'Campus Activities Board', N'events@campus.edu', 'organizer'),
    (N'Alex Johnson', N'alex.johnson@univ.edu.ph', 'student'),
    (N'Maria Santos', N'maria.santos@univ.edu.ph', 'student'),
    (N'Liam Garcia', N'liam.garcia@univ.edu.ph', 'student');

-- Seed Venues
INSERT INTO dbo.Venues (venue_name, building, max_capacity)
VALUES 
    (N'Founders Quad', N'Campus Grounds', 200),
    (N'Reading Room', N'Hawthorne Library', 50),
    (N'Atrium', N'Engineering Hall', 100),
    (N'Lakeside Lawn', N'Campus Outdoors', 300),
    (N'Main Hall', N'Student Union', 150),
    (N'Cedar Auditorium', N'Performing Arts Center', 250);

-- Seed Events matching frontend/script.js catalog. Capacity includes the seeded
-- active registrations; available seats are derived by the backend and view.
INSERT INTO dbo.Events (event_code, title, description, venue_id, organizer_id, event_date, start_time, end_time, capacity, image_color, image_description, status)
VALUES
    (N'harvest-fair', N'Autumn Harvest Fair', N'A campus fair celebration with autumn leaves and golden sun.', 1, 2, '2026-10-14', '09:00:00', '16:00:00', 44, N'#c6603d', N'A campus fair illustration with autumn leaves and a golden sun.', 'published'),
    (N'poetry-night', N'Open Mic Poetry Night', N'An open mic reading room evening with live poetry.', 2, 2, '2026-10-21', '18:00:00', '21:00:00', 29, N'#406a82', N'A reading-room illustration with a microphone and blue stage lights.', 'published'),
    (N'robotics-showcase', N'Student Robotics Showcase', N'Student innovation showcase featuring autonomous bots.', 3, 2, '2026-10-29', '10:00:00', '15:00:00', 65, N'#537b55', N'A robotics showcase illustration with a small campus-built robot.', 'published'),
    (N'film-screening', N'Outdoor Film Screening', N'Evening movie screening beneath the campus stars.', 4, 2, '2026-11-06', '19:00:00', '22:00:00', 90, N'#76547d', N'An outdoor movie illustration with a screen beneath the evening sky.', 'published'),
    (N'winter-market', N'Winter Makers Market', N'Craft market featuring handcrafted gifts and winter items.', 5, 2, '2026-11-18', '11:00:00', '17:00:00', 54, N'#377b78', N'A makers market illustration with craft stalls and winter decorations.', 'published'),
    (N'music-showcase', N'Campus Music Showcase', N'Live musical concert featuring student bands and solo acts.', 6, 2, '2026-12-02', '18:30:00', '21:30:00', 110, N'#a65354', N'A live music illustration with a guitar under warm stage lights.', 'published');

-- Seed Sample Registrations
INSERT INTO dbo.Registrations (user_id, event_id, status)
VALUES
    (3, 1, 'registered'), -- Alex Johnson registered for Autumn Harvest Fair
    (4, 1, 'registered'), -- Maria Santos registered for Autumn Harvest Fair
    (5, 2, 'registered'); -- Liam Garcia registered for Open Mic Poetry Night

-- ==============================================================================
-- VIEW: vw_EventRegistrationOverview
-- Helpful for backend queries and administrative attendee dashboards
-- ==============================================================================
GO
CREATE OR ALTER VIEW dbo.vw_EventRegistrationOverview AS
SELECT 
    r.registration_id,
    u.user_id,
    u.full_name AS student_name,
    u.email AS student_email,
    e.event_id,
    e.event_code,
    e.title AS event_title,
    e.event_date,
    e.capacity,
    e.capacity - (
        SELECT COUNT(*)
        FROM dbo.Registrations AS active_reg
        WHERE active_reg.event_id = e.event_id
          AND active_reg.status IN ('registered', 'attended')
    ) AS seats_available,
    v.venue_name,
    v.building,
    r.registration_date,
    r.status AS registration_status
FROM dbo.Registrations r
INNER JOIN dbo.Users u ON r.user_id = u.user_id
INNER JOIN dbo.Events e ON r.event_id = e.event_id
INNER JOIN dbo.Venues v ON e.venue_id = v.venue_id;
GO
