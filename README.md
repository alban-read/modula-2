# modula-2
modula-2 by Excelsior/xtech.


----
Tips

XDS compiles and run on Windows 10 with the MSVC compiler; either VS2015, or VS2017 when set to use the windows 8.1 SDK.
XDS strings are ascii not unicode; which helps explain some very small exe sizes.
The compilers generate 32bit code; either 386-pentium-pro native or via C translation.
These are originally from the 1990s an era when 16MB was a lot of memory for a PC.
Use the intel floating point unit; not later SSE instructions etc.
NASM is used to compile the ASM for the runtimes.
I found that openwatcom version 2 does not work; earlier versions might work.

----

Excelsior kindly open sourced their famous modula-2/oberon xds compilers.

These were picked up from 
https://github.com/excelsior-oss/xds

The components in here with source code are open sourced by Exelsior.
The components without source code include the older IDE are provided free of charge by Excelsior.
Nothing new here; some ideas in progress.

The 2.6 version of xds comes with the nice new Java Exclipse based IDE.
The open source version appears to be the 2.52 version.






