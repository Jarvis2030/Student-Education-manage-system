CREATE OR REPLACE FUNCTION allowToRegister() RETURNS TRIGGER AS $$
DECLARE
	unpassed INT;
	cap INT;
	reg INT;
	nextPos INT;
	skip BOOLEAN = false;
BEGIN
	CREATE TEMP TABLE Pre AS(SELECT prerequisite FROM Prerequisite WHERE (Prerequisite.course = NEW.course));
	CREATE TEMP TABLE Pass AS(SELECT course FROM PassedCourses WHERE (PassedCourses.student = NEW.Student));
	
	IF (NEW.course IN (SELECT * FROM Pass)) THEN
		RAISE EXCEPTION 'Student has already passed this course';
		skip := true;
	END IF;
	
	unpassed := (SELECT COUNT(*) FROM Pre WHERE prerequisite NOT IN (SELECT * FROM pass));
	DROP TABLE Pre;
	DROP TABLE Pass;
	
	IF (unpassed > 0) THEN
		RAISE EXCEPTION 'Student is missing prerequisite course(s): %', unpassed;
		skip := true;
	END IF;
	
	IF (skip) THEN
	ELSEIF EXISTS(SELECT student FROM Registrations WHERE(NEW.student = Registrations.student AND NEW.course = Registrations.course)) THEN --Check if the stduent has registered
        RAISE EXCEPTION 'Student has registered to the course';
    ELSEIF EXISTS (SELECT code FROM LimitedCourses WHERE (LimitedCourses.code = NEW.course)) THEN --Check if the course is LimitedCourse
        RAISE NOTICE 'Course limited';
        cap := (SELECT capacity FROM LimitedCourses WHERE (NEW.course = LimitedCourses.code)); -- Find its capacity
        reg := (SELECT COUNT(*) FROM Registered WHERE (Registered.course = NEW.course)); -- Find the total registered amount now
        IF (reg >= cap) THEN -- Check if there is still capacity
            nextPos := (SELECT COUNT(*) FROM Waitinglist WHERE (NEW.course = Waitinglist.course)) + 1;
			RAISE NOTICE 'Student is in waitinglist at position: %', nextPos;
            INSERT INTO Waitinglist VALUES (NEW.student, NEW.course, nextPos);
        ELSE
        INSERT INTO Registered VALUES (NEW.student, NEW.course);
        RAISE NOTICE 'Student now registered to Course: %', NEW.course;
        END IF;
    ELSE
        INSERT INTO Registered VALUES (NEW.student, NEW.course);
        RAISE NOTICE 'Course unlimited';
    END IF;
	RETURN NULL;		
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER onInsertRegister 
	INSTEAD OF INSERT ON Registrations
	FOR EACH ROW
	EXECUTE FUNCTION allowToRegister();

CREATE FUNCTION unregistered() RETURNS TRIGGER AS $$
DECLARE
waitingstudent TEXT;
oldposition INT;
cap INT;
reg INT;
BEGIN
    IF EXISTS(SELECT student FROM Registrations WHERE(OLD.student = Registrations.student AND OLD.course = Registrations.course AND Registrations.status = 'registered'))
    THEN
        cap := (SELECT capacity FROM LimitedCourses WHERE (OLD.course = LimitedCourses.code));
        reg := (SELECT COUNT(*) FROM Registered WHERE (Registered.course = OLD.course));
        RAISE NOTICE ' % and %', cap, reg;
        IF EXISTS(SELECT student from WaitingList WHERE (OLD.course = WaitingList.course AND position = 1)) AND (cap > reg) THEN
            waitingstudent := (SELECT student from WaitingList WHERE (OLD.course = WaitingList.course AND position = 1));
            INSERT INTO Registered VALUES (waitingstudent, OLD.course); -- put the position 1 waiting student into the registered list
            DELETE FROM WaitingList WHERE (OLD.course = WaitingList.course AND WaitingList.position = 1);
            UPDATE WaitingList SET position = position-1 WHERE (OLD.course = WaitingList.course); -- All waitlist position for this course move forward 1
            DELETE FROM Registered WHERE (OLD.student = Registered.student AND OLD.course = Registered.course); -- Delete the student from registered list
            RAISE NOTICE 'Remove % from Registrations list of course %', OLD.student, OLD.course;
            RAISE NOTICE '% is now registered into the course %', waitingstudent, OLD.course;
        ELSE
            RAISE NOTICE 'Remove % from Registrations list of course %', OLD.student, OLD.course;
             DELETE FROM Registered WHERE (OLD.student = Registered.student AND OLD.course = Registered.course); -- Delete the student from registered list
        END IF;
    ELSEIF EXISTS(SELECT student FROM Registrations WHERE(OLD.student = Registrations.student AND OLD.course = Registrations.course AND Registrations.status = 'waiting'))
    THEN
        oldposition := (SELECT position FROM WaitingList WHERE (OLD.student = WaitingList.student AND OLD.course = WaitingList.course)); -- store the student's original pos
        DELETE FROM WaitingList WHERE (OLD.student = WaitingList.student AND OLD.course = WaitingList.course); -- delete from the waitinglist
        UPDATE WaitingList SET position = position-1
        WHERE (OLD.course = WaitingList.course AND position > oldposition); -- update all the student's pos behind him/her
        RAISE NOTICE 'Remove % from Waitinglist of course %', OLD.student, OLD.course;
    ELSE
        RAISE EXCEPTION 'The student didnt registered the course';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER beforeunregister
INSTEAD OF DELETE ON Registrations
FOR EACH ROW
EXECUTE FUNCTION unregistered();
