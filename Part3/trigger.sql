\c portal
\set QUIT true
SET client_min_messages TO NOTICE;
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
\set QUIET false


\i tables.sql
\i inserts.sql
\i views.sql


CREATE OR REPLACE VIEW CourseQueuePositions AS(
    SELECT * FROM WaitingList
);


--Function 1:
--part 1: 
--Check the availbiltiy by SELECT student,course FROM passcoursed where passcoursed.student = NEW.student
-- SELECT prerequisite FROM prerequeisite 

CREATE OR REPLACE FUNCTION allowToRegister() RETURNS TRIGGER AS $$
DECLARE
	cap INT;
	reg INT;
	nextPos INT;
BEGIN
    --RAISE NOTICE 'The function starts';
    IF EXISTS(SELECT student FROM Registerations WHERE(NEW.student = Registerations.student AND NEW.course = Registerations.course)) THEN --Check if the stduent has registered
        RAISE NOTICE 'Student has registered to the course';
	ELSEIF EXISTS (SELECT code FROM LimitedCourses WHERE (LimitedCourses.code = NEW.course)) THEN --Check if the course is LimitedCourse
        --RAISE NOTICE 'Course limited';
		cap := (SELECT capacity FROM LimitedCourses WHERE (NEW.course = LimitedCourses.code)); -- Find its capacity
		reg := (SELECT COUNT(*) FROM Registered WHERE (Registered.course = NEW.course)); -- Find the total registered amount now
		IF (reg >= cap) THEN -- Check if there is still capacity
			nextPos := (SELECT COUNT(*) FROM Waitinglist WHERE (NEW.course = Waitinglist.course)) + 1; 
			INSERT INTO Waitinglist VALUES (NEW.student, NEW.course, nextPos);
        
        ELSE INSERT INTO Registered VALUES (NEW.student, NEW.course);
		END IF;
    ELSE
        --RAISE NOTICE 'Course unlimited'; 
        INSERT INTO Registered VALUES (NEW.student, NEW.course);
	END IF;
	RETURN NEW;		
END;
$$ LANGUAGE plpgsql;


--Trigger 1: 
--check that the student may actually register (function 1)
--for the course before adding him/her to the course or the waiting list, 
--if it may not you should raise an error
--view: student, course, status

CREATE TRIGGER checkAvailabiltiy 
INSTEAD OF INSERT ON registerations
FOR EACH ROW
EXECUTE FUNCTION allowToRegister();


--Function 2:
--check whether is in waiting list or registered list
--if waiting: delete the student, all position-1
--if register: Add the position 1 student to registered list, all position-1

CREATE FUNCTION unregistered() RETURNS TRIGGER AS $$

DECLARE 
waitingstudent TEXT;
oldposition INT;

BEGIN
    IF EXISTS(SELECT student FROM Registerations WHERE(OLD.student = Registerations.student AND OLD.course = Registerations.course AND Registerations.status = 'registered'))
    THEN
        
        IF EXISTS(SELECT student from WaitingList WHERE (OLD.course = WaitingList.course AND position = 1)) THEN
            waitingstudent := (SELECT student from WaitingList WHERE (OLD.course = WaitingList.course AND position = 1));
            INSERT INTO Registered VALUES (waitingstudent, OLD.course); -- put the position 1 waiting student into the registered list
            DELETE FROM WaitingList WHERE (OLD.course = WaitingList.course AND WaitingList.position = 1);
            UPDATE WaitingList SET position = position-1 WHERE (OLD.course = WaitingList.course); -- All waitlist position for this course move forward 1
        END IF;
        DELETE FROM Registered WHERE (OLD.student = Registered.student AND OLD.course = Registered.course); -- Delete the student from registered list

    ELSEIF EXISTS(SELECT student FROM Registerations WHERE(OLD.student = Registerations.student AND OLD.course = Registerations.course AND Registerations.status = 'waiting'))
    THEN
        oldposition := (SELECT position FROM WaitingList WHERE (OLD.student = WaitingList.student AND OLD.course = WaitingList.course)); -- store the student's original pos
        DELETE FROM WaitingList WHERE (OLD.student = WaitingList.student AND OLD.course = WaitingList.course); -- delete from the waitinglist
        UPDATE WaitingList SET position = position-1 
        WHERE (OLD.course = WaitingList.course AND position > oldposition); -- update all the student's pos behind him/her
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;


--Tigger 2:
--unregistered (this includes being removed from the waiting list) 
--by deleting him/her from the Registrations view. If removing the student opens up a spot in the course,
-- the first student (if any) in the waiting list should be registered for the course instead.

CREATE TRIGGER beforeunregister
INSTEAD OF DELETE ON registerations
FOR EACH ROW 
EXECUTE FUNCTION unregistered();