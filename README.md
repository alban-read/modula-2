# modula-2

modula-2 by Excelsior/xtech.


----
Tips

XDS compiles and run on the latest versions of Windows 10.

Works with the MSVC compiler; either VS2015, or VS2017 when set to use the windows 8.1 SDK.

XDS strings are ascii not unicode; which helps explain some very small exe sizes.

The compilers generate 32bit code; either 386-pentium-pro native or via C translation.

These are originally from the 1990s an era when 16MB was a lot of memory for a PC.

I suspect on 64bit Windows 10; you might be able to get as much as 4GB ram per process; if you update the exe.

e.g. editbin /largeaddressaware my.exe 

And also update the heap limit parameters set to a max of 1128MB in the runtime objects.

XDS uses the intel floating point unit; not later SSE instructions etc.

NASM is used to compile the ASM for the runtimes.

I found that modern openwatcom C version 2 does not work; earlier versions might work.

The design of the XDS compilers separates the front end languages (oberon-2 and modula-2) from the backends

(x86 and ansi C) there were many backends available commercially; back in the day.  

The XDS compilers are written in modula-2, oberon-2, C and x86 asm.

The versions of the source languages are modula-2 ISO10514 and oberon-2.

modula-2 is an imperative procedural modular structured language in the pascal family; oberon is similar, smaller; even more minimal with simple object orientation extensions.

The XDS compilers will compile a project that contains modules written in both languages.


----

Excelsior kindly open sourced their famous modula-2 and oberon-2 xds compilers.

The XDS compilers have been available as binary packages free of charge for a number of years.


These artefacts were picked up from 

https://github.com/excelsior-oss/xds

https://github.com/excelsior-oss/xds-ide

And possibly earlier binary archives from the Excelsior site back in the day.

The components in here with source code are open sourced by Exelsior (see links above.)

The components without source code include the older IDE were provided free of charge by Excelsior.
 
The 2.6 version of xds comes included as the SDK with the modern Java Eclipse based IDE.


The open source version of XDS compilers/debuggers/linkers/resource builder appear to be the 2.52 version.






