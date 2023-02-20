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


CREATE OR REPLACE VIEW CourseQueuePositions AS
(course,
student,
place
);



/* 

);
Basicinfomation + recommendedbranch UNION Basicinfomation + passcoruse
passed at least 10 credits worth of courses among the recommended courses for the branch. 
Furthermore they need to passed 20+ credits worth of courses classified as mathematical courses, 
10 credits worth of courses classified as research courses, 
and at least one seminar course. */
