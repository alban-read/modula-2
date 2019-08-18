cd DLL

mkdir testsym
mkdir log

octins =p dll1
if errorlevel 1 goto error
xc =p =a dll1
if errorlevel 1 goto error

octins =p dll2
if errorlevel 1 goto error
xc =p =a dll2
if errorlevel 1 goto error

octins =p exe1
if errorlevel 1 goto error
xc =p =a exe1
if errorlevel 1 goto error

octins =p exe2
if errorlevel 1 goto error
xc =p =a exe2
if errorlevel 1 goto error
cd ..

cd GENERIC

mkdir testsym
mkdir log

xrc /stb generic.rc
if errorlevel 1 goto error
octins =p generic
if errorlevel 1 goto error
xc =p =a generic
if errorlevel 1 goto error
cd ..

cd H2D
h2d =p example.h2d
if errorlevel 1 goto error
cd ..

cd HUFFCHAN
mkdir testsym
mkdir log

octins =m huf.mod
if errorlevel 1 goto error
xc =m huf.mod
if errorlevel 1 goto error

octins =m unhuf.mod
if errorlevel 1 goto error
xc =m unhuf.mod
if errorlevel 1 goto error
cd ..

cd MAND

mkdir testsym
mkdir log

octins =p mandset
if errorlevel 1 goto error
xc =a =p mandset
if errorlevel 1 goto error
cd ..

cd MGDEMO
mkdir testsym
mkdir log

octins =p mgdemo.prj
if errorlevel 1 goto error
xc =a =p mgdemo.prj
if errorlevel 1 goto error
cd ..

cd MODULA
mkdir testsym
mkdir log

octins =m bf.mod
if errorlevel 1 goto error
xc =m bf.mod
if errorlevel 1 goto error

octins =m e.mod
if errorlevel 1 goto error
xc =m e.mod
if errorlevel 1 goto error

octins =m except.mod
if errorlevel 1 goto error
xc =m except.mod
if errorlevel 1 goto error

octins =m exp.mod
if errorlevel 1 goto error
xc =m exp.mod
if errorlevel 1 goto error


octins =m fact.mod
if errorlevel 1 goto error
xc =m fact.mod
if errorlevel 1 goto error

octins =m halt.mod
if errorlevel 1 goto error
xc =m halt.mod
if errorlevel 1 goto error

octins =m hello.mod
if errorlevel 1 goto error
xc =m hello.mod
if errorlevel 1 goto error

octins =m hisdemo.mod +map +genhistory +lineno
if errorlevel 1 goto error
xc =m hisdemo.mod +map +genhistory +lineno
if errorlevel 1 goto error

octins =m queens.mod
if errorlevel 1 goto error
xc =m queens.mod
if errorlevel 1 goto error

octins =m sieve.mod
if errorlevel 1 goto error
xc =m sieve.mod
if errorlevel 1 goto error

octins =m term.mod
if errorlevel 1 goto error
xc =m term.mod
if errorlevel 1 goto error

cd ..

cd NODES
mkdir testsym
mkdir log

octins =p runme
if errorlevel 1 goto error
xc =a =p runme
if errorlevel 1 goto error
cd ..

cd OBERON
mkdir testsym
mkdir log

octins ackermann.ob2
if errorlevel 1 goto error
xc =m =a ackermann.ob2
if errorlevel 1 goto error

octins =m exp.ob2
if errorlevel 1 goto error
xc =m =a exp.ob2
if errorlevel 1 goto error

octins =m gcreport.ob2
if errorlevel 1 goto error
xc =m =a gcreport.ob2
if errorlevel 1 goto error

octins =m hello.ob2
if errorlevel 1 goto error
xc =m =a hello.ob2
if errorlevel 1 goto error

octins =m Random.ob2
if errorlevel 1 goto error
xc =m =a Random.ob2
if errorlevel 1 goto error

octins =m self.ob2
if errorlevel 1 goto error
xc =m =a self.ob2
if errorlevel 1 goto error

octins =m sieve.ob2
if errorlevel 1 goto error
xc =m =a sieve.ob2
if errorlevel 1 goto error

cd ..

cd PENTA
mkdir testsym
mkdir log

xrc /stb penta.rc
if errorlevel 1 goto error
xrc /stb penta.rc
if errorlevel 1 goto error

octins =p penta
if errorlevel 1 goto error
xc =p =a penta
if errorlevel 1 goto error

cd ..

cd WINDEMOM
mkdir testsym
mkdir log

octins =p windemom.prj
if errorlevel 1 goto error
xc =a =p windemom.prj
if errorlevel 1 goto error
cd ..

goto quit

:error
echo *** FAULT ***
cd ..

:quit

