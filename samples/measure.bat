cd BENCH
mkdir testsym
mkdir sts

merins =m dry.mod
if errorlevel 1 goto error
merins =m linnew.mod
if errorlevel 1 goto error
merins =m whet.mod
if errorlevel 1 goto error
cd ..

cd DLL
mkdir testsym
mkdir sts

merins =p dll1
if errorlevel 1 goto error
merins =p dll2
if errorlevel 1 goto error
merins =p exe1
if errorlevel 1 goto error
merins =p exe2
if errorlevel 1 goto error
cd ..

cd GENERIC
mkdir testsym
mkdir sts

xrc /stb generic.rc
if errorlevel 1 goto error
merins =p generic
if errorlevel 1 goto error
cd ..

cd H2D
h2d =p example.h2d
if errorlevel 1 goto error
cd ..

cd HUFFCHAN
mkdir testsym
mkdir sts

merins =m huf.mod
if errorlevel 1 goto error
merins =m unhuf.mod
if errorlevel 1 goto error
cd ..

cd MAND
mkdir testsym
mkdir sts

merins =p mandset
if errorlevel 1 goto error
cd ..

cd MGDEMO
mkdir testsym
mkdir sts

merins =p mgdemo.prj
if errorlevel 1 goto error
cd ..

cd MODULA
mkdir testsym
mkdir sts

merins =m bf.mod
if errorlevel 1 goto error
merins =m e.mod
if errorlevel 1 goto error
merins =m except.mod
if errorlevel 1 goto error
merins =m exp.mod
if errorlevel 1 goto error
merins =m fact.mod
if errorlevel 1 goto error
merins =m halt.mod
if errorlevel 1 goto error
merins =m hello.mod
if errorlevel 1 goto error
merins =m hisdemo.mod +map +genhistory +lineno
if errorlevel 1 goto error
merins =m queens.mod
if errorlevel 1 goto error
merins =m sieve.mod
if errorlevel 1 goto error
merins =m term.mod
if errorlevel 1 goto error
cd ..

cd NODES
mkdir testsym
mkdir sts

merins =p runme
if errorlevel 1 goto error
cd ..

cd OBERON
mkdir testsym
mkdir sts

merins =m ackermann.ob2
if errorlevel 1 goto error
merins =m exp.ob2
if errorlevel 1 goto error
merins =m gcreport.ob2
if errorlevel 1 goto error
merins =m hello.ob2
if errorlevel 1 goto error
merins =m Random.ob2
if errorlevel 1 goto error
merins =m self.ob2
if errorlevel 1 goto error
merins =m sieve.ob2
if errorlevel 1 goto error
cd ..

cd PENTA
mkdir testsym
mkdir sts

xrc /stb penta.rc
if errorlevel 1 goto error
merins =p penta
if errorlevel 1 goto error
cd ..

cd WINDEMOM
mkdir testsym
mkdir sts

merins =p windemom.prj
if errorlevel 1 goto error
cd ..

goto quit

:error
echo *** FAULT ***
cd ..

:quit

