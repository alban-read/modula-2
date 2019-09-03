del *.exe
del *.obj
del *.sym
xc =project testmemoryusage.prj
editbin /largeaddressaware testmemoryusage.exe
