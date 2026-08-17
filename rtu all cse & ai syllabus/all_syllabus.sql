-- =======================================================================================
-- Database: all_syllabus
-- Target Platform: Supabase (PostgreSQL)
-- Description: Complete RTU Kota B.Tech Syllabus Database (1st Year Common, CSE, and AI & DS)
--              Includes Courses, Units, Detailed Topics, High-Yield Exam Annotations,
--              Laboratory Curricula, Recommended Textbooks, and Open Electives.
-- =======================================================================================

-- 1. EXTENSIONS & SCHEMAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. DROP TABLES IF EXISTS (CASCADE)
DROP VIEW IF EXISTS view_subject_summary CASCADE;
DROP VIEW IF EXISTS view_lab_curriculum CASCADE;
DROP VIEW IF EXISTS view_high_yield_topics CASCADE;
DROP VIEW IF EXISTS view_all_syllabus CASCADE;

DROP TABLE IF EXISTS open_electives CASCADE;
DROP TABLE IF EXISTS recommended_books CASCADE;
DROP TABLE IF EXISTS lab_experiments CASCADE;
DROP TABLE IF EXISTS topics CASCADE;
DROP TABLE IF EXISTS course_units CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS semesters CASCADE;
DROP TABLE IF EXISTS branches CASCADE;

-- 3. ENUMS & DOMAINS
DO $$ BEGIN
    CREATE TYPE course_category_type AS ENUM ('BSC', 'ESC', 'HSMC', 'PCC', 'PEC', 'OE', 'PSIT', 'FEC');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE course_delivery_type AS ENUM ('THEORY', 'PRACTICAL', 'SESSIONAL', 'PROJECT', 'SEMINAR');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE importance_level_type AS ENUM ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE exam_frequency_type AS ENUM ('VERY_FREQUENT', 'FREQUENT', 'OCCASIONAL');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE book_category_type AS ENUM ('TEXT_BOOK', 'REFERENCE_BOOK');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 4. TABLE DEFINITIONS

-- 4.1 Branches Table
CREATE TABLE branches (
    id VARCHAR(20) PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    university VARCHAR(255) DEFAULT 'Rajasthan Technical University, Kota',
    degree VARCHAR(50) DEFAULT 'B.Tech',
    effective_session VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4.2 Semesters Table
CREATE TABLE semesters (
    id SERIAL PRIMARY KEY,
    branch_id VARCHAR(20) NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    semester_number INT NOT NULL CHECK (semester_number BETWEEN 1 AND 8),
    year_number INT NOT NULL CHECK (year_number BETWEEN 1 AND 4),
    academic_title VARCHAR(100) NOT NULL,
    UNIQUE(branch_id, semester_number)
);

-- 4.3 Courses Table
CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    semester_id INT NOT NULL REFERENCES semesters(id) ON DELETE CASCADE,
    branch_id VARCHAR(20) NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    course_code VARCHAR(30) NOT NULL,
    course_title VARCHAR(255) NOT NULL,
    category course_category_type NOT NULL,
    delivery_type course_delivery_type NOT NULL,
    credits NUMERIC(3, 1) NOT NULL,
    lecture_hours INT DEFAULT 0,
    tutorial_hours INT DEFAULT 0,
    practical_hours INT DEFAULT 0,
    exam_hours INT DEFAULT 3,
    ia_marks INT NOT NULL DEFAULT 30,
    ete_marks INT NOT NULL DEFAULT 70,
    total_marks INT NOT NULL DEFAULT 100,
    course_objectives TEXT[],
    course_outcomes TEXT[],
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(semester_id, course_code)
);

-- 4.4 Course Units Table
CREATE TABLE course_units (
    id SERIAL PRIMARY KEY,
    course_id INT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    unit_number INT NOT NULL,
    unit_title VARCHAR(255) NOT NULL,
    lecture_hours INT NOT NULL DEFAULT 0,
    description TEXT,
    UNIQUE(course_id, unit_number)
);

-- 4.5 Topics Table (with RTU Exam Importance & High Yield Analysis)
CREATE TABLE topics (
    id SERIAL PRIMARY KEY,
    unit_id INT NOT NULL REFERENCES course_units(id) ON DELETE CASCADE,
    topic_title VARCHAR(255) NOT NULL,
    topic_description TEXT,
    is_high_yield BOOLEAN DEFAULT FALSE,
    importance_level importance_level_type DEFAULT 'MEDIUM',
    exam_frequency exam_frequency_type DEFAULT 'OCCASIONAL',
    rtu_exam_tips TEXT,
    key_concepts TEXT[],
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4.6 Lab Experiments Table
CREATE TABLE lab_experiments (
    id SERIAL PRIMARY KEY,
    course_id INT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    experiment_number INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    tools_used VARCHAR(255),
    UNIQUE(course_id, experiment_number)
);

-- 4.7 Recommended Books Table
CREATE TABLE recommended_books (
    id SERIAL PRIMARY KEY,
    course_id INT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    book_type book_category_type NOT NULL,
    title VARCHAR(255) NOT NULL,
    authors VARCHAR(255),
    publisher VARCHAR(255),
    edition_year VARCHAR(50)
);

-- 4.8 Open Electives Catalog
CREATE TABLE open_electives (
    id SERIAL PRIMARY KEY,
    semester_number INT NOT NULL CHECK (semester_number IN (7, 8)),
    elective_group VARCHAR(50) NOT NULL,
    subject_code VARCHAR(30) NOT NULL,
    title VARCHAR(255) NOT NULL,
    department VARCHAR(100) NOT NULL
);

-- 5. INDEXES FOR PERFORMANCE & SUPABASE SEARCH
CREATE INDEX idx_courses_branch_sem ON courses(branch_id, semester_id);
CREATE INDEX idx_courses_code ON courses(course_code);
CREATE INDEX idx_course_units_course ON course_units(course_id);
CREATE INDEX idx_topics_unit ON topics(unit_id);
CREATE INDEX idx_topics_high_yield ON topics(is_high_yield) WHERE is_high_yield = TRUE;
CREATE INDEX idx_topics_importance ON topics(importance_level);
CREATE INDEX idx_lab_experiments_course ON lab_experiments(course_id);
CREATE INDEX idx_recommended_books_course ON recommended_books(course_id);

-- Full text search indexes (trigram)
CREATE INDEX idx_courses_title_trgm ON courses USING gin (course_title gin_trgm_ops);
CREATE INDEX idx_topics_title_trgm ON topics USING gin (topic_title gin_trgm_ops);

-- 6. VIEWS FOR SUPABASE / FRONTEND CONSUMPTION

-- View 1: Unified Syllabus View
CREATE OR REPLACE VIEW view_all_syllabus AS
SELECT 
    b.name AS branch_name,
    b.code AS branch_code,
    s.semester_number,
    s.year_number,
    c.course_code,
    c.course_title,
    c.category AS course_category,
    c.delivery_type,
    c.credits,
    cu.unit_number,
    cu.unit_title,
    cu.lecture_hours AS unit_hours,
    t.topic_title,
    t.topic_description,
    t.is_high_yield,
    t.importance_level,
    t.exam_frequency,
    t.rtu_exam_tips
FROM branches b
JOIN semesters s ON s.branch_id = b.id
JOIN courses c ON c.semester_id = s.id
JOIN course_units cu ON cu.course_id = c.id
LEFT JOIN topics t ON t.unit_id = cu.id
ORDER BY b.id, s.semester_number, c.course_code, cu.unit_number, t.id;

-- View 2: High Yield Exam Preparation View
CREATE OR REPLACE VIEW view_high_yield_topics AS
SELECT 
    b.code AS branch,
    s.semester_number AS sem,
    c.course_code,
    c.course_title,
    cu.unit_number AS unit,
    cu.unit_title,
    t.topic_title,
    t.importance_level,
    t.exam_frequency,
    t.rtu_exam_tips,
    t.key_concepts
FROM topics t
JOIN course_units cu ON t.unit_id = cu.id
JOIN courses c ON cu.course_id = c.id
JOIN semesters s ON c.semester_id = s.id
JOIN branches b ON s.branch_id = b.id
WHERE t.is_high_yield = TRUE
ORDER BY s.semester_number, c.course_code, cu.unit_number;

-- View 3: Practical & Laboratory Curriculum View
CREATE OR REPLACE VIEW view_lab_curriculum AS
SELECT 
    b.name AS branch_name,
    s.semester_number,
    c.course_code,
    c.course_title,
    c.credits,
    le.experiment_number,
    le.title AS experiment_title,
    le.description AS experiment_description,
    le.tools_used
FROM lab_experiments le
JOIN courses c ON le.course_id = c.id
JOIN semesters s ON c.semester_id = s.id
JOIN branches b ON s.branch_id = b.id
ORDER BY b.id, s.semester_number, c.course_code, le.experiment_number;

-- View 4: Course Summary View
CREATE OR REPLACE VIEW view_subject_summary AS
SELECT 
    b.code AS branch,
    s.semester_number AS sem,
    c.course_code,
    c.course_title,
    c.category,
    c.delivery_type,
    c.credits,
    c.ia_marks,
    c.ete_marks,
    c.total_marks,
    COUNT(DISTINCT cu.id) AS total_units,
    COUNT(DISTINCT t.id) AS total_topics,
    COUNT(DISTINCT CASE WHEN t.is_high_yield THEN t.id END) AS high_yield_topics_count
FROM courses c
JOIN semesters s ON c.semester_id = s.id
JOIN branches b ON s.branch_id = b.id
LEFT JOIN course_units cu ON cu.course_id = c.id
LEFT JOIN topics t ON t.unit_id = cu.id
GROUP BY b.code, s.semester_number, c.course_code, c.course_title, c.category, c.delivery_type, c.credits, c.ia_marks, c.ete_marks, c.total_marks
ORDER BY b.code, s.semester_number, c.course_code;

-- 7. ROW LEVEL SECURITY (RLS) FOR SUPABASE
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE semesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE recommended_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE open_electives ENABLE ROW LEVEL SECURITY;

-- Allow public read access to all syllabus information
CREATE POLICY "Public Read Access for Branches" ON branches FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Semesters" ON semesters FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Courses" ON courses FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Course Units" ON course_units FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Topics" ON topics FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Lab Experiments" ON lab_experiments FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Books" ON recommended_books FOR SELECT USING (true);
CREATE POLICY "Public Read Access for Open Electives" ON open_electives FOR SELECT USING (true);

-- =======================================================================================
-- 8. DATA INSERTIONS: COMPLETE SYLLABI POPULATION
-- =======================================================================================

BEGIN;

-- 8.1 Branches
INSERT INTO branches (id, code, name, university, degree, effective_session) VALUES
('FY_COMMON', 'FY', 'First Year Common Engineering', 'Rajasthan Technical University, Kota', 'B.Tech', '2024-25 onwards'),
('CSE_RTU', 'CS', 'Computer Science and Engineering', 'Rajasthan Technical University, Kota', 'B.Tech', '2023-24 / 2024-25 onwards'),
('AI_DS_RTU', 'AID', 'Artificial Intelligence and Data Science', 'Rajasthan Technical University, Kota', 'B.Tech', '2023-24 / 2024-25 onwards');

-- 8.2 Semesters
-- First Year
INSERT INTO semesters (id, branch_id, semester_number, year_number, academic_title) VALUES
(101, 'FY_COMMON', 1, 1, 'I Semester (First Year Common)'),
(102, 'FY_COMMON', 2, 1, 'II Semester (First Year Common)'),
-- CSE Semesters (3 to 8)
(203, 'CSE_RTU', 3, 2, 'II Year - III Semester: B.Tech Computer Science and Engineering'),
(204, 'CSE_RTU', 4, 2, 'II Year - IV Semester: B.Tech Computer Science and Engineering'),
(205, 'CSE_RTU', 5, 3, 'III Year - V Semester: B.Tech Computer Science and Engineering'),
(206, 'CSE_RTU', 6, 3, 'III Year - VI Semester: B.Tech Computer Science and Engineering'),
(207, 'CSE_RTU', 7, 4, 'IV Year - VII Semester: B.Tech Computer Science and Engineering'),
(208, 'CSE_RTU', 8, 4, 'IV Year - VIII Semester: B.Tech Computer Science and Engineering'),
-- AI & Data Science Semesters (3 to 8)
(303, 'AI_DS_RTU', 3, 2, 'II Year - III Semester: B.Tech Artificial Intelligence and Data Science'),
(304, 'AI_DS_RTU', 4, 2, 'II Year - IV Semester: B.Tech Artificial Intelligence and Data Science'),
(305, 'AI_DS_RTU', 5, 3, 'III Year - V Semester: B.Tech Artificial Intelligence and Data Science'),
(306, 'AI_DS_RTU', 6, 3, 'III Year - VI Semester: B.Tech Artificial Intelligence and Data Science'),
(307, 'AI_DS_RTU', 7, 4, 'IV Year - VII Semester: B.Tech Artificial Intelligence and Data Science'),
(308, 'AI_DS_RTU', 8, 4, 'IV Year - VIII Semester: B.Tech Artificial Intelligence and Data Science');


-- =======================================================================================
-- 8.3 FIRST YEAR COURSES, UNITS, TOPICS & LABS (Common to All Branches)
-- =======================================================================================

-- 1FY2-01: Engineering Mathematics-I
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1001, 101, 'FY_COMMON', '1FY2-01', 'Engineering Mathematics-I', 'BSC', 'THEORY', 4.0, 3, 1, 0, 3, 30, 70, 100);

INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(10011, 1001, 1, 'Calculus', 8, 'Improper integrals (Beta and Gamma functions) and properties; Definite integrals applications.'),
(10012, 1001, 2, 'Sequences and Series', 8, 'Convergence of sequence and series, tests for convergence, Power series, Taylor series.'),
(10013, 1001, 3, 'Fourier Series', 8, 'Periodic functions, Fourier series, Euler formula, Change of intervals, Half range series, Parseval theorem.'),
(10014, 1001, 4, 'Multivariable Calculus (Differentiation)', 8, 'Limit, continuity, partial derivatives, Maxima/minima, Lagrange multipliers, Gradient/curl/div.'),
(10015, 1001, 5, 'Multivariable Calculus (Integration)', 8, 'Multiple Integration, Change of order/variables, Green, Gauss, and Stokes Theorems.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(10011, 'Beta and Gamma Functions', 'Properties, relations and evaluations of improper integrals using Beta-Gamma definitions.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Direct numerical proof on Beta(m,n) and Gamma(n) relation is repeated nearly every year.', ARRAY['Beta Function', 'Gamma Function', 'Improper Integrals', 'Definite Integrals']),
(10012, 'Convergence Tests of Series', 'Ratio test, Root test, Comparison test, Raabe test, and alternating series Leibniz test.', TRUE, 'HIGH', 'VERY_FREQUENT', 'D-Alembert ratio test and Cauchy root test problems carry guaranteed 7-mark questions.', ARRAY['Ratio Test', 'Root Test', 'Convergence', 'Power Series']),
(10013, 'Fourier Series & Half Range Expansions', 'Expansion of odd/even functions, Dirichlet conditions, half range sine/cosine series.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Derivation and expansion over [-pi, pi] or [0, 2L] with Parsevals identity.', ARRAY['Fourier Series', 'Eulers Formula', 'Half Range Series', 'Parseval Theorem']),
(10014, 'Maxima, Minima & Lagrange Multipliers', 'Finding extreme values of multi-variable functions subject to constraints using Lagrange method.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Lagrange Multiplier constrained optimization problem is high probability in section C.', ARRAY['Partial Derivatives', 'Saddle Points', 'Lagrange Multipliers', 'Gradient Curl Divergence']),
(10015, 'Vector Integral Theorems (Green, Gauss, Stokes)', 'Verification and direct line/surface/volume evaluation using Gauss Divergence, Stokes, and Green theorems.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'One guaranteed 14-mark question on verifying either Gauss Divergence or Stokes Theorem.', ARRAY['Green Theorem', 'Gauss Divergence Theorem', 'Stokes Theorem', 'Double Integrals']);

-- 1FY2-02 / 2FY2-02: Engineering Physics
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1002, 101, 'FY_COMMON', '1FY2-02/2FY2-02', 'Engineering Physics', 'BSC', 'THEORY', 4.0, 3, 1, 0, 3, 30, 70, 100);

INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(10021, 1002, 1, 'Wave Optics', 8, 'Newtons Rings, Michelson Interferometer, Fraunhofer diffraction, Grating, Resolving power.'),
(10022, 1002, 2, 'Quantum Mechanics', 8, 'Wave-particle duality, Schrodinger wave equations, Particle in 1D and 3D boxes.'),
(10023, 1002, 3, 'Coherence and Optical Fibers', 6, 'Spatial and temporal coherence, Optical fibers, Numerical aperture, Acceptance angle.'),
(10024, 1002, 4, 'Laser', 6, 'Einsteins coefficients, Population inversion, He-Ne Laser, Semiconductor Laser.'),
(10025, 1002, 5, 'Material Science & Semiconductor Physics', 6, 'Energy bands, Fermi Dirac distribution, Conductivity, Hall Effect and applications.'),
(10026, 1002, 6, 'Introduction to Electromagnetism', 6, 'Laplace/Poisson equations, Biot-Savart, Faradays law, Maxwell equations, Poynting vector.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(10021, 'Newtons Rings & Diffraction Grating', 'Formula derivation for dark/bright fringe diameters, wavelength determination, resolving power.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Derivation of diameter of dark/bright rings is a top-ranked RTU question.', ARRAY['Newtons Rings', 'Interference', 'Diffraction Grating', 'Resolving Power']),
(10022, 'Schrodingers Wave Equation & 1D Box', 'Time-dependent/independent wave equation derivation, energy eigenvalues for 1D potential well.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Particle in 1D box wave functions and zero-point energy derivation is extremely frequent.', ARRAY['Schrodinger Equation', 'Wave Function', '1D Box', 'Quantum Mechanics']),
(10023, 'Optical Fiber & Numerical Aperture', 'Step-index/Graded-index fiber, acceptance angle, derivation of Numerical Aperture (NA).', TRUE, 'HIGH', 'VERY_FREQUENT', 'Formula derivation for NA = sqrt(n1^2 - n2^2) and numericals.', ARRAY['Numerical Aperture', 'Acceptance Angle', 'Coherence Length', 'Optical Fiber']),
(10024, 'He-Ne Laser & Einstein Coefficients', 'Four-level laser system, optical pumping mechanism, Einstein A and B coefficient relationship.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Construction and energy level working diagram of He-Ne laser.', ARRAY['He-Ne Laser', 'Population Inversion', 'Einstein Coefficients', 'Stimulated Emission']),
(10025, 'Hall Effect in Semiconductors', 'Hall coefficient derivation, Hall voltage, determination of carrier type and carrier mobility.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Derivation of Hall coefficient Rh = 1/(n*e) and experimental setup.', ARRAY['Hall Effect', 'Hall Coefficient', 'Fermi Level', 'Intrinsic Semiconductor']),
(10026, 'Maxwells Equations & Poynting Vector', 'Integral and differential forms of 4 Maxwell equations, physical significance, Poynting theorem.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Derivation of Maxwells equations and displacement current explanation.', ARRAY['Maxwells Equations', 'Displacement Current', 'Poynting Vector', 'Electromagnetism']);

-- 1FY2-03 / 2FY2-03: Engineering Chemistry
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1003, 101, 'FY_COMMON', '1FY2-03/2FY2-03', 'Engineering Chemistry', 'BSC', 'THEORY', 4.0, 3, 1, 0, 3, 30, 70, 100);

INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(10031, 1003, 1, 'Water Chemistry & Softening', 8, 'Hardness (EDTA method), Municipal water, Boiler troubles, Zeolite & Demineralization processes.'),
(10032, 1003, 2, 'Organic Fuels', 8, 'Coal proximate/ultimate analysis, Bomb calorimeter, Octane/Cetane number, Junkers calorimeter.'),
(10033, 1003, 3, 'Corrosion & Control', 6, 'Mechanism of wet/dry corrosion, Galvanic/Pitting corrosion, Galvanization, Cathodic protection.'),
(10034, 1003, 4, 'Engineering Materials', 6, 'Portland Cement manufacture & setting, Glass annealing, Lubricants classification & properties.'),
(10035, 1003, 5, 'Organic Reaction Mechanisms & Drugs', 6, 'SN1, SN2 mechanisms, Free radical, Aspirin & Paracetamol synthesis.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(10031, 'Water Softening: Zeolite & Demineralization', 'Ion-exchange resin and zeolite bed processes, chemical reactions, regeneration, and hardness calculations.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'EDTA numerical and Zeolite/Demineralization diagram & comparison are guaranteed.', ARRAY['EDTA Hardness', 'Zeolite Process', 'Demineralization', 'Boiler Corrosion']),
(10032, 'Calorific Value & Bomb Calorimeter', 'Gross vs Net calorific value (GCV/NCV), Bomb calorimeter working, Dulongs formula calculations.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Bomb calorimeter numerical and coal proximate analysis calculations.', ARRAY['Bomb Calorimeter', 'Proximate Analysis', 'Octane Number', 'Calorific Value']),
(10033, 'Corrosion Mechanisms & Cathodic Protection', 'Electrochemical mechanism (evolution of H2, absorption of O2), sacrificial anode and impressed current.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Galvanic corrosion vs Concentration cell corrosion with sacrificial cathodic protection.', ARRAY['Electrochemical Corrosion', 'Galvanizing', 'Cathodic Protection', 'Sacrificial Anode']),
(10034, 'Portland Cement Manufacturing & Setting', 'Rotary kiln process, chemical composition, reactions involved in initial and final setting of cement.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Manufacturing flow diagram and role of Gypsum in cement setting.', ARRAY['Portland Cement', 'Rotary Kiln', 'Lubricants', 'Flash Point']),
(10035, 'Synthesis of Aspirin and Paracetamol', 'Chemical reaction pathways, reagents, properties, and applications of Aspirin and Paracetamol.', TRUE, 'HIGH', 'FREQUENT', 'Reaction steps for Aspirin from salicylic acid and Paracetamol from p-aminophenol.', ARRAY['Aspirin Synthesis', 'Paracetamol', 'SN1 vs SN2', 'Reaction Mechanisms']);

-- 1FY3-06 / 2FY3-06: Programming for Problem Solving (PPS - C Programming)
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1004, 101, 'FY_COMMON', '1FY3-06/2FY3-06', 'Programming for Problem Solving', 'ESC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100);

INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(10041, 1004, 1, 'Fundamentals of Computer & Algorithms', 6, 'Stored program architecture, Memory hierarchy, Flowcharts, Pseudo-code.'),
(10042, 1004, 2, 'Number Systems & Data Representation', 6, 'Radix conversions, 1s and 2s complements, Binary arithmetic, Character encoding.'),
(10043, 1004, 3, 'C Programming Constructs & Memory Management', 16, 'Conditionals, Loops, Arrays, Functions, Recursion, Pointers, Structures, File I/O.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(10042, 'Number System Conversions & Complements', 'Binary, octal, decimal, hex interconversions, r-1 and r complement arithmetic.', TRUE, 'HIGH', 'VERY_FREQUENT', '2s complement subtraction questions are recurring in Section A and B.', ARRAY['Binary Arithmetic', '2s Complement', 'Hexadecimal', 'Radix Conversion']),
(10043, 'Pointers, Dynamic Memory & Structures in C', 'Pointer arithmetic, pointers to pointers, malloc/calloc/free, structures vs unions.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Call by value vs call by reference with swap program and structure padding.', ARRAY['Pointers', 'Structures', 'Dynamic Allocation', 'Recursion', 'File Handling']);

-- 2FY2-01: Engineering Mathematics-II
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1005, 102, 'FY_COMMON', '2FY2-01', 'Engineering Mathematics-II', 'BSC', 'THEORY', 4.0, 3, 1, 0, 3, 30, 70, 100);

INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(10051, 1005, 1, 'Matrices & Linear Algebra', 8, 'Rank, Rank-nullity, Linear equations, Eigenvalues/vectors, Cayley-Hamilton theorem, Diagonalization.'),
(10052, 1005, 2, 'First Order Ordinary Differential Equations', 8, 'Exact equations, Bernoullis equations, Solvable for p/y/x, Clairauts form.'),
(10053, 1005, 3, 'Higher Order Linear Differential Equations', 8, 'Homogeneous/Exact forms, Variation of parameters, Cauchy-Euler, Power series, Bessel/Legendre.'),
(10054, 1005, 4, 'First Order Partial Differential Equations', 8, 'Lagranges linear PDE, Non-linear first order PDE, Charpits method.'),
(10055, 1005, 5, 'Higher Order PDEs & Applications', 8, 'Separation of variables, 1D Heat equation, 1D Wave equation, 2D Laplace equation.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(10051, 'Eigenvalues, Eigenvectors & Cayley-Hamilton', 'Finding characteristic equation, eigenvalues, eigenvectors, matrix powers and inverse via Cayley-Hamilton.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Cayley-Hamilton verification and computing A^-1 or A^8 is asked every single year.', ARRAY['Cayley-Hamilton', 'Eigenvalues', 'Diagonalization', 'Rank of Matrix']),
(10053, 'Method of Variation of Parameters & Cauchy-Euler', 'Solving 2nd order ODEs using wronskian method of variation of parameters and homogeneous Cauchy-Euler.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Variation of parameters method numerical is a fixed 14-mark question in RTU exams.', ARRAY['Variation of Parameters', 'Cauchy-Euler', 'Wronskian', 'Bessel Functions']),
(10054, 'Charpits Method for Non-Linear PDEs', 'Forming auxiliary equations, integration to find complete integral of f(x,y,z,p,q)=0.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Charpits method for non-linear first-order PDE is one of the highest scoring recurring questions.', ARRAY['Charpits Method', 'Lagranges Linear Form', 'Partial Differential Equations']),
(10055, 'Wave & Heat Equation by Separation of Variables', 'Solving 1D Wave equation (vibrating string) and 1D Heat conduction with boundary conditions.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Derivation of 1D wave equation solution using Fourier boundary conditions.', ARRAY['Separation of Variables', '1D Heat Equation', '1D Wave Equation', 'Laplace Equation']);

-- First Year Common Engineering Subjects (Electrical, Civil, Mechanical, Human Values, Communication)
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1006, 101, 'FY_COMMON', '1FY3-08/2FY3-08', 'Basic Electrical Engineering', 'ESC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(1007, 101, 'FY_COMMON', '1FY3-07/2FY3-07', 'Basic Mechanical Engineering', 'ESC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(1008, 101, 'FY_COMMON', '1FY3-09/2FY3-09', 'Basic Civil Engineering', 'ESC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(1009, 101, 'FY_COMMON', '1FY1-05/2FY1-05', 'Human Values', 'HSMC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(1010, 101, 'FY_COMMON', '1FY1-04/2FY1-04', 'Communication Skills', 'HSMC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100);

-- Labs for 1st Year
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(1020, 101, 'FY_COMMON', '1FY2-20/2FY2-20', 'Engineering Physics Lab', 'BSC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(1021, 101, 'FY_COMMON', '1FY2-21/2FY2-21', 'Engineering Chemistry Lab', 'BSC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(1022, 101, 'FY_COMMON', '1FY2-22/2FY2-22', 'Language Lab', 'HSMC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(1023, 101, 'FY_COMMON', '1FY1-23/2FY1-23', 'Human Values Activities', 'HSMC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(1024, 101, 'FY_COMMON', '1FY3-24/2FY3-24', 'Computer Programming Lab', 'ESC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(1025, 101, 'FY_COMMON', '1FY3-25/2FY3-25', 'Manufacturing Practices Workshop', 'ESC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(1026, 101, 'FY_COMMON', '1FY3-26/2FY3-26', 'Basic Electrical Engineering Lab', 'ESC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(1027, 101, 'FY_COMMON', '1FY3-27/2FY3-27', 'Basic Civil Engineering Lab', 'ESC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(1028, 101, 'FY_COMMON', '1FY3-28/2FY3-28', 'Computer Aided Engineering Graphics', 'ESC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(1029, 101, 'FY_COMMON', '1FY3-29/2FY3-29', 'Computer Aided Machine Drawing', 'ESC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100);

-- Experiments for PPS Lab
INSERT INTO lab_experiments (course_id, experiment_number, title, description, tools_used) VALUES
(1024, 1, 'Preprocessor and I/O Basics', 'To learn about C Library, Preprocessor directive, and formatted Input-output statements.', 'GCC / Turbo C / CodeBlocks'),
(1024, 2, 'Data Types & Branching', 'Programs to implement variables, data types, and if-else decision statements.', 'C Compiler'),
(1024, 3, 'Switch & Nested Conditions', 'Programs to implement nested if-else structure and multi-branch switch cases.', 'C Compiler'),
(1024, 4, 'Iterative Loops (While, Do-While)', 'Programs to learn iterative control statements using while and do-while loops.', 'C Compiler'),
(1024, 5, 'For Loops & Patterns', 'Programs using for loops to generate numerical series and triangular matrix patterns.', 'C Compiler'),
(1024, 6, 'Arrays & String Manipulations', 'Programs for 1D and 2D arrays, matrix multiplication, and string manipulation without library functions.', 'C Compiler'),
(1024, 7, 'Sorting & Searching', 'Implementation of Linear Search, Binary Search, and Bubble Sort on arrays.', 'C Compiler'),
(1024, 8, 'Functions & Recursion', 'Programs implementing user defined functions and recursive mathematical computations (Factorial, Fibonacci, GCD).', 'C Compiler'),
(1024, 9, 'Structures & Unions', 'Programs creating complex records using structures and demonstrating union memory overlap.', 'C Compiler'),
(1024, 10, 'Pointer Operations', 'Programs performing pointer arithmetic, dynamic memory allocation, and passing pointers to functions.', 'C Compiler'),
(1024, 11, 'File Handling Operations', 'Reading and writing formatted text/binary files using fopen, fprintf, fscanf, and fclose.', 'C Compiler'),
(1024, 12, 'Command Line Arguments', 'Writing C programs that process argument vectors argc and argv passed via command terminal.', 'C Compiler');


-- =======================================================================================
-- 8.4 3RD SEMESTER (Common Core across AI & CSE)
-- =======================================================================================

-- Courses for Sem 3 (AI & CSE)
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
-- AID Sem 3
(2301, 303, 'AI_DS_RTU', '3AID2-01', 'Advanced Engineering Mathematics', 'BSC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2302, 303, 'AI_DS_RTU', '3AID1-02', 'Technical Communication', 'HSMC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(2303, 303, 'AI_DS_RTU', '3AID1-03', 'Managerial Economics and Financial Accounting', 'HSMC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(2304, 303, 'AI_DS_RTU', '3AID3-04', 'Digital Electronics', 'ESC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2305, 303, 'AI_DS_RTU', '3AID4-05', 'Data Structures and Algorithms', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2306, 303, 'AI_DS_RTU', '3AID4-06', 'Object Oriented Programming', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2307, 303, 'AI_DS_RTU', '3AID4-07', 'Software Engineering', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
-- CSE Sem 3
(2351, 203, 'CSE_RTU', '3CS2-01', 'Advanced Engineering Mathematics', 'BSC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2352, 203, 'CSE_RTU', '3CS1-02', 'Technical Communication', 'HSMC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(2353, 203, 'CSE_RTU', '3CS1-03', 'Managerial Economics and Financial Accounting', 'HSMC', 'THEORY', 2.0, 2, 0, 0, 2, 30, 70, 100),
(2354, 203, 'CSE_RTU', '3CS3-04', 'Digital Electronics', 'ESC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2355, 203, 'CSE_RTU', '3CS4-05', 'Data Structures and Algorithms', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2356, 203, 'CSE_RTU', '3CS4-06', 'Object Oriented Programming', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2357, 203, 'CSE_RTU', '3CS4-07', 'Software Engineering', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100);

-- Units & Topics for Data Structures & Algorithms (3AID4-05 & 3CS4-05)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(23051, 2305, 1, 'Stacks & Applications', 8, 'Basic stack operations, static/dynamic arrays, multiple stack in single array, infix-to-postfix conversion, Tower of Hanoi.'),
(23052, 2305, 2, 'Queues & Linked Lists', 10, 'Circular queue, Dequeue, Priority Queue, Singly, Doubly, and Circular Linked Lists operations.'),
(23053, 2305, 3, 'Searching & Sorting Techniques', 7, 'Sequential & Binary Search, Bubble, Selection, Insertion, Quick, Merge, Heap, Radix, Counting sort.'),
(23054, 2305, 4, 'Trees & Binary Search Trees', 7, 'Tree traversals, Binary Search Tree (BST), AVL trees, B-Trees, B+ Trees, Threaded binary trees.'),
(23055, 2305, 5, 'Graphs & Hashing', 8, 'BFS, DFS, Prims & Kruskals MST, Dijkstras algorithm, Hash functions, Collision resolution techniques.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(23051, 'Infix to Postfix & Expression Evaluation', 'Stack algorithms for operator precedence, associativity, and postfix evaluation.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Algorithm + manual tracing table with given arithmetic expression is a guaranteed 7-mark question.', ARRAY['Stack', 'Infix to Postfix', 'Tower of Hanoi', 'Array Representation']),
(23052, 'Circular Queue & Doubly Linked List', 'Circular queue boundary conditions (front = (rear+1)%size), reversal and insertion in linked lists.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Circular queue overflow/underflow algorithms and linked list node reversal.', ARRAY['Circular Queue', 'Priority Queue', 'Doubly Linked List', 'Header List']),
(23053, 'Quick Sort & Merge Sort Analysis', 'Divide and conquer partitioning, recursive recurrence relations, best and worst-case time complexities.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Quick Sort partition algorithm + worst case O(n^2) proof is repeatedly asked.', ARRAY['Quick Sort', 'Merge Sort', 'Heap Sort', 'Radix Sort', 'Binary Search']),
(23054, 'AVL Tree Rotations & BST Operations', 'Height balancing (LL, RR, LR, RL rotations), BST node insertion and deletion cases.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Constructing AVL tree step-by-step with given numbers and showing rotations.', ARRAY['AVL Trees', 'BST', 'Tree Traversals', 'B-Tree', 'B+ Tree']),
(23055, 'Dijkstras Shortest Path & Kruskals MST', 'Greedy shortest path algorithm, Minimum Spanning Tree using disjoint-set cycle check.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Step-by-step table execution of Dijkstras algorithm on a given weighted graph.', ARRAY['Dijkstras Algorithm', 'Prims Algorithm', 'Kruskals Algorithm', 'BFS', 'DFS', 'Hashing']);

-- Units & Topics for Digital Electronics (3AID3-04 & 3CS3-04)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(23041, 2304, 1, 'Number Systems & Boolean Algebra', 8, 'Sign magnitude, complements, Boolean postulates and theorems.'),
(23042, 2304, 2, 'Minimization Techniques', 8, 'SOP, POS, K-Map (up to 5 variables), Don’t care conditions, Quine-McCluskey (Tabulation) method.'),
(23043, 2304, 3, 'Logic Gate Characteristics & Families', 8, 'TTL NAND, Open collector, Tri-state logic, CMOS logic families, RTL, DTL, ECL.'),
(23044, 2304, 4, 'Combinational Logic Circuits', 8, 'Adders, Subtractors, BCD Adder, Encoders, Decoders, Multiplexers, Demultiplexers.'),
(23045, 2304, 5, 'Sequential Logic Circuits', 8, 'Latches, Flip-Flops (SR, JK, D, T, Master-Slave), Counters (Sync/Async), Shift Registers.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(23042, 'K-Map Minimization & Quine-McCluskey', 'Minimization of Boolean expressions with don’t cares using 4-variable K-Maps and Tabular Method.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Quine-McCluskey prime implicant table problem is an RTU exam staple.', ARRAY['K-Map', 'Quine-McCluskey', 'SOP', 'POS', 'Prime Implicants']),
(23044, 'Multiplexers & BCD Adder Circuit Design', 'Realization of logic functions using MUX, carry look-ahead adder, and BCD adder correction logic.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Design 8:1 MUX using 4:1 MUX and BCD adder circuit diagram with +6 correction logic.', ARRAY['Multiplexer', 'Decoder', 'BCD Adder', 'Full Adder']),
(23045, 'Master-Slave JK Flip Flop & Synchronous Counters', 'Race around condition elimination in JK flip-flop, excitation tables, state transition diagrams.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Explain race around condition in JK Flip Flop and how Master-Slave configuration solves it.', ARRAY['JK Flip Flop', 'Race Around Condition', 'Master-Slave', 'Synchronous Counter', 'Shift Registers']);

-- Units & Topics for Object Oriented Programming (3AID4-06 & 3CS4-06)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(23061, 2306, 1, 'OOP Paradigms & C++ Fundamentals', 8, 'Classes, Objects, Access specifiers, Array of objects, Member functions.'),
(23062, 2306, 2, 'Constructors, Destructors & Friend Functions', 8, 'Dynamic allocation (new/delete), Function overloading, Default args, Friend class/functions, this pointer.'),
(23063, 2306, 3, 'Inheritance & Virtual Base Classes', 9, 'Single/Multiple/Hierarchical inheritance, Virtual base class, Ambiguity resolution, Pure virtual functions.'),
(23064, 2306, 4, 'Polymorphism & Operator Overloading', 9, 'Unary and binary operator overloading, Dynamic binding, Virtual functions, VTABLE mechanism.'),
(23065, 2306, 5, 'Templates, Exception Handling & Files', 6, 'Class/Function templates, try-catch-throw, Stream classes, C++ File handling.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(23063, 'Virtual Base Class & Diamond Problem', 'Resolving multiple inheritance ambiguity with virtual keyword, abstract class definitions.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Diamond problem in C++ and virtual base class syntax with diagram.', ARRAY['Virtual Base Class', 'Multiple Inheritance', 'Abstract Class', 'Diamond Problem']),
(23064, 'Operator Overloading & Virtual Functions', 'Overloading +, -, <<, >> operators using member and friend functions, runtime polymorphism.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Overload binary operator using friend function + runtime polymorphism with virtual functions.', ARRAY['Operator Overloading', 'Virtual Function', 'Runtime Polymorphism', 'VTABLE']),
(23065, 'Templates & Exception Handling Mechanics', 'Generic programming with templates, standard template library basics, custom exception classes.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Class template syntax and multiple catch blocks with rethrowing exceptions.', ARRAY['Templates', 'Exception Handling', 'Try Catch', 'File Streams']);

-- Units & Topics for Software Engineering (3AID4-07 & 3CS4-07)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(23071, 2307, 1, 'Software Life-Cycle Models & SRS', 8, 'Waterfall, Spiral, Agile, RAD models, SRS format (IEEE 830), Verification & Validation.'),
(23072, 2307, 2, 'Software Project Management & COCOMO', 8, 'LOC, Function Points (FP), COCOMO (Basic, Intermediate, Detailed), Risk analysis, Scheduling.'),
(23073, 2307, 3, 'Requirement Analysis & Structured Analysis', 8, 'Data Flow Diagrams (DFD Level 0/1/2), Data Dictionary, Finite State Machines (FSM).'),
(23074, 2307, 4, 'Software Design Fundamentals', 8, 'Cohesion, Coupling, Architectural design, Modular decomposition.'),
(23075, 2307, 5, 'Object Oriented Design & UML', 8, 'Class diagrams, Use Case diagrams, Sequence diagrams, Statechart diagrams.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(23071, 'Spiral Model & Waterfall vs Agile', 'Phased lifecycle models, risk-driven development in Spiral model, Agile manifesto principles.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Detailed diagram and explanation of Spiral model including risk analysis quadrant.', ARRAY['Spiral Model', 'Waterfall Model', 'Agile', 'SRS Document']),
(23072, 'COCOMO Model & Function Point Calculation', 'Cost and effort estimation formulas for Organic, Semidetached, and Embedded software systems.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Numerical on Basic and Intermediate COCOMO to calculate Effort (Person-Months) and Time.', ARRAY['COCOMO Model', 'Function Points', 'Effort Estimation', 'Project Scheduling']),
(23074, 'Cohesion and Coupling in Modular Design', 'Types of cohesion (Coincidental to Functional) and coupling (Data to Content), principles of good design.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare all types of Cohesion and Coupling from best to worst with examples.', ARRAY['Cohesion', 'Coupling', 'Modularity', 'Software Architecture']);

-- Labs for Sem 3
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(2321, 303, 'AI_DS_RTU', '3AID4-21', 'Data Structures and Algorithms Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2322, 303, 'AI_DS_RTU', '3AID4-22', 'Object Oriented Programming Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2323, 303, 'AI_DS_RTU', '3AID4-23', 'Software Engineering Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2324, 303, 'AI_DS_RTU', '3AID4-24', 'Digital Electronics Lab', 'ESC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2371, 203, 'CSE_RTU', '3CS4-21', 'Data Structures and Algorithms Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2372, 203, 'CSE_RTU', '3CS4-22', 'Object Oriented Programming Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2373, 203, 'CSE_RTU', '3CS4-23', 'Software Engineering Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2374, 203, 'CSE_RTU', '3CS4-24', 'Digital Electronics Lab', 'ESC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100);

-- DSA Lab Experiments
INSERT INTO lab_experiments (course_id, experiment_number, title, description, tools_used) VALUES
(2321, 1, 'Array Storage & Row/Column Major Address Calculation', 'Write a C program on 32-bit compiler calculating theoretical vs simulated memory addresses for arrays up to 4D.', 'C / GCC'),
(2321, 2, 'Array Implementation of Stack and Queues', 'Simulate Stack, Linear Queue, Circular Queue, and Deque operations using 1D arrays.', 'C / GCC'),
(2321, 3, 'Polynomial Addition Using Arrays', 'Represent 2-variable polynomials using array structures and implement polynomial addition.', 'C / GCC'),
(2321, 4, 'Sparse Matrix Representation & Transposition', 'Represent sparse matrices using 3-tuple array format and implement fast transposition.', 'C / GCC'),
(2321, 5, 'Linked List Operations (Singly, Doubly, Circular)', 'Implement insertion, deletion from specific locations, and reversal in Singly and Doubly linked lists.', 'C / GCC'),
(2321, 6, 'Binary Search Tree Traversals', 'Build a BST with insertion, deletion, and recursive Inorder, Preorder, and Postorder traversals.', 'C / GCC'),
(2321, 7, 'Graph Traversal (BFS & DFS)', 'Perform Depth First Search and Breadth First Search using adjacency matrix and adjacency list.', 'C / GCC'),
(2321, 8, 'Binary Search & Sorting Implementations', 'Implementation of Binary Search, Quick Sort, Merge Sort, and Heap Sort.', 'C / GCC');


-- =======================================================================================
-- 8.5 4TH SEMESTER (Core Subjects: DBMS, TOC, DCCN, Microprocessor, Discrete Maths)
-- =======================================================================================

-- Courses for Sem 4 (AI & CSE)
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
-- AID Sem 4
(2401, 304, 'AI_DS_RTU', '4AID2-01', 'Discrete Mathematics Structure', 'BSC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2402, 304, 'AI_DS_RTU', '4AID3-04', 'Microprocessor & Interfaces', 'ESC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2403, 304, 'AI_DS_RTU', '4AID4-05', 'Database Management System', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2404, 304, 'AI_DS_RTU', '4AID4-06', 'Theory Of Computation', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2405, 304, 'AI_DS_RTU', '4AID4-07', 'Data Communication and Computer Networks', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
-- CSE Sem 4
(2451, 204, 'CSE_RTU', '4CS2-01', 'Discrete Mathematics Structure', 'BSC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2452, 204, 'CSE_RTU', '4CS3-04', 'Microprocessor & Interfaces', 'ESC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2453, 204, 'CSE_RTU', '4CS4-05', 'Database Management System', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2454, 204, 'CSE_RTU', '4CS4-06', 'Theory Of Computation', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2455, 204, 'CSE_RTU', '4CS4-07', 'Data Communication and Computer Networks', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100);

-- Units & Topics for DBMS (4AID4-05 & 4CS4-05)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(24031, 2403, 1, 'Introduction to DBMS & ER Model', 8, 'File System vs DBMS, Database Architecture, ER Diagrams, Weak entities, Aggregation.'),
(24032, 2403, 2, 'Relational Algebra, Calculus & SQL', 8, 'Selection, Projection, Joins, Relational Calculus, SQL DDL/DML, Nested queries, Triggers, Views.'),
(24033, 2403, 3, 'Schema Refinement & Normalization', 8, 'Functional dependencies, 1NF, 2NF, 3NF, BCNF decomposition, Lossless join, Dependency preservation.'),
(24034, 2403, 4, 'Transaction Management & Concurrency Control', 8, 'ACID properties, Serializability (Conflict & View), Testing serializability, Recoverability.'),
(24035, 2403, 5, 'Locking Protocols & Crash Recovery', 8, 'Two-Phase Locking (2PL), Timestamp ordering, Deadlocks, Shadow Paging, Log-based Recovery (ARIES).');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(24031, 'ER Diagram Design & Cardinality Constraints', 'Entity sets, relationship sets, weak entities, generalization, and mapping ER models to relational tables.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Design complete ER diagram for Hospital/Bank/University system with primary & foreign keys.', ARRAY['ER Diagram', 'Weak Entity', 'Cardinality', 'Schema Design']),
(24032, 'Relational Algebra Operations & Complex SQL Joins', 'Relational operators (Select, Project, Join, Division) and complex SQL queries with GROUP BY, HAVING, and correlated subqueries.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Write both Relational Algebra expressions and SQL queries for 5 given schema questions.', ARRAY['Relational Algebra', 'SQL Queries', 'Joins', 'Nested Queries', 'Triggers']),
(24033, 'Functional Dependency & BCNF Decomposition', 'Finding candidate keys, attribute closure, testing whether a decomposition is lossless and dependency preserving.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Find candidate keys and decompose R(A,B,C,D,E) into 3NF and BCNF with justification.', ARRAY['Normalization', '3NF', 'BCNF', 'Lossless Join', 'Functional Dependencies']),
(24034, 'Conflict Serializability & Precedence Graphs', 'Schedule testing using precedence graphs, detecting conflict serializability vs view serializability.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Given 2 concurrent transaction schedules S1 and S2, test for conflict serializability with graph.', ARRAY['Conflict Serializability', 'Precedence Graph', 'ACID Properties', 'Cascadeless Schedule']),
(24035, 'Two-Phase Locking (2PL) & Log-Based Recovery', 'Strict 2PL, Rigorous 2PL, Lock conversion, Deferred vs Immediate database modification with checkpoints.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Explain 2PL protocol and solve crash recovery questions using Log records with Undo/Redo lists.', ARRAY['Two-Phase Locking', 'Deadlock Detection', 'Log-Based Recovery', 'Checkpoints', 'Shadow Paging']);

-- Units & Topics for Theory of Computation (4AID4-06 & 4CS4-06)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(24041, 2404, 1, 'Finite Automata & Regular Expressions', 8, 'DFA, NFA, epsilon-NFA, NFA to DFA conversion, DFA minimization, Mealy & Moore machines.'),
(24042, 2404, 2, 'Regular Languages & Pumping Lemma', 8, 'Regular expressions, Arden theorem, Pumping Lemma for regular sets, Closure properties, Myhill-Nerode.'),
(24043, 2404, 3, 'Context Free Grammars & Normal Forms', 8, 'CFG derivation trees, Ambiguity, Simplification of CFG, Chomsky Normal Form (CNF), Greibach Normal Form (GNF).'),
(24044, 2404, 4, 'Pushdown Automata (PDA)', 8, 'Deterministic & Non-deterministic PDA, PDA to CFG conversion, Pumping Lemma for CFLs.'),
(24045, 2404, 5, 'Turing Machines & Decidability', 8, 'Turing Machine design, Universal TM, Halting Problem, Chomsky Hierarchy, P vs NP, NP-Completeness.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(24041, 'NFA to DFA Conversion & DFA Minimization', 'Subset construction algorithm and Table-filling (Myhill-Nerode) state equivalence minimization.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Convert given epsilon-NFA to equivalent minimal DFA with state transition table and diagram.', ARRAY['DFA', 'NFA', 'DFA Minimization', 'Mealy Moore Conversion']),
(24042, 'Pumping Lemma for Regular Languages', 'Proof of non-regularity of languages such as L = {0^n 1^n | n >= 1} using Pumping Lemma.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Step-by-step contradiction proof using Pumping Lemma is a recurring 7-mark question.', ARRAY['Pumping Lemma', 'Regular Expressions', 'Ardens Theorem', 'Closure Properties']),
(24043, 'Chomsky Normal Form (CNF) Conversion', 'Eliminating epsilon productions, unit productions, useless symbols, and transforming CFG to CNF.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Convert given grammar G to CNF with complete 4-step elimination process.', ARRAY['CFG', 'CNF', 'GNF', 'Ambiguous Grammar', 'Derivation Tree']),
(24044, 'Design of Pushdown Automata (PDA)', 'Constructing PDA transition functions accepting languages like L = {w c w^R} or balanced parentheses.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Design PDA accepting by empty stack / final state and trace sample input string transitions.', ARRAY['Pushdown Automata', 'PDA', 'CFL', 'Instantaneous Description']),
(24045, 'Turing Machine Construction & Halting Problem', 'Designing single-tape TM for unary multiplication, palindrome recognition, and proof of Halting Problem undecidability.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Design TM for L = {a^n b^n c^n | n >= 1} and explain why Halting problem is undecidable.', ARRAY['Turing Machine', 'Halting Problem', 'Undecidability', 'Chomsky Hierarchy', 'NP-Complete']);

-- Units & Topics for Data Communication and Computer Networks (4AID4-07 & 4CS4-07)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(24051, 2405, 1, 'Network Models & Physical Layer', 8, 'OSI 7-layer architecture vs TCP/IP model, Topologies, Transmission media, Line coding, Nyquist & Shannon limits.'),
(24052, 2405, 2, 'Data Link Layer & MAC Sublayer', 9, 'Framing, CRC (Cyclic Redundancy Check), Hamming Code, Flow Control (Stop & Wait, Go-Back-N, Selective Repeat), ALOHA, CSMA/CD.'),
(24053, 2405, 3, 'Network Layer & Routing', 8, 'IPv4 & IPv6 addressing, Subnetting, Classless addressing (CIDR), Routing algorithms (Distance Vector, Link State), ARP, RARP.'),
(24054, 2405, 4, 'Transport Layer Protocols', 8, 'TCP 3-way handshake, UDP, Congestion control, Leaky Bucket and Token Bucket algorithms, Quality of Service.'),
(24055, 2405, 5, 'Application Layer & Network Security', 7, 'DNS, HTTP/HTTPS, SMTP, FTP, Basics of firewalls and cryptography.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(24051, 'OSI Reference Model vs TCP/IP Suite', 'Detailed function of each of the 7 OSI layers with header encapsulation and comparison with TCP/IP.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare OSI and TCP/IP models with detailed layer responsibilities and diagrams.', ARRAY['OSI Model', 'TCP/IP Model', 'Encapsulation', 'Transmission Media']),
(24052, 'CRC Error Detection & Sliding Window ARQ', 'Modulo-2 polynomial division for CRC generation and checking, Go-Back-N vs Selective Repeat ARQ window efficiency.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Numerical on CRC frame generation and checking + Go-Back-N sliding window efficiency.', ARRAY['CRC', 'Sliding Window', 'Go-Back-N', 'Selective Repeat', 'CSMA/CD']),
(24053, 'IPv4 Subnetting & Distance Vector vs Link State Routing', 'FLSM/VLSM subnet mask calculation, Bellman-Ford count-to-infinity problem, Dijkstras Link State protocol.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Subnetting numerical: Calculate Network ID, Broadcast ID, and valid host range for given IP/CIDR.', ARRAY['Subnetting', 'IPv4', 'CIDR', 'Distance Vector Routing', 'Link State Routing']),
(24054, 'TCP Connection Management & Congestion Control', 'TCP 3-way handshake, 4-way termination, Slow Start, Congestion Avoidance, Fast Retransmit, Leaky/Token bucket.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Explain TCP 3-way handshake mechanism with sequence diagrams and Leaky Bucket algorithm.', ARRAY['TCP Handshake', 'Congestion Control', 'Leaky Bucket', 'Token Bucket', 'UDP']);

-- Labs for Sem 4
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(2421, 304, 'AI_DS_RTU', '4AID4-21', 'Microprocessor & Interfaces Lab', 'ESC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2422, 304, 'AI_DS_RTU', '4AID4-22', 'Database Management System Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2423, 304, 'AI_DS_RTU', '4AID4-23', 'Network Programming Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2424, 304, 'AI_DS_RTU', '4AID4-24', 'Linux Shell Programming Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2425, 304, 'AI_DS_RTU', '4AID4-25', 'Java Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2471, 204, 'CSE_RTU', '4CS4-21', 'Microprocessor & Interfaces Lab', 'ESC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2472, 204, 'CSE_RTU', '4CS4-22', 'Database Management System Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2473, 204, 'CSE_RTU', '4CS4-23', 'Network Programming Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2474, 204, 'CSE_RTU', '4CS4-24', 'Linux Shell Programming Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2475, 204, 'CSE_RTU', '4CS4-25', 'Java Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100);

-- DBMS Lab Experiments
INSERT INTO lab_experiments (course_id, experiment_number, title, description, tools_used) VALUES
(2422, 1, 'Database Schema Creation & Constraints', 'Design and create tables for Banking/College database applying PRIMARY KEY, FOREIGN KEY, and NOT NULL.', 'PostgreSQL / MySQL / Oracle'),
(2422, 2, 'Data Modification Statements', 'Execute SQL DDL/DML statements implementing ALTER, UPDATE, and DELETE operations.', 'PostgreSQL / SQL Client'),
(2422, 3, 'Complex SQL Joins', 'Write SQL queries implementing INNER JOIN, LEFT OUTER JOIN, RIGHT OUTER JOIN, and FULL JOIN.', 'PostgreSQL / SQL Client'),
(2422, 4, 'Aggregate Functions & Grouping', 'Execute queries utilizing MAX(), MIN(), AVG(), COUNT(), GROUP BY, and HAVING clauses.', 'PostgreSQL / SQL Client'),
(2422, 5, 'Views & Integrity Constraints', 'Create updatable and read-only views, enforcing domain and referential integrity constraints.', 'PostgreSQL / SQL Client'),
(2422, 6, 'Database Triggers & Procedures', 'Implement BEFORE and AFTER row-level triggers for audit logging and automatic balance checks.', 'PostgreSQL / SQL Client'),
(2422, 7, 'Database Application Project', 'Group project (3-4 students) to design a complete schema for Hospital or Inventory Management System.', 'PostgreSQL / Full-stack App');


-- =======================================================================================
-- 8.6 5TH SEMESTER (Core Subjects: OS, Compiler Design, DAA, CG, Data Mining / ITC)
-- =======================================================================================

-- Courses for Sem 5
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
-- AID Sem 5
(2501, 305, 'AI_DS_RTU', '5AID3-01', 'Data Mining-Concepts and Techniques', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2502, 305, 'AI_DS_RTU', '5AID4-02', 'Compiler Design', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2503, 305, 'AI_DS_RTU', '5AID4-03', 'Operating System', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2504, 305, 'AI_DS_RTU', '5AID4-04', 'Computer Graphics & Multimedia', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2505, 305, 'AI_DS_RTU', '5AID4-05', 'Analysis of Algorithms', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2506, 305, 'AI_DS_RTU', '5AID5-11', 'Fundamentals of Blockchain', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2507, 305, 'AI_DS_RTU', '5AID5-12', 'Probability and Statistics for Data Science', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2508, 305, 'AI_DS_RTU', '5AID5-13', 'Programming for Data Science', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
-- CSE Sem 5
(2551, 205, 'CSE_RTU', '5CS3-01', 'Information Theory & Coding', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2552, 205, 'CSE_RTU', '5CS4-02', 'Compiler Design', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2553, 205, 'CSE_RTU', '5CS4-03', 'Operating System', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2554, 205, 'CSE_RTU', '5CS4-04', 'Computer Graphics & Multimedia', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2555, 205, 'CSE_RTU', '5CS4-05', 'Analysis of Algorithms', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2556, 205, 'CSE_RTU', '5CS5-11', 'Wireless Communication', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2557, 205, 'CSE_RTU', '5CS5-12', 'Human Computer Interaction', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2558, 205, 'CSE_RTU', '5CS5-13', 'Bioinformatics', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100);

-- Units & Topics for Operating Systems (5AID4-03 & 5CS4-03)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(25031, 2503, 1, 'Introduction & Process Management', 5, 'OS structure, System calls, IPC, Process states, Scheduling algorithms (FCFS, SJF, RR, Priority), Threads.'),
(25032, 2503, 2, 'Process Synchronization', 6, 'Critical section problem, Peterson algorithm, Semaphores, Classic synchronization problems (Bounded Buffer, Dining Philosophers).'),
(25033, 2503, 3, 'Deadlocks', 7, 'Deadlock characterization, Resource Allocation Graph (RAG), Deadlock Prevention, Avoidance (Bankers algorithm), Detection and Recovery.'),
(25034, 2503, 4, 'Memory Management & Virtual Memory', 8, 'Paging, Segmentation, Page table structure, Demand paging, Page replacement algorithms (FIFO, LRU, Optimal), Thrashing.'),
(25035, 2503, 5, 'File Systems, I/O & Case Studies', 14, 'File allocation methods (Contiguous, Linked, Indexed), Disk scheduling (FCFS, SSTF, SCAN, C-SCAN), Linux/UNIX architecture.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(25031, 'CPU Scheduling Algorithms & Gantt Charts', 'FCFS, SJF Preemptive (SRTF), Priority, and Round Robin scheduling with turnaround & waiting time calculation.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Solve complete numerical for 5 processes: draw Gantt chart, compute average Turnaround & Waiting time.', ARRAY['CPU Scheduling', 'Round Robin', 'SRTF', 'Gantt Chart', 'Context Switching']),
(25032, 'Semaphores & Classical Synchronization Problems', 'Counting and binary semaphores, Producer-Consumer, Reader-Writer, and Dining Philosophers semaphore solutions.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Provide working semaphore pseudo-code for Producer-Consumer bounded buffer problem.', ARRAY['Semaphores', 'Critical Section', 'Mutual Exclusion', 'Dining Philosophers']),
(25033, 'Bankers Algorithm for Deadlock Avoidance', 'Safety algorithm and resource request algorithm with Available, Max, Allocation, and Need matrices.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Bankers Algorithm 5-process allocation numerical is repeated in 90% of RTU exam papers.', ARRAY['Bankers Algorithm', 'Deadlock Avoidance', 'Resource Allocation Graph', 'Safe State']),
(25034, 'Page Replacement Algorithms & Thrashing', 'FIFO, LRU, and Optimal page replacement simulation with frame traces, page fault counts, and Beladys anomaly.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Calculate page faults for given reference string using FIFO, LRU, and Optimal methods on 3/4 frames.', ARRAY['LRU Page Replacement', 'Paging', 'Demand Paging', 'Beladys Anomaly', 'Thrashing']),
(25035, 'Disk Scheduling Algorithms (SCAN, C-SCAN, SSTF)', 'Total head movement calculation across disk tracks for FCFS, SSTF, SCAN, LOOK, C-SCAN, and C-LOOK.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Calculate total head movements given disk request queue and initial head position.', ARRAY['Disk Scheduling', 'SCAN', 'C-SCAN', 'SSTF', 'File Allocation']);

-- Units & Topics for Compiler Design (5AID4-02 & 5CS4-02)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(25021, 2502, 1, 'Phases of Compiler & Lexical Analysis', 7, 'Phases of compilation, Lexical analyzer, Token recognition, LEX generator, Bootstrapping.'),
(25022, 2502, 2, 'Syntax Analysis & Parsing Techniques', 10, 'Top-down (Recursive descent, LL(1)), Bottom-up parsing (Shift Reduce, Operator Precedence, SLR, CLR, LALR).'),
(25023, 2502, 3, 'Syntax Directed Translation & Intermediate Code', 10, 'S-Attributed and L-Attributed SDD, Three-Address Code (TAC), Quadruples, Triples, Indirect Triples, DAG.'),
(25024, 2502, 4, 'Runtime Storage Organization & Symbol Tables', 8, 'Activation records, Storage allocation strategies, Symbol table data structures, Parameter passing.'),
(25025, 2502, 5, 'Code Optimization & Generation', 7, 'Basic blocks, Flow graphs, Loop optimization, Peephole optimization, DAG representation, Code generator design.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(25021, 'Phases of Compiler & Symbol Table Interaction', 'Role and diagram of 6 phases: Lexical, Syntax, Semantic, ICG, Code Optimizer, Code Generator.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Draw detailed phase diagram and translate sample expression: position = initial + rate * 60 through all phases.', ARRAY['Phases of Compiler', 'Lexical Analyzer', 'Symbol Table', 'Bootstrapping']),
(25022, 'LL(1) & LR Parsing Table Construction', 'Computation of FIRST and FOLLOW sets, constructing LL(1) parsing table, SLR(1)/LALR(1) item collections.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compute FIRST/FOLLOW and construct LL(1) parsing table or SLR(1) parsing table with shift-reduce moves.', ARRAY['LL(1) Parser', 'FIRST and FOLLOW', 'SLR(1)', 'LALR(1)', 'Shift Reduce Parsing']),
(25023, 'Three-Address Code (TAC) & Quadruples/Triples', 'Translating control flow and expressions into TAC, Quadruple, Triple, and Indirect Triple representations.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Convert while loop or arithmetic expression into 3-Address Code, Quadruples, and Triples.', ARRAY['Three Address Code', 'Quadruples', 'Triples', 'Syntax Directed Translation', 'DAG']),
(25025, 'Basic Blocks, Flow Graphs & Loop Optimization', 'Partitioning TAC into basic blocks, control flow graphs, loop invariants, code motion, induction variables.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Identify basic blocks from 3AC list, draw CFG, and apply loop optimizations + peephole techniques.', ARRAY['Basic Blocks', 'Flow Graph', 'Loop Invariants', 'Peephole Optimization', 'Code Generation']);

-- Units & Topics for Analysis of Algorithms (5AID4-05 & 5CS4-05)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(25051, 2505, 1, 'Algorithm Analysis & Divide and Conquer', 7, 'Asymptotic notations (O, Omega, Theta), Master theorem, Merge sort, Quick sort, Strassen matrix multiplication.'),
(25052, 2505, 2, 'Greedy Method & Dynamic Programming', 10, 'Knapsack problem, Job sequencing, Matrix Chain Multiplication, Longest Common Subsequence (LCS), 0/1 Knapsack.'),
(25053, 2505, 3, 'Branch and Bound & Backtracking', 8, 'N-Queens problem, Subset sum, Graph coloring, Traveling Salesperson Problem (TSP), Lower bound theory.'),
(25054, 2505, 4, 'String Matching & Randomized Algorithms', 8, 'Naive, Rabin-Karp, KMP (Knuth-Morris-Pratt) algorithm, Boyer-Moore, Las Vegas and Monte Carlo algorithms.'),
(25055, 2505, 5, 'NP-Completeness & Approximation Algorithms', 8, 'P, NP, NP-Hard, NP-Complete, Cooks Theorem, 3-SAT to Clique reduction, Vertex Cover approximation.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(25051, 'Asymptotic Complexity & Master Theorem', 'Solving recurrence relations using Master Theorem cases and recursion tree methods.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Master Theorem numericals solving T(n) = aT(n/b) + f(n) for 3 given recurrences.', ARRAY['Master Theorem', 'Asymptotic Notation', 'Divide and Conquer', 'Merge Sort']),
(25052, 'Dynamic Programming: 0/1 Knapsack, MCM & LCS', 'Building dynamic programming tables for Matrix Chain Multiplication, LCS, and 0/1 Knapsack problem.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Solve Matrix Chain Multiplication with dimensions <5, 10, 3, 12, 5> and construct m and s tables.', ARRAY['Matrix Chain Multiplication', '0/1 Knapsack', 'LCS', 'Dynamic Programming']),
(25053, 'Backtracking: N-Queens & Graph Coloring', 'State space tree generation, bounding functions, solving 4-Queens and 8-Queens backtracking.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Explain 8-Queens backtracking algorithm and draw state space search tree for 4-Queens.', ARRAY['N-Queens Problem', 'Backtracking', 'Graph Coloring', 'Branch and Bound']),
(25054, 'KMP String Matching Algorithm & Prefix Function', 'Knuth-Morris-Pratt string matching, failure function / pi-table calculation, O(n+m) complexity.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compute KMP prefix table (pi array) for a given pattern string and trace text matching steps.', ARRAY['KMP Algorithm', 'Rabin Karp', 'String Matching', 'Prefix Function']),
(25055, 'NP-Completeness & Cooks Theorem', 'Definitions of P, NP, NP-Hard, NP-Complete, polynomial time reductions, Cooks Theorem statement.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Prove that Vertex Cover or 3-SAT problem is NP-Complete through polynomial-time reduction.', ARRAY['NP-Complete', 'NP-Hard', 'Cooks Theorem', 'Polynomial Reduction', 'Vertex Cover']);

-- Labs for Sem 5
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(2521, 305, 'AI_DS_RTU', '5AID4-21', 'Computer Graphics & Multimedia Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2522, 305, 'AI_DS_RTU', '5AID4-22', 'Compiler Design Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2523, 305, 'AI_DS_RTU', '5AID4-23', 'Analysis of Algorithms Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2524, 305, 'AI_DS_RTU', '5AID4-24', 'Advance Java Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2571, 205, 'CSE_RTU', '5CS4-21', 'Computer Graphics & Multimedia Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2572, 205, 'CSE_RTU', '5CS4-22', 'Compiler Design Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2573, 205, 'CSE_RTU', '5CS4-23', 'Analysis of Algorithms Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2574, 205, 'CSE_RTU', '5CS4-24', 'Advance Java Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100);

-- DAA Lab Experiments
INSERT INTO lab_experiments (course_id, experiment_number, title, description, tools_used) VALUES
(2523, 1, 'Quick Sort Empirical Analysis', 'Sort elements using Quicksort, vary array size n, measure CPU clock cycles, and plot time vs n curve.', 'C++ / Python'),
(2523, 2, 'Parallelized Merge Sort Analysis', 'Implement Merge Sort algorithm and benchmark performance against varying data distributions.', 'C++ / Python'),
(2523, 3, 'Topological Sort & Warshalls Transitive Closure', 'Obtain topological ordering in a DAG and compute transitive closure matrix using Warshalls algorithm.', 'C++ / Python'),
(2523, 4, '0/1 Knapsack Dynamic Programming', 'Implement 0/1 Knapsack dynamic programming table to determine maximum value subset.', 'C++ / Python'),
(2523, 5, 'Dijkstras Shortest Path Algorithm', 'Compute single-source shortest path weights and paths on weighted directed graph.', 'C++ / Python'),
(2523, 6, 'Kruskals Minimum Spanning Tree', 'Find MST using Kruskals greedy edge selection with Union-Find cycle detection.', 'C++ / Python'),
(2523, 7, 'Prims Minimum Spanning Tree', 'Construct Minimum Cost Spanning Tree using Prims priority queue algorithm.', 'C++ / Python'),
(2523, 8, 'Floyds All-Pairs Shortest Path', 'Implement Floyd-Warshalls dynamic programming algorithm to compute all-pairs distance matrix.', 'C++ / Python'),
(2523, 9, 'N-Queens Backtracking Problem', 'Place N non-attacking queens on NxN chessboard using recursive backtracking.', 'C++ / Python');


-- =======================================================================================
-- 8.7 6TH SEMESTER (Machine Learning, DIP, Information Security, Cloud, AI / COA)
-- =======================================================================================

-- Courses for Sem 6
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
-- AID Sem 6
(2601, 306, 'AI_DS_RTU', '6AID3-01', 'Digital Image Processing', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2602, 306, 'AI_DS_RTU', '6AID4-02', 'Machine Learning', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2603, 306, 'AI_DS_RTU', '6AID4-03', 'Information Security System', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2604, 306, 'AI_DS_RTU', '6AID4-04', 'Computer Architecture and Organization', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2605, 306, 'AI_DS_RTU', '6AID4-05', 'Principles of Artificial Intelligence', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2606, 306, 'AI_DS_RTU', '6AID4-06', 'Cloud Computing', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2607, 306, 'AI_DS_RTU', '6AID5-11', 'Artificial Neural Network', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2608, 306, 'AI_DS_RTU', '6AID5-12', 'Natural Language Processing (NLP)', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2609, 306, 'AI_DS_RTU', '6AID5-13', 'Nature Inspired Computing', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
-- CSE Sem 6
(2651, 206, 'CSE_RTU', '6CS3-01', 'Digital Image Processing', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2652, 206, 'CSE_RTU', '6CS4-02', 'Machine Learning', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2653, 206, 'CSE_RTU', '6CS4-03', 'Information Security System', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2654, 206, 'CSE_RTU', '6CS4-04', 'Computer Architecture and Organization', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2655, 206, 'CSE_RTU', '6CS4-05', 'Artificial Intelligence', 'PCC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2656, 206, 'CSE_RTU', '6CS4-06', 'Cloud Computing', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2657, 206, 'CSE_RTU', '6CS5-11', 'Distributed System', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2658, 206, 'CSE_RTU', '6CS5-12', 'Software Defined Network', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100),
(2659, 206, 'CSE_RTU', '6CS5-13', 'Ecommerce & ERP', 'PEC', 'THEORY', 2.0, 2, 0, 0, 3, 30, 70, 100);

-- Units & Topics for Machine Learning (6AID4-02 & 6CS4-02)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(26021, 2602, 1, 'Supervised Learning Algorithms', 10, 'Linear Regression, Logistic Regression, Decision Trees (ID3), Naive Bayes, KNN, SVM, Random Forests.'),
(26022, 2602, 2, 'Unsupervised Learning & Pattern Mining', 8, 'K-Means clustering, Hierarchical clustering, Gaussian Mixture Models, Apriori algorithm, FP-Growth.'),
(26023, 2602, 3, 'Statistical Learning & Feature Engineering', 8, 'PCA (Principal Component Analysis), SVD, Feature selection (Filter, Wrapper, Embedded), Cross validation, ROC/AUC.'),
(26024, 2602, 4, 'Reinforcement Learning & Semi-Supervised', 8, 'Markov Decision Process (MDP), Bellman equations, Value/Policy Iteration, Q-Learning, SARSA.'),
(26025, 2602, 5, 'Neural Networks & Deep Learning Intro', 8, 'Perceptron, Multilayer Perceptron, Backpropagation learning rule, Recommender Systems (Collaborative vs Content).');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(26021, 'Decision Tree Induction & ID3 Information Gain', 'Calculating Entropy, Information Gain, and Split Info to construct decision trees from tabular training data.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Solve complete numerical: calculate root node splitting feature from given 14-instance PlayTennis dataset.', ARRAY['Decision Tree', 'ID3', 'Information Gain', 'Entropy', 'SVM', 'Random Forest']),
(26021, 'Support Vector Machines (SVM) & Kernel Trick', 'Maximal margin hyperplane, support vectors, soft margin slack variables, and Kernel functions (RBF, Polynomial).', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Mathematical formulation of SVM optimization problem with dual Lagrangian multipliers.', ARRAY['Support Vector Machines', 'Hyperplane', 'Margin', 'Kernel Trick']),
(26022, 'K-Means Clustering & Apriori Algorithm', 'Iterative centroid updates, SSE convergence, Apriori candidate itemset generation and association rules.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Perform K-Means clustering step-by-step for given 1D/2D data points or derive Apriori frequent itemsets.', ARRAY['K-Means', 'Clustering', 'Apriori Algorithm', 'Association Rules']),
(26023, 'Principal Component Analysis (PCA)', 'Covariance matrix calculation, eigenvalue decomposition, variance explained, and dimensionality reduction.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Derive mathematical steps of PCA: mean centering, covariance matrix, eigenvectors projection.', ARRAY['PCA', 'Dimensionality Reduction', 'Eigenvalues', 'Feature Selection']),
(26024, 'Q-Learning & Bellman Optimality Equation', 'Temporal difference learning, Q-value update rule, exploration vs exploitation (epsilon-greedy), MDPs.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Write Bellman optimality equation and explain Q-learning update formula with discount factor gamma.', ARRAY['Q-Learning', 'Bellman Equation', 'Reinforcement Learning', 'Markov Decision Process']);

-- Units & Topics for Principles of AI (6AID4-05 & 6CS4-05)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(26051, 2605, 1, 'Intelligent Agents & Problem Solving Searches', 4, 'Agent architectures, Uninformed search (BFS, DFS, DLS, IDDFS), Informed Search (Greedy Best-First, A*, AO*), CSP.'),
(26052, 2605, 2, 'Adversarial Search & Game Playing', 6, 'Minimax algorithm, Alpha-Beta pruning, Water Jug problem, 8-puzzle problem, Chess heuristics.'),
(26053, 2605, 3, 'Knowledge Representation & First Order Logic', 6, 'Propositional logic, First Order Predicate Logic (FOPL), Unification, Resolution Refutation, Bayesian Networks.'),
(26054, 2605, 4, 'Machine Learning & Knowledge Systems', 7, 'Supervised learning overview, Decision Trees, Neural Networks in AI, Market Basket Analysis.'),
(26055, 2605, 5, 'Natural Language Processing & Expert Systems', 5, 'Phases of NLP, Rule-based Expert Systems, Architecture of Inference Engine, Robotics.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(26051, 'A* Search Algorithm & Heuristic Admissibility', 'Evaluation function f(n) = g(n) + h(n), admissibility condition h(n) <= h*(n), consistency, 8-puzzle state search.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Solve 8-puzzle or shortest path problem using A* algorithm and prove admissibility of Manhattan distance.', ARRAY['A* Search', 'Heuristics', 'AO* Search', 'Constraint Satisfaction', 'BFS', 'DFS']),
(26052, 'Alpha-Beta Pruning on Game Trees', 'Minimax game tree evaluation, Alpha cutoff, Beta cutoff, reducing branch exploration.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Apply Alpha-Beta pruning on a given 4-ply game tree and show pruned subtrees.', ARRAY['Alpha-Beta Pruning', 'Minimax Algorithm', 'Game Trees', 'Water Jug Problem']),
(26053, 'Resolution Refutation in First Order Logic', 'Converting English sentences to FOPL, converting to CNF / Clause form, Unification algorithm, Resolution proof by refutation.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Given knowledge base, convert to clauses and prove target query using Resolution Refutation.', ARRAY['Resolution Refutation', 'FOPL', 'Unification', 'Bayesian Networks', 'Knowledge Representation']);

-- Units & Topics for Information Security System (6AID4-03 & 6CS4-03)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(26031, 2603, 1, 'Classical Encryption & Security Attacks', 7, 'Substitution/Transposition ciphers, Cryptanalysis, Stream and Block ciphers.'),
(26032, 2603, 2, 'Modern Block Ciphers: DES & AES', 6, 'DES Feistel structure, AES encryption rounds, S-Box substitution, Modes of operation (ECB, CBC, CFB, OFB, CTR).'),
(26033, 2603, 3, 'Public Key Cryptography & Key Exchange', 6, 'RSA algorithm, Diffie-Hellman Key Exchange, Elliptic Curve Cryptography (ECC), Man-in-the-middle attack.'),
(26034, 2603, 4, 'Cryptographic Hashes & Digital Signatures', 5, 'SHA-512, Message Authentication Codes (HMAC), Digital Signatures (DSA, RSA signature), NIST standard.'),
(26035, 2603, 5, 'Key Management, Authentication & Web Security', 4, 'X.509 certificates, Kerberos authentication, SSL/TLS handshake, HTTPS, SSH, Firewalls.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(26032, 'DES Architecture vs AES Round Structure', 'DES 16-round Feistel structure, round keys, S-boxes vs AES 128-bit 10-round SubBytes, ShiftRows, MixColumns, AddRoundKey.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare DES and AES architectures and explain 4 AES transformation steps with diagrams.', ARRAY['DES', 'AES', 'Block Ciphers', 'Cipher Block Chaining', 'Modes of Operation']),
(26033, 'RSA Algorithm & Diffie-Hellman Key Exchange', 'RSA key generation (p, q, n, phi, e, d), modular exponentiation, Diffie-Hellman discrete log exchange.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Solve RSA numerical: given p=7, q=11, e=13, find d and encrypt message M=9.', ARRAY['RSA Algorithm', 'Diffie-Hellman', 'Public Key Cryptography', 'Discrete Logarithm']),
(26034, 'Digital Signatures & Secure Hash Algorithm (SHA)', 'Message authentication, collision resistance in SHA-512, Digital Signature standard verification.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Explain Digital Signature generation and verification workflow using private/public key pairs.', ARRAY['Digital Signatures', 'SHA-512', 'HMAC', 'Message Digest']),
(26035, 'SSL/TLS Handshake Protocol & Kerberos', 'SSL/TLS record and handshake steps, Kerberos Ticket Granting Server (TGS) authentication.', TRUE, 'HIGH', 'VERY_FREQUENT', 'Draw and explain SSL/TLS Handshake protocol message exchange sequence.', ARRAY['SSL/TLS Handshake', 'Kerberos', 'X.509', 'HTTPS', 'Network Security']);

-- Units & Topics for Cloud Computing (6AID4-06 & 6CS4-06)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(26061, 2606, 1, 'Cloud Architecture & Service Models', 7, 'IaaS, PaaS, SaaS, Public/Private/Hybrid clouds, Cloud economics, Data center architecture.'),
(26062, 2606, 2, 'Cloud Programming & MapReduce', 10, 'Distributed programming models, MapReduce paradigm, Hadoop architecture, Google App Engine.'),
(26063, 2606, 3, 'Virtualization Technology', 10, 'Hypervisors (Type 1 and Type 2), CPU/Memory/IO Virtualization, KVM, VMware, Xen, Docker containers.'),
(26064, 2606, 4, 'Cloud Security & SLA Management', 8, 'Cloud threats, Multi-tenancy isolation, Data security, Service Level Agreements (SLA), Disaster recovery.'),
(26065, 2606, 5, 'Commercial Cloud Platforms', 7, 'AWS EC2/S3, Microsoft Azure, Google Cloud Platform, Aneka platform.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(26061, 'Cloud Service & Deployment Models (SPI & Types)', 'Comparison of SaaS, PaaS, IaaS and Public, Private, Hybrid, Community deployment models.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Detailed comparison table of IaaS, PaaS, and SaaS with examples and responsibility boundaries.', ARRAY['IaaS', 'PaaS', 'SaaS', 'Hybrid Cloud', 'Cloud Architecture']),
(26063, 'Virtualization Architecture & Hypervisors', 'Hardware-assisted, full, and para-virtualization; Bare metal (Type-1) vs Hosted (Type-2) hypervisors.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare Type-1 (Bare Metal) and Type-2 (Hosted) hypervisors with architectural block diagrams.', ARRAY['Virtualization', 'Hypervisors', 'KVM', 'VMware', 'Containers']);

-- Labs for Sem 6
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
(2621, 306, 'AI_DS_RTU', '6AID4-21', 'Digital Image Processing Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2622, 306, 'AI_DS_RTU', '6AID4-22', 'Machine Learning Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2623, 306, 'AI_DS_RTU', '6AID4-23', 'Python Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2624, 306, 'AI_DS_RTU', '6AID4-24', 'Mobile Application Development Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2671, 206, 'CSE_RTU', '6CS4-21', 'Digital Image Processing Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2672, 206, 'CSE_RTU', '6CS4-22', 'Machine Learning Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2673, 206, 'CSE_RTU', '6CS4-23', 'Python Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100),
(2674, 206, 'CSE_RTU', '6CS4-24', 'Mobile Application Development Lab', 'PCC', 'PRACTICAL', 1.5, 0, 0, 3, 2, 60, 40, 100);

-- ML Lab Experiments
INSERT INTO lab_experiments (course_id, experiment_number, title, description, tools_used) VALUES
(2622, 1, 'FIND-S Concept Learning Algorithm', 'Implement FIND-S algorithm for finding maximally specific hypotheses from CSV training data.', 'Python / Scikit-learn'),
(2622, 2, 'Candidate-Elimination Algorithm', 'Implement Candidate-Elimination algorithm outputting General (G) and Specific (S) hypothesis boundaries.', 'Python / Pandas'),
(2622, 3, 'ID3 Decision Tree Classifier', 'Demonstrate decision tree construction from scratch and classify unseen test samples.', 'Python / Numpy'),
(2622, 4, 'Backpropagation Artificial Neural Network', 'Build multilayer feedforward neural network and train with Backpropagation on non-linear datasets.', 'Python / PyTorch / Keras'),
(2622, 5, 'Naive Bayes Text Classifier', 'Implement Naive Bayes classifier on document datasets and compute accuracy, precision, and recall.', 'Python / NLTK'),
(2622, 6, 'Bayesian Network Medical Diagnostic System', 'Construct Bayesian Network for Heart Disease diagnosis using clinical datasets.', 'Python / pgmpy'),
(2622, 7, 'K-Means & EM Clustering Comparison', 'Cluster unlabelled datasets using K-Means and Expectation-Maximization (EM) and compare cluster quality.', 'Python / Scikit-learn'),
(2622, 8, 'k-Nearest Neighbour (k-NN) Classification', 'Classify Iris dataset samples using k-NN with Euclidean distance metric.', 'Python / Scikit-learn'),
(2622, 9, 'Locally Weighted Regression (LWR)', 'Implement non-parametric Locally Weighted Regression fitting curves to non-linear data points.', 'Python / Matplotlib');


-- =======================================================================================
-- 8.8 7TH SEMESTER (Big Data Analytics / Internet of Things, Labs & Sessional)
-- =======================================================================================

-- Courses for Sem 7
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
-- AID Sem 7
(2701, 307, 'AI_DS_RTU', '7AID4-01', 'Big Data Analytics', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2721, 307, 'AI_DS_RTU', '7AID4-21', 'Big Data Analytics Lab', 'PCC', 'PRACTICAL', 2.0, 0, 0, 4, 2, 60, 40, 100),
(2722, 307, 'AI_DS_RTU', '7AID4-22', 'R. Programming Lab', 'PCC', 'PRACTICAL', 2.0, 0, 0, 4, 2, 60, 40, 100),
(2723, 307, 'AI_DS_RTU', '7AID7-30', 'Industrial Training', 'PSIT', 'SESSIONAL', 2.5, 1, 0, 0, 0, 60, 40, 100),
(2724, 307, 'AI_DS_RTU', '7AID7-40', 'Seminar', 'PSIT', 'SESSIONAL', 2.0, 2, 0, 0, 0, 60, 40, 100),
-- CSE Sem 7
(2751, 207, 'CSE_RTU', '7CS4-01', 'Internet of Things', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2771, 207, 'CSE_RTU', '7CS4-21', 'Internet of Things Lab', 'PCC', 'PRACTICAL', 2.0, 0, 0, 4, 2, 60, 40, 100),
(2772, 207, 'CSE_RTU', '7CS4-22', 'Cyber Security Lab', 'PCC', 'PRACTICAL', 2.0, 0, 0, 4, 2, 60, 40, 100),
(2773, 207, 'CSE_RTU', '7CS7-30', 'Industrial Training', 'PSIT', 'SESSIONAL', 2.5, 1, 0, 0, 0, 60, 40, 100),
(2774, 207, 'CSE_RTU', '7CS7-40', 'Seminar', 'PSIT', 'SESSIONAL', 2.0, 2, 0, 0, 0, 60, 40, 100);

-- Units & Topics for Big Data Analytics (7AID4-01 & 8CS4-01)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(27011, 2701, 1, 'Introduction to Big Data & HDFS Architecture', 11, '3 Vs of Big Data, Google File System, HDFS architecture (Namenode, Datanode, Secondary Namenode), Hadoop cluster modes.'),
(27012, 2701, 2, 'MapReduce Programming Framework', 8, 'Hadoop API for MapReduce, Mapper, Reducer, Combiner, Partitioner, InputFormat/RecordReader, WordCount program.'),
(27013, 2701, 3, 'Hadoop I/O & Serialization', 8, 'Writable interface, WritableComparable, Custom Writable serialization, Raw comparators for high speed.'),
(27014, 2701, 4, 'Pig & Pig Latin Scripting', 7, 'Pig architecture, Pig Latin application flow, Data types, Grunt shell, Joins, Grouping, Filtering in Pig.'),
(27015, 2701, 5, 'Hive Data Warehousing', 6, 'Hive architecture, HiveQL, Metastore, Managed vs External tables, Partitioning and Bucketing in Hive.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(27011, 'HDFS Architecture & Block Replication', 'Namenode metadata management, EditLog and FsImage checkpointing by Secondary Namenode, heartbeat & block report.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Draw HDFS architecture diagram showing Namenode, Datanode, client read/write pipeline.', ARRAY['HDFS', 'Namenode', 'Datanode', 'Secondary Namenode', '3 Vs of Big Data']),
(27012, 'MapReduce Lifecycle & WordCount Execution', 'Data flow from InputSplit to Mapper, Shuffle & Sort phase, Combiner optimization, Reducer aggregation.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Write complete Java MapReduce code for WordCount or Weather Dataset max temperature.', ARRAY['MapReduce', 'Mapper', 'Reducer', 'Shuffle and Sort', 'Combiner']),
(27014, 'Pig Latin Scripting & Operators', 'LOAD, FILTER, GROUP, FOREACH, JOIN, DUMP, STORE commands and User Defined Functions (UDFs).', TRUE, 'HIGH', 'VERY_FREQUENT', 'Write Pig Latin scripts to filter and calculate aggregate statistics on customer transactions.', ARRAY['Apache Pig', 'Pig Latin', 'Grunt Shell', 'Transformations']),
(27015, 'Hive Architecture, Partitioning & Bucketing', 'Hive data models, Internal vs External tables, improving query efficiency with Partitions and Buckets.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare Managed vs External tables in Hive and explain Partitioning vs Bucketing with HiveQL syntax.', ARRAY['Apache Hive', 'HiveQL', 'Partitioning', 'Bucketing', 'Metastore']);

-- Units & Topics for Internet of Things (7CS4-01)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(27511, 2751, 1, 'Introduction to IoT & Enabling Technologies', 9, 'Definition, Physical and logical design, IoT functional blocks, IoT communication APIs, WSN, Cloud integration.'),
(27512, 2751, 2, 'IoT Hardware Platforms & Embedded OS', 7, 'Sensors, Actuators, Arduino, Raspberry Pi, Embedded operating systems (LiteOS, Contiki OS, TinyOS).'),
(27513, 2751, 3, 'IoT Reference Architecture & REST Style', 8, 'IoT reference model, REST architectural style, URIs, Security and scalability challenges.'),
(27514, 2751, 4, 'IoT vs M2M & Software Defined IoT', 8, 'M2M vs IoT differences, Software Defined Networking (SDN) and Network Function Virtualization (NFV) for IoT.'),
(27515, 2751, 5, 'IoT Domain Applications & Case Studies', 8, 'Smart Cities, Smart Home automation, Industrial IoT (IIoT), Agriculture monitoring, Connected healthcare.');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(27511, 'IoT Architecture & Communication Models', 'Request-Response, Publish-Subscribe, Push-Pull, and Exclusive Pair communication protocols.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare Request-Response vs Publish-Subscribe (MQTT) models with architectural diagrams.', ARRAY['IoT Architecture', 'MQTT', 'CoAP', 'Publish-Subscribe', 'REST']),
(27514, 'M2M vs IoT & SDN Integration', 'Comparison of M2M and IoT protocols, role of SDN in dynamic IoT resource management.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Provide a comprehensive comparison table between M2M and IoT with network protocol stacks.', ARRAY['M2M vs IoT', 'SDN', 'NFV', 'Network Virtualization']);


-- =======================================================================================
-- 8.9 8TH SEMESTER (Deep Learning / Big Data Analytics, Project & Labs)
-- =======================================================================================

-- Courses for Sem 8
INSERT INTO courses (id, semester_id, branch_id, course_code, course_title, category, delivery_type, credits, lecture_hours, tutorial_hours, practical_hours, exam_hours, ia_marks, ete_marks, total_marks) VALUES
-- AID Sem 8
(2801, 308, 'AI_DS_RTU', '8AID4-01', 'Deep Learning and Its Applications', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2821, 308, 'AI_DS_RTU', '8AID4-21', 'Deep Learning and Its Application Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2822, 308, 'AI_DS_RTU', '8AID4-22', 'Robot Programming Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2823, 308, 'AI_DS_RTU', '8AID7-50', 'Project', 'PSIT', 'PROJECT', 7.0, 3, 0, 0, 0, 60, 40, 100),
-- CSE Sem 8
(2851, 208, 'CSE_RTU', '8CS4-01', 'Big Data Analytics', 'PCC', 'THEORY', 3.0, 3, 0, 0, 3, 30, 70, 100),
(2871, 208, 'CSE_RTU', '8CS4-21', 'Big Data Analytics Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2872, 208, 'CSE_RTU', '8CS4-22', 'Software Testing and Validation Lab', 'PCC', 'PRACTICAL', 1.0, 0, 0, 2, 2, 60, 40, 100),
(2873, 208, 'CSE_RTU', '8CS7-50', 'Project', 'PSIT', 'PROJECT', 7.0, 3, 0, 0, 0, 60, 40, 100);

-- Units & Topics for Deep Learning and Its Applications (8AID4-01)
INSERT INTO course_units (id, course_id, unit_number, unit_title, lecture_hours, description) VALUES
(28011, 2801, 1, 'Deep Feedforward Networks & Optimization', 9, 'Multilayer Perceptrons, Gradient descent variants (SGD, Adam, RMSProp), Activation functions (ReLU, LeakyReLU, ELU), Backpropagation.'),
(28012, 2801, 2, 'Deep Learning Architectures & Regularization', 8, 'Representation learning, Restricted Boltzmann Machines (RBM), Dropout, Batch Normalization, L1/L2 weight decay.'),
(28013, 2801, 3, 'Convolutional Neural Networks (CNN)', 7, 'Convolution operation, Pooling layers, Stride, Padding, Receptive fields, AlexNet, VGGNet, ResNet residual skip connections.'),
(28014, 2801, 4, 'Sequence Models & RNNs / LSTMs', 9, 'Recurrent Neural Networks, Backpropagation Through Time (BPTT), Exploding/Vanishing gradients, LSTM gates, GRUs, Encoder-Decoder Seq2Seq.'),
(28015, 2801, 5, 'Autoencoders & Generative Models', 7, 'Undercomplete, Regularized, Contractive, and Variational Autoencoders (VAE), Generative Adversarial Networks (GANs).');

INSERT INTO topics (unit_id, topic_title, topic_description, is_high_yield, importance_level, exam_frequency, rtu_exam_tips, key_concepts) VALUES
(28011, 'Activation Functions & Vanishing Gradient Problem', 'Mathematical formulation and derivatives of Sigmoid, Tanh, ReLU, Leaky ReLU, ELU, and why ReLU mitigates vanishing gradients.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Compare Sigmoid, Tanh, and ReLU with formulas, curves, advantages, and limitations.', ARRAY['Activation Functions', 'ReLU', 'Vanishing Gradient', 'Stochastic Gradient Descent']),
(28013, 'CNN Architecture & Residual Networks (ResNet)', 'Filter convolution arithmetic, feature maps, max pooling, AlexNet architecture, ResNet residual skip connections.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Draw ResNet residual block diagram and explain why skip connections enable training very deep networks (50+ layers).', ARRAY['CNN', 'Convolution', 'ResNet', 'AlexNet', 'Max Pooling']),
(28014, 'LSTM Cell Architecture & Gating Mechanism', 'Forget Gate, Input Gate, Candidate Value, Cell State update, Output Gate equations.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Draw complete LSTM cell diagram and write mathematical equations for all 3 gates.', ARRAY['LSTM', 'RNN', 'BPTT', 'Vanishing Gradients', 'Seq2Seq']),
(28015, 'Autoencoders & Generative Adversarial Networks (GANs)', 'Encoder-Decoder bottleneck representation, GAN minimax game objective function between Generator and Discriminator.', TRUE, 'CRITICAL', 'VERY_FREQUENT', 'Explain GAN architecture with Minimax loss function equation: min_G max_D V(D, G).', ARRAY['Autoencoders', 'GAN', 'Generator', 'Discriminator', 'Variational Autoencoder']);

-- Deep Learning Lab Experiments
INSERT INTO lab_experiments (course_id, experiment_number, title, description, tools_used) VALUES
(2821, 1, 'Deep Regression Model with PyTorch/TensorFlow', 'Build a deep neural network for single and multi-variable regression.', 'Python / PyTorch / TensorFlow'),
(2821, 2, 'Audio and Video Data Preprocessing', 'Write programs to perform Speech-to-Text, Text-to-Speech, and Video-to-Frame extraction.', 'Python / OpenCV / Librosa'),
(2821, 3, 'Feedforward Neural Network for Logic Gates', 'Construct and train MLP from scratch to learn XOR non-linear decision boundary.', 'Python / Numpy'),
(2821, 4, 'CNN for Handwritten Digit/Character Recognition', 'Train a Convolutional Neural Network on MNIST dataset achieving >98% accuracy.', 'Python / Keras / PyTorch'),
(2821, 5, 'Image Captioning with CNN + LSTM', 'Combine CNN feature extractor with LSTM sequence decoder for image caption generation.', 'Python / PyTorch'),
(2821, 6, 'Generative Models: Autoencoder & GAN on MNIST', 'Implement Undercomplete Autoencoder and DCGAN to synthesize handwritten digits.', 'Python / PyTorch');


-- =======================================================================================
-- 8.10 OPEN ELECTIVES (7th & 8th Semester)
-- =======================================================================================

INSERT INTO open_electives (semester_number, elective_group, subject_code, title, department) VALUES
-- Open Elective - I (7th Semester)
(7, 'Open Elective - I', '7AG6-60.1', 'Human Engineering and Safety', 'Agriculture Engineering'),
(7, 'Open Elective - I', '7AG6-60.2', 'Environmental Engineering and Disaster Management', 'Agriculture Engineering'),
(7, 'Open Elective - I', '7AN6-60.1', 'Aircraft Avionic System', 'Aeronautical Engineering'),
(7, 'Open Elective - I', '7AN6-60.2', 'Non-Destructive Testing', 'Aeronautical Engineering'),
(7, 'Open Elective - I', '7CH6-60.1', 'Optimization Techniques', 'Chemical Engineering'),
(7, 'Open Elective - I', '7CH6-60.2', 'Sustainable Engineering', 'Chemical Engineering'),
(7, 'Open Elective - I', '7CR6-60.1', 'Introduction to Ceramic Science & Technology', 'Ceramic Engineering'),
(7, 'Open Elective - I', '7CR6-60.2', 'Plant, Equipment and Furnace Design', 'Ceramic Engineering'),
(7, 'Open Elective - I', '7CE6-60.1', 'Environmental Impact Analysis', 'Civil Engineering'),
(7, 'Open Elective - I', '7CE6-60.2', 'Disaster Management', 'Civil Engineering'),
(7, 'Open Elective - I', '7EE6-60.1', 'Electrical Machines and Drives', 'Electrical Engineering'),
(7, 'Open Elective - I', '7EE6-60.2', 'Power Generation Sources', 'Electrical Engineering'),
(7, 'Open Elective - I', '7EC6-60.1', 'Principle of Electronic Communication', 'Electronics & Comm. Engineering'),
(7, 'Open Elective - I', '7EC6-60.2', 'Micro and Smart System Technology', 'Electronics & Comm. Engineering'),
(7, 'Open Elective - I', '7ME6-60.1', 'Finite Element Analysis', 'Mechanical Engineering'),
(7, 'Open Elective - I', '7ME6-60.2', 'Quality Management', 'Mechanical Engineering'),
(7, 'Open Elective - I', '7MI6-60.1', 'Rock Engineering', 'Mining Engineering'),
(7, 'Open Elective - I', '7MI6-60.2', 'Mineral Processing', 'Mining Engineering'),
(7, 'Open Elective - I', '7PE6-60.1', 'Pipeline Engineering', 'Petroleum Engineering'),
(7, 'Open Elective - I', '7PE6-60.2', 'Water Pollution Control Engineering', 'Petroleum Engineering'),
(7, 'Open Elective - I', '7TT6-60.1', 'Technical Textiles', 'Textile Engineering'),
(7, 'Open Elective - I', '7TT6-60.2', 'Garment Manufacturing Technology', 'Textile Engineering'),

-- Open Elective - II (8th Semester)
(8, 'Open Elective - II', '8AG6-60.1', 'Energy Management', 'Agriculture Engineering'),
(8, 'Open Elective - II', '8AG6-60.2', 'Waste and By-product Utilization', 'Agriculture Engineering'),
(8, 'Open Elective - II', '8AN6-60.1', 'Finite Element Methods', 'Aeronautical Engineering'),
(8, 'Open Elective - II', '8AN6-60.2', 'Factor of Human Interactions', 'Aeronautical Engineering'),
(8, 'Open Elective - II', '8CH6-60.1', 'Refinery Engineering Design', 'Chemical Engineering'),
(8, 'Open Elective - II', '8CH6-60.2', 'Fertilizer Technology', 'Chemical Engineering'),
(8, 'Open Elective - II', '8CR6-60.1', 'Electrical and Electronic Ceramics', 'Ceramic Engineering'),
(8, 'Open Elective - II', '8CR6-60.2', 'Biomaterials', 'Ceramic Engineering'),
(8, 'Open Elective - II', '8CE6-60.1', 'Composite Materials', 'Civil Engineering'),
(8, 'Open Elective - II', '8CE6-60.2', 'Fire and Safety Engineering', 'Civil Engineering'),
(8, 'Open Elective - II', '8EE6-60.1', 'Energy Audit and Demand Side Management', 'Electrical Engineering'),
(8, 'Open Elective - II', '8EE6-60.2', 'Soft Computing', 'Electrical Engineering'),
(8, 'Open Elective - II', '8EC6-60.1', 'Industrial and Biomedical Applications of RF Energy', 'Electronics & Comm. Engineering'),
(8, 'Open Elective - II', '8EC6-60.2', 'Robotics and Control', 'Electronics & Comm. Engineering'),
(8, 'Open Elective - II', '8ME6-60.1', 'Operations Research', 'Mechanical Engineering'),
(8, 'Open Elective - II', '8ME6-60.2', 'Simulation Modeling and Analysis', 'Mechanical Engineering'),
(8, 'Open Elective - II', '8MI6-60.1', 'Experimental Stress Analysis', 'Mining Engineering'),
(8, 'Open Elective - II', '8MI6-60.2', 'Maintenance Management', 'Mining Engineering'),
(8, 'Open Elective - II', '8PE6-60.1', 'Unconventional Hydrocarbon Resources', 'Petroleum Engineering'),
(8, 'Open Elective - II', '8PE6-60.2', 'Energy Management & Policy', 'Petroleum Engineering'),
(8, 'Open Elective - II', '8TT6-60.1', 'Material and Human Resource Management', 'Textile Engineering'),
(8, 'Open Elective - II', '8TT6-60.2', 'Disaster Management', 'Textile Engineering');


-- =======================================================================================
-- 8.11 RECOMMENDED TEXTBOOKS & REFERENCE BOOKS
-- =======================================================================================

INSERT INTO recommended_books (course_id, book_type, title, authors, publisher, edition_year) VALUES
-- Data Structures
(2305, 'TEXT_BOOK', 'Data Structures Using C and C++', 'Yedidyah Langsam, Moshe J. Augenstein, Aaron M. Tenenbaum', 'PHI', '2nd Edition'),
(2305, 'REFERENCE_BOOK', 'Fundamentals of Data Structures in C++', 'Ellis Horowitz, Sartaj Sahni, Dinesh Mehta', 'Silicon Press', '2nd Edition'),
-- DBMS
(2403, 'TEXT_BOOK', 'Database System Concepts', 'Abraham Silberschatz, Henry F. Korth, S. Sudarshan', 'McGraw-Hill', '7th Edition'),
(2403, 'REFERENCE_BOOK', 'Fundamentals of Database Systems', 'Ramez Elmasri, Shamkant B. Navathe', 'Pearson', '7th Edition'),
-- TOC
(2404, 'TEXT_BOOK', 'Introduction to Automata Theory, Languages, and Computation', 'John E. Hopcroft, Rajeev Motwani, Jeffrey D. Ullman', 'Pearson', '3rd Edition'),
(2404, 'REFERENCE_BOOK', 'Introduction to the Theory of Computation', 'Michael Sipser', 'Cengage Learning', '3rd Edition'),
-- OS
(2503, 'TEXT_BOOK', 'Operating System Concepts', 'Abraham Silberschatz, Peter Baer Galvin, Greg Gagne', 'Wiley', '10th Edition'),
(2503, 'REFERENCE_BOOK', 'Modern Operating Systems', 'Andrew S. Tanenbaum, Herbert Bos', 'Pearson', '4th Edition'),
-- Machine Learning
(2602, 'TEXT_BOOK', 'Machine Learning', 'Tom M. Mitchell', 'McGraw-Hill', '1st Edition'),
(2602, 'TEXT_BOOK', 'An Introduction to Statistical Learning', 'Gareth James, Daniela Witten, Trevor Hastie, Robert Tibshirani', 'Springer', '2nd Edition'),
(2602, 'REFERENCE_BOOK', 'Pattern Recognition and Machine Learning', 'Christopher M. Bishop', 'Springer', '2006'),
-- Deep Learning
(2801, 'TEXT_BOOK', 'Deep Learning', 'Ian Goodfellow, Yoshua Bengio, Aaron Courville', 'MIT Press', '2016'),
(2801, 'REFERENCE_BOOK', 'Deep Learning with Python', 'Francois Chollet', 'Manning Publications', '2nd Edition'),
-- Big Data
(2701, 'TEXT_BOOK', 'Hadoop: The Definitive Guide', 'Tom White', 'O''Reilly Media', '4th Edition'),
(2701, 'REFERENCE_BOOK', 'Mining of Massive Datasets', 'Jure Leskovec, Anand Rajaraman, Jeffrey D. Ullman', 'Cambridge University Press', '3rd Edition');

COMMIT;

-- =======================================================================================
-- End of Database Creation Script for all_syllabus
-- =======================================================================================
