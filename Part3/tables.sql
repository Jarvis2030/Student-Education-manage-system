\c portal
\set QUIT true
SET client_min_messages TO NOTICE;
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
\set QUIET false

CREATE TABLE Program(
	name TEXT PRIMARY KEY,
	abbreviation CHAR(2) NOT NULL);
	
CREATE TABLE Department(
	name TEXT PRIMARY KEY,
	abbreviation CHAR(2) UNIQUE NOT NULL);
	
CREATE TABLE HostedBy(
	department TEXT NOT NULL REFERENCES Department(name),
	program TEXT NOT NULL REFERENCES Program(name),
	PRIMARY KEY(department, program)
);

--student info
CREATE TABLE Students(
    idnr TEXT UNIQUE NOT NULL
    CHECK (idnr SIMILAR TO '[0-9]{10}'), 
    name TEXT NOT NULL, 
    login TEXT UNIQUE NOT NULL, 
    program TEXT NOT NULL REFERENCES Program(name),
	PRIMARY KEY(idnr, program)
);

--Branches define which program should the branch belongs to
CREATE TABLE Branches(
    name TEXT NOT NULL, 
    program TEXT NOT NULL REFERENCES Program(name),
    PRIMARY KEY(name, program)
); 

-- Course info
CREATE TABLE Courses(
    code TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    credits FLOAT NOT NULL, 
    department TEXT NOT NULL REFERENCES Department(name)
); 

--This shows the courses that are fulled and its capacity
CREATE TABLE LimitedCourses(
    code TEXT NOT NULL REFERENCES Courses(code) PRIMARY KEY, 
    capacity INT NOT NULL,
    CONSTRAINT no_negative_capacity CHECK (0 <= capacity)
);
 
--connected student and branches to store the student's branch
CREATE TABLE StudentBranches(
    student TEXT NOT NULL PRIMARY KEY REFERENCES Students(idnr), 
    branch TEXT NOT NULL, 
    program TEXT NOT NULL,
    FOREIGN KEY (branch, program) REFERENCES Branches(name,program),
	FOREIGN KEY (student, program) REFERENCES Students(idnr, program)
);
  --(branch, program) → Branches.(name, program) 

--Stored the types of course classfication
CREATE TABLE Classifications(
    name TEXT NOT NULL PRIMARY KEY
    ); 

-- connect to classification, shows which type of courses it is
CREATE TABLE Classified(
    course TEXT NOT NULL REFERENCES Courses(code), 
    classification TEXT NOT NULL REFERENCES Classifications(name),
    PRIMARY KEY(course,classification)); 

--Defined the mandatory courses of program
CREATE TABLE MandatoryProgram(
    course TEXT NOT NULL REFERENCES Courses(code), 
    program TEXT NOT NULL REFERENCES Program(name),
    PRIMARY KEY(course, program)); 

--Defined the additiona mandatory courses for the branch
CREATE TABLE MandatoryBranch(
    course TEXT NOT NULL REFERENCES Courses(code), 
    branch TEXT NOT NULL, 
    program TEXT NOT NULL,
    FOREIGN KEY (branch, program) REFERENCES Branches(name,program),
    PRIMARY KEY(course, branch, program)); 
  --(branch, program) → Branches.(name, program) 

--
CREATE TABLE RecommendedBranch(
    course TEXT NOT NULL REFERENCES Courses(code), 
    branch TEXT NOT NULL, 
    program TEXT NOT NULL,
    FOREIGN KEY (branch, program) REFERENCES Branches(name,program),
    PRIMARY KEY(course, branch, program));  
 --(branch, program) → Branches.(name, program) 

--Students' course registeration
CREATE TABLE Registered(
    student TEXT NOT NULL REFERENCES Students(idnr), 
    course TEXT NOT NULL REFERENCES Courses(code),
    PRIMARY KEY(student, course)); 

--Students who finished the courses and their grade
CREATE TABLE Taken(
    student TEXT NOT NULL REFERENCES Students(idnr), 
    course TEXT NOT NULL REFERENCES Courses(code), 
    grade CHAR(1) NOT NULL CHECK (grade IN ('U','3','4','5')),
    PRIMARY KEY(student, course)); 
 
-- position is either a SERIAL, a TIMESTAMP or the actual position 
CREATE TABLE WaitingList(
    student TEXT NOT NULL REFERENCES Students(idnr), 
    course TEXT NOT NULL REFERENCES Limitedcourses(code), 
    position SERIAL,
    UNIQUE(course, position),
	CONSTRAINT valid_position CHECK (0 < position),
    PRIMARY KEY(student, course)); 
	
CREATE TABLE Prerequisite(
	course TEXT NOT NULL REFERENCES Courses(code),
	prerequisite TEXT NOT NULL REFERENCES Courses(code),
	CONSTRAINT no_self_prerequisite CHECK (course != prerequisite),
	PRIMARY KEY(course, prerequisite)
);

