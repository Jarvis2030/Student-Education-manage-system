import psycopg2

import PortalConnection

conn = psycopg2.connect(
    host="localhost",
    database="assignment",
    user="postgres",
    password="Junelin9658")
conn.autocommit = True

def pause():
  input("Press Enter to continue...")
  print("")

if __name__ == "__main__":        
    c = PortalConnection.PortalConnection()



    # List info for a student
    print("Test 1")
    print(c.getInfo("2222222222"))
    pause()


    # Register student 2 for an unrestricted course
    print("Test 2:")
    print(c.register("2222222222", "CCC555"))
    print(c.getInfo("2222222222"))
    pause()

    # Register the student for the same course, expected to fail
    print("Test 3:")
    print(c.register("2222222222", "CCC555"))
    print(c.getInfo("2222222222"))
    pause()

    # Unregister the student twice, should give error message the second time and course should no longer be in
    # registered
    print("Test 4:")
    print(c.unregister("'2222222222'", "'CCC555'"))
    print(c.unregister("'2222222222'", "'CCC555'"))
    print(c.getInfo("2222222222"))
    pause()

    # Register student for a course where they do not posses prerequisites, should give error message and registered
    # should not contain course 2
    print("Test 5:")
    print(c.register("6666666666", "CCC222"))
    print(c.getInfo("6666666666"))
    pause()

    # Unregister then reregister student to a course with a waitinglist where it was registered, new position
    # should be 3
    print("Test 6:")
    print(c.unregister("'5555555555'", "'CCC333'"))
    print(c.register("5555555555", "CCC333"))
    print(c.getInfo("5555555555"))
    pause()

    # Unregister then reregister student that's last in the waitinglist to the same restricted course. Poistion
    # should remain 3
    print("Test 7:")
    print(c.unregister("'5555555555'", "'CCC333'"))
    print(c.register("5555555555", "CCC333"))
    print(c.getInfo("5555555555"))
    pause()

    # Unregistering a student from an overfull course where student 3 is in the waitinglist, student 3
    # should not be registered to course 4 afterwards
    print("Test 8:")
    print(c.unregister("'1111111111'", "'DDD111'"))
    print(c.getInfo("6666666666"))
    pause()

    print("Test 9")
    print(c.unregister("student OR 'a' = 'a'", "course OR 'b' = 'b'"))
    with conn.cursor() as cur:
        try:
            cur.execute("SELECT * FROM Registrations")
            for result in cur:
                print(result)
        except psycopg2.Error as e:
            print("Unexpected error") 
    