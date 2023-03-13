--Add another limitedcourse
INSERT INTO Courses VALUES ('CCC666', 'C6', 30, 'Dep1');
INSERT INTO LimitedCourses VALUES ('CCC666', 1);

INSERT INTO Registerations VALUES ('4444444444', 'CCC111'); --registered to an unlimited course;
INSERT INTO Registerations VALUES ('1111111111', 'CCC666'); --registered to a limited course;
INSERT INTO Registerations VALUES ('6666666666', 'CCC333');--waiting for a limited course;

INSERT INTO Registerations VALUES('4444444444', 'CCC111');
-- TEST 2 #Should not insert, does not meet the prerequisites
INSERT INTO Registerations VALUES('2222222222', 'CCC333');
-- TEST 3 #Should be inserted into the registered, course has unlimited capacity
INSERT INTO Registerations VALUES('6666666666', 'CCC111');
-- Adds a course temporarily to limited for tests 4 and 5 since there are no unfilled with the default inserts
-- TEST 4 #Should be inserted, tests if a student can be registered to a course with an unfilled capacity
INSERT INTO Registerations VALUES('5555555555', 'CCC666');
-- TEST 5 #Should insert into waiting list since the maximum capacity has already been reached
INSERT INTO Registerations VALUES('6666666666', 'CCC666');


SELECT * FROM Registered;
SELECT * FROM WaitingList;
 
---- TEST #7: Unregister from an unlimited course. 
-- EXPECTED OUTCOME: Pass
DELETE FROM Registerations WHERE Student = '1111111111' AND course = 'CCC111';

---- TEST #8: Removed from a waiting list (with additional students in it)
-- EXPECTED OUTCOME: Pass
DELETE FROM Registerations WHERE Student = '3333333333' AND course = 'CCC333';

---- TEST #9: unregistered from a limited course without a waiting list;
-- EXPECTED OUTCOME: Pass
DELETE FROM Registerations WHERE Student = '1111111111' AND course = 'CCC666';

---- TEST #10: unregistered from a limited course with a waiting list, when the student is in the middle of the waiting list;
-- EXPECTED OUTCOME: Pass
DELETE FROM Registerations WHERE Student = '1111111111' AND course = 'CCC222';

---- TEST #11:  unregistered from an overfull course with a waiting list.
-- EXPECTED OUTCOME: Pass
DELETE FROM Registerations WHERE Student = '5555555555' AND course = 'CCC333';

---- TEST #12: Unregister from the list which student doesn't exist
-- EXPECTED OUTCOME: Pass 
DELETE FROM Registerations WHERE Student = '2222222222' AND course = 'CCC666';

SELECT * FROM Registered;
SELECT * FROM WaitingList;