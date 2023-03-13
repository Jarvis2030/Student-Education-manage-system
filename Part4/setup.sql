\c assignment
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
    idnr TEXT PRIMARY KEY NOT NULL
    CHECK (idnr SIMILAR TO '[0-9]{10}'), 
    name TEXT NOT NULL, 
    login TEXT UNIQUE NOT NULL, 
    program TEXT NOT NULL REFERENCES Program(name),
	UNIQUE (idnr, program)
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

CREATE OR REPLACE VIEW BasicInformation AS (
    SELECT Students.*, branch FROM Students LEFT OUTER JOIN StudentBranches
    ON (Students.idnr = StudentBranches.student)
    ORDER BY idnr ASC
);

CREATE OR REPLACE VIEW FinishedCourses AS (
    SELECT student, course, grade, credits FROM 
    Courses JOIN Taken ON course = code
);

CREATE VIEW PassedCourses AS (
    SELECT student,course, COALESCE(credits,0) AS credits FROM FinishedCourses
    WHERE (grade != 'U')
);


CREATE VIEW Registrations AS (
    SELECT student, course, 'waiting' AS status FROM Waitinglist
    UNION
    SELECT student, course,'registered' AS status FROM Registered
    ORDER BY student
);

CREATE VIEW CourseQueuePositions AS (
	SELECT course, student, position AS place FROM WaitingList
	ORDER BY course
);

CREATE OR REPLACE VIEW UnreadMandatory AS (
    ((SELECT idnr "student", course FROM BasicInformation 
    JOIN Mandatoryprogram ON (BasicInformation.program = Mandatoryprogram.program))
    UNION
    (SELECT idnr "student", course FROM BasicInformation, Mandatorybranch 
    WHERE (BasicInformation.branch = Mandatorybranch.branch 
    AND BasicInformation.program = Mandatorybranch.program)))
    EXCEPT
    (SELECT student, course from PassedCourses)
);


CREATE OR REPLACE VIEW StudentCre AS(
    WITH
        totalcre AS (
            SELECT student, SUM(credits) AS totalCredits FROM PassedCourses
            GROUP BY student --total credit
    )
    SELECT idnr "student", totalcredits FROM Students FULL OUTER JOIN totalcre ON Students.idnr = totalcre.student
);

CREATE OR REPLACE VIEW StudentMan AS(
    WITH 
        Unreadman AS (
            SELECT student, COUNT(course) AS mandatoryLeft FROM UnreadMandatory
            GROUP BY student)
    SELECT idnr "student", mandatoryLeft FROM Students FULL OUTER JOIN Unreadman ON Students.idnr = Unreadman.student
);

CREATE OR REPLACE VIEW mathcre AS(
    SELECT student, SUM(credits) AS mathCredits FROM PassedCourses JOIN Classified ON Classified.course = PassedCourses.course
    WHERE classification = 'math'
    GROUP BY student
);
CREATE OR REPLACE VIEW researchcre AS(
    SELECT student, SUM(credits) AS researchCredits FROM PassedCourses JOIN Classified ON Classified.course = PassedCourses.course
    WHERE classification = 'research'
    GROUP BY student
);
CREATE OR REPLACE VIEW seminar AS(
    SELECT student,COUNT(classification) AS seminarCourses FROM PassedCourses JOIN Classified ON Classified.course = PassedCourses.course
    WHERE classification = 'seminar'
    GROUP BY student
);

CREATE OR REPLACE VIEW recommended AS(
    SELECT idnr "student", course FROM BasicInformation, Recommendedbranch 
    WHERE (BasicInformation.branch = Recommendedbranch.branch 
    AND BasicInformation.program = Recommendedbranch.program)
);

CREATE OR REPLACE VIEW passedrecommended AS(
    SELECT recommended.student, SUM(credits) AS totalreCredits FROM 
    PassedCourses, recommended
    WHERE (recommended.student = PassedCourses.student
    AND recommended.course = PassedCourses.course)
    GROUP BY recommended.student
);

CREATE OR REPLACE VIEW PathToGraduation AS (
WITH
graducationinfo AS (
    SELECT StudentCre.student, 
    COALESCE(totalcredits,0) AS totalCredits, 
    COALESCE(mandatoryLeft,0) AS mandatoryLeft, 
    COALESCE(mathCredits,0) AS mathCredits, 
    COALESCE(researchCredits,0) AS researchCredits,  
    COALESCE(seminarCourses,0) AS seminarCourses,
    COALESCE(totalreCredits,0) AS totalreCredits
    FROM 
    StudentCre
    FULL OUTER JOIN 
    StudentMan ON StudentCre.student = StudentMan.student
    FULL OUTER JOIN
    mathcre ON StudentCre.student = mathcre.student
    FULL OUTER JOIN
    researchcre ON StudentCre.student = researchcre.student
    FULL OUTER JOIN
    seminar ON StudentCre.student = seminar.student
    FULL OUTER JOIN
    passedrecommended ON StudentCre.student = passedrecommended.student
    ORDER BY student
),
cangraduate AS (
    SELECT graducationinfo.*, TRUE AS qualified FROM graducationinfo
    WHERE(totalreCredits >= 10 AND mandatoryleft = 0 AND mathCredits >= 20 AND researchCredits >= 10 AND seminarCourses >=1)
)

SELECT graducationinfo.student, graducationinfo.totalCredits, graducationinfo.mandatoryLeft, graducationinfo.mathCredits, graducationinfo.researchCredits, graducationinfo.seminarCourses, COALESCE(qualified,FALSE) AS qualified FROM graducationinfo FULL OUTER JOIN cangraduate ON graducationinfo.student = cangraduate.student
);

