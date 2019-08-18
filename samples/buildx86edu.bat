cd BENCH
xc =m dry.mod
if errorlevel 1 goto error
xc =m linnew.mod
if errorlevel 1 goto error
xc =m whet.mod
if errorlevel 1 goto error
cd ..

cd HUFFCHAN
xc =m huf.mod
if errorlevel 1 goto error
xc =m unhuf.mod
if errorlevel 1 goto error
cd ..

cd MGDEMO
xc =p mgdemo.prj
if errorlevel 1 goto error
cd ..

cd MODULA
xc =m bf.mod
if errorlevel 1 goto error
xc =m e.mod
if errorlevel 1 goto error
xc =m except.mod
if errorlevel 1 goto error
xc =m exp.mod
if errorlevel 1 goto error
xc =m fact.mod
if errorlevel 1 goto error
xc =m halt.mod
if errorlevel 1 goto error
xc =m hello.mod
if errorlevel 1 goto error
xc =m hisdemo.mod +map +genhistory +lineno
if errorlevel 1 goto error
xc =m queens.mod
if errorlevel 1 goto error
xc =m sieve.mod
if errorlevel 1 goto error
xc =m term.mod
if errorlevel 1 goto error
cd ..

cd NODES
xc =p runme
if errorlevel 1 goto error
cd ..

cd OBERON
xc =m ackermann.ob2
if errorlevel 1 goto error
xc =m exp.ob2
if errorlevel 1 goto error
xc =m gcreport.ob2
if errorlevel 1 goto error
xc =m hello.ob2
if errorlevel 1 goto error
xc =m Random.ob2
if errorlevel 1 goto error
xc =m self.ob2
if errorlevel 1 goto error
xc =m sieve.ob2
if errorlevel 1 goto error
cd ..

cd VTERM
xc =p golygon.prj
if errorlevel 1 goto error
cd ..

cd WINDEMOM
xc =p windemom.prj
if errorlevel 1 goto error
cd ..

goto quit

:error
echo *** FAULT ***
cd ..

:quit

