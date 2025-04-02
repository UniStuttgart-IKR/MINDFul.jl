## Develop always simultaneously with testing:
- create /test/multiprocess/ for that purpose
- have a script starting up several processes of MINDFul.jl
- each one might reserve a particular port. be sure to gracefully free that when done.
- have a test suite for all of them