INSERT INTO Program VALUES ('Prog1', 'P1');
INSERT INTO Program VALUES ('Prog2', 'P2');

INSERT INTO Department VALUES('Dep1', 'D1');

INSERT INTO Branches VALUES ('B1','Prog1');
INSERT INTO Branches VALUES ('B2','Prog1');
INSERT INTO Branches VALUES ('B1','Prog2');

INSERT INTO Students VALUES ('1111111111','N1','ls1','Prog1');
INSERT INTO Students VALUES ('2222222222','N2','ls2','Prog1');
INSERT INTO Students VALUES ('3333333333','N3','ls3','Prog2');
INSERT INTO Students VALUES ('4444444444','N4','ls4','Prog1');
INSERT INTO Students VALUES ('5555555555','Nx','ls5','Prog2');
INSERT INTO Students VALUES ('6666666666','Nx','ls6','Prog2');

INSERT INTO Courses VALUES ('CCC111','C1',22.5,'Dep1');
INSERT INTO Courses VALUES ('CCC222','C2',20,'Dep1');
INSERT INTO Courses VALUES ('CCC333','C3',30,'Dep1');
INSERT INTO Courses VALUES ('CCC444','C4',60,'Dep1');
INSERT INTO Courses VALUES ('CCC555','C5',50,'Dep1');

INSERT INTO LimitedCourses VALUES ('CCC222',1);
INSERT INTO LimitedCourses VALUES ('CCC333',2);

INSERT INTO Classifications VALUES ('math');
INSERT INTO Classifications VALUES ('research');
INSERT INTO Classifications VALUES ('seminar');

INSERT INTO Classified VALUES ('CCC333','math');
INSERT INTO Classified VALUES ('CCC444','math');
INSERT INTO Classified VALUES ('CCC444','research');
INSERT INTO Classified VALUES ('CCC444','seminar');


INSERT INTO StudentBranches VALUES ('2222222222','B1','Prog1');
INSERT INTO StudentBranches VALUES ('3333333333','B1','Prog2');
INSERT INTO StudentBranches VALUES ('4444444444','B1','Prog1');
INSERT INTO StudentBranches VALUES ('5555555555','B1','Prog2');

INSERT INTO MandatoryProgram VALUES ('CCC111','Prog1');

INSERT INTO MandatoryBranch VALUES ('CCC333', 'B1', 'Prog1');
INSERT INTO MandatoryBranch VALUES ('CCC444', 'B1', 'Prog2');

INSERT INTO RecommendedBranch VALUES ('CCC222', 'B1', 'Prog1');
INSERT INTO RecommendedBranch VALUES ('CCC333', 'B1', 'Prog2');

INSERT INTO Prerequisite VALUES('CCC333', 'CCC111');
INSERT INTO Prerequisite VALUES('CCC333', 'CCC222');
INSERT INTO Prerequisite VALUES('CCC222', 'CCC111');

INSERT INTO Taken VALUES('4444444444','CCC111','5');
INSERT INTO Taken VALUES('4444444444','CCC222','5');
INSERT INTO Taken VALUES('4444444444','CCC333','5');
INSERT INTO Taken VALUES('4444444444','CCC444','5');

INSERT INTO Taken VALUES('5555555555','CCC111','5');
INSERT INTO Taken VALUES('5555555555','CCC222','4');
INSERT INTO Taken VALUES('5555555555','CCC444','3');

INSERT INTO Taken VALUES('2222222222','CCC111','U');
INSERT INTO Taken VALUES('2222222222','CCC222','U');
INSERT INTO Taken VALUES('2222222222','CCC444','U');

INSERT INTO Registered VALUES ('1111111111','CCC111');
INSERT INTO Registered VALUES ('1111111111','CCC222');
INSERT INTO Registered VALUES ('1111111111','CCC333');
INSERT INTO Registered VALUES ('2222222222','CCC222');
INSERT INTO Registered VALUES ('5555555555','CCC222');
INSERT INTO Registered VALUES ('5555555555','CCC333');

INSERT INTO WaitingList VALUES('3333333333','CCC222',1);
INSERT INTO WaitingList VALUES('3333333333','CCC333',1);
INSERT INTO WaitingList VALUES('2222222222','CCC333',2);

-- Adds a course temporarily to limited for tests 4 and 5 since there are no unfilled with the default inserts
INSERT INTO LimitedCourses VALUES('CCC555', 1);

-- Insert a new course that is limited for testing removals
INSERT INTO Courses VALUES('CCC666', 'C6', 30, 'Dep1');
INSERT INTO LimitedCourses VALUES('CCC666', 1);

INSERT INTO WaitingList VALUES('6666666666', 'CCC333', 3);
INSERT INTO Registered VALUES ('1111111111', 'CCC666');

--Insert a overfull class for testing 
INSERT INTO Courses VALUES('DDD111', 'D1', 22.5, 'Dep1');
INSERT INTO LimitedCourses VALUES('DDD111', 2);
INSERT INTO Registered VALUES ('1111111111', 'DDD111');
INSERT INTO Registered VALUES ('2222222222', 'DDD111');
INSERT INTO Registered VALUES ('4444444444', 'DDD111');

INSERT INTO WaitingList VALUES('6666666666', 'DDD111', 1);

CREATE VIEW finished AS (
    SELECT Courses.name, course, student, grade, Finishedcourses.credits FROM 
    FinishedCourses JOIN Courses ON course = code
);