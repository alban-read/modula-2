del *.exe
del *.obj
del *.sym
xc =project generic.prj
editbin /largeaddressaware generic.exe
