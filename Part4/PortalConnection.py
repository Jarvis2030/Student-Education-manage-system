import psycopg2
import json

conn = psycopg2.connect(
    host="localhost",
    database="assignment",
    user="postgres",
    password="Junelin9658")
conn.autocommit = True


class PortalConnection:

    def getInfo(self, student):
        info_object = InfoObject(student)
        return json.dumps(info_object.__dict__, default=obj_dict, indent=2)

    def register(self, student, courseCode):
        try:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO Registrations VALUES('%s', '%s')" % (student, courseCode))
                return '{"success":true}'
        except psycopg2.Error as e:
            message = getError(e)
            return '{"success":false, "error": "' + message + '"}'

    def unregister(self, student, courseCode):
        try:
            with conn.cursor() as cur:
                if self.exists(student, courseCode):
                    print("DELETE FROM Registrations WHERE student =%s AND course =%s" % (student, courseCode))
                    cur.execute("DELETE FROM Registrations WHERE student =%s AND course =%s" % (student, courseCode))
                    return '{"success":true}'
                else:
                    return '{"success":false} student did not register to the course'
        except psycopg2.Error as e:
            return 'Unexpected error'

    def exists(self, student, courseCode):
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT student FROM Registrations WHERE (student =%s AND course =%s)" %
                            (student, courseCode))
                return cur.fetchone() is not None
        except psycopg2.Error as e:
            return 'Unexpected error, should return true or false'




def getError(e):
    message = repr(e)
    message = message.replace("\\n", " ")
    message = message.replace("\"", "\\\"")
    return message


def obj_dict(obj):
    return obj.__dict__


class InfoObject:
    def __init__(self, student):
        self.student = student
        self.name = None
        self.login = None
        self.program = None
        self.branch = None
        self.finished = []
        self.registered = []
        self.get_info()

    def get_info(self):
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM BasicInformation WHERE (idnr = %s )", (self.student,))
                data = cur.fetchone()
                self.name = data[1]
                self.login = data[2]
                self.program = data[3]
                self.branch = data[4]
                self.get_finished(cur)
                self.get_registered(cur)
                cur.execute("SELECT seminarcourses, mathcredits, researchcredits, totalcredits, qualified FROM "
                            "PathToGraduation WHERE student = %s", (self.student,))
                data = cur.fetchone()
                self.seminarCourses = data[0]
                self.mathCredits = data[1]
                self.researchCredits = data[2]
                self.totalCredits = data[3]
                self.canGraduate = bool(data[4])
        except psycopg2.Error as e:
            return 'Something went wrong: ' + getError(e)

    def get_finished(self, cur):
        cur.execute("SELECT name, course, grade, credits FROM Finished WHERE (student = %s)", (self.student,))
        for course in cur:
            self.finished.append(PassedCourse(course[0], course[1], course[3], course[2]))

    def get_registered(self, cur):
        cur.execute(
            "SELECT name, Registrations.course, status, place FROM Registrations "
            "JOIN Courses ON course = code LEFT OUTER JOIN CourseQueuePositions ON "
            "(CourseQueuePositions.course = Registrations.course AND "
            "CourseQueuePositions.student = Registrations.student) WHERE Registrations.student = %s",
            (self.student,))
        for course in cur:
            if course[2] == "waiting":
                reg_course = RegisteredCourse(course[0], course[1], course[2], course[3])
            else:
                reg_course = RegisteredCourse(course[0], course[1], course[2])
            self.registered.append(reg_course)


class PassedCourse:
    def __init__(self, course, code, credit, grade):
        self.course = course
        self.code = code
        self.credits = credit
        self.grade = grade


class RegisteredCourse:
    def __init__(self, course, code, status, position=None):
        self.course = course
        self.code = code
        self.status = status
        self.position = position