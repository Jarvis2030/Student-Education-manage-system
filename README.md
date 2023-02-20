# Student-Education-manage-system
--Introduction
The is a course project aiming to provide hand-on exercise in practicing the usage of PostgresSQL. The management system is created for the university to manage the student infomation, student study pathway (including manatory courses from belonged program and branch), course registeration status and the graducation requirement.
The system can be divided into backend and frondend:

-Backend:
1. ER model, FD and Table creating
  ![ER](https://user-images.githubusercontent.com/77675271/220145316-6d810f1c-3cb7-4d06-aa54-07eab3c630ac.png)
The ER model and FD schema helps clarify the relationship based on the problem description.
2. Trigger and functions
We include 2 trigger functions in part3 file to manage the course registeration, it will automatically reallocate the student from waitinglist and registered list after the client-side submit the registered request.

-Frondend:
1. Server connection

2.Backend connection
