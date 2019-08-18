cd DLL
octrun =dr dllsrc\dll1
if errorlevel 1 goto error
octrun =dr dllsrc\dll2
if errorlevel 1 goto error
octrun =dr exesrc\exe1
if errorlevel 1 goto error
octrun =dr exesrc\exe2
if errorlevel 1 goto error
cd ..

cd GENERIC
xrc /stb generic.rc
if errorlevel 1 goto error
octrun =dr generic
if errorlevel 1 goto error
cd ..

cd HUFFCHAN
octrun =dr huf.mod
if errorlevel 1 goto error
octrun =dr unhuf.mod
if errorlevel 1 goto error
cd ..

cd MAND
octrun =dr mandset
if errorlevel 1 goto error
cd ..

cd MGDEMO
octrun =dr mgdemo.prj
if errorlevel 1 goto error
cd ..

cd MODULA
octrun =dr bf.mod
if errorlevel 1 goto error
octrun =dr e.mod
if errorlevel 1 goto error
octrun =dr except.mod
if errorlevel 1 goto error
octrun =dr exp.mod
if errorlevel 1 goto error
octrun =dr fact.mod
if errorlevel 1 goto error
octrun =dr halt.mod
if errorlevel 1 goto error
octrun =dr hello.mod
if errorlevel 1 goto error
octrun =dr hisdemo.mod +map +genhistory +lineno
if errorlevel 1 goto error
octrun =dr queens.mod
if errorlevel 1 goto error
octrun =dr sieve.mod
if errorlevel 1 goto error
octrun =dr term.mod
if errorlevel 1 goto error
cd ..

cd NODES
octrun =dr runme
if errorlevel 1 goto error
cd ..

cd OBERON
octrun =dr ackermann.ob2
if errorlevel 1 goto error
octrun =dr exp.ob2
if errorlevel 1 goto error
octrun =dr gcreport.ob2
if errorlevel 1 goto error
octrun =dr hello.ob2
if errorlevel 1 goto error
octrun =dr Random.ob2
if errorlevel 1 goto error
octrun =dr self.ob2
if errorlevel 1 goto error
octrun =dr sieve.ob2
if errorlevel 1 goto error
cd ..

cd PENTA
xrc /stb penta.rc
if errorlevel 1 goto error
octrun =dr penta
if errorlevel 1 goto error
cd ..

cd WINDEMOM
octrun =dr windemom.prj
if errorlevel 1 goto error
cd ..

goto quit

:error
echo *** FAULT ***
cd ..

:quit

