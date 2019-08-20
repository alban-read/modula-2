# modula-2 oberon-2 XDS compilers

These XDS compilers were created by Excelsior in Russia: XDS is Copyright 1991-2019 Excelsior, LLC.

If you like the modula-2 and oberon-2 languages; these are useful tools.

I think that modula-2 and oberon-2 are better languages than many that came before them; and better than many that came after them.

They are simpler and more readable than many other popular computer languages; and the compilers support multithreading allowing more than one processor to be used; which seems essential now that every PC (and even phones) have several CPUs (2019.)

I plan to use them for some projects; and will track any changes here.

If you like compilers XDS is an interesting framework: http://oberon2005.oberoncore.ru/paper/vm1999.pdf


----
## Compatability

XDS compiles and run on the latest versions of Windows 10.

Works with the MSVC compiler; either VS2015, or VS2017 when set to use the windows 8.1 SDK.

# How to Compile these - see wiki 

https://github.com/alban-read/modula-2/wiki

## XDS Features

These are optimizing compilers

In XDS the strings are not unicode; which helps explain some very small exe sizes.

The native compiler generates 32bit code; (for 386; 486; pentium or pentium-pro); the ansi C compiler; compiles to C and uses a system C compiler to create the exe file.

Low memory usage: these are originally from the 1990s an era when powerful PC workstations had 16Mb of RAM. 

I suspect on 64bit Windows 10; you might be able to get as much as 4GB ram per 32bit process; if you update the exe.

e.g. to set the large address mode:- editbin /largeaddressaware my.exe 

You may also need update the heap limit parameters set to a max of 1128MB in the runtime objects.


XDS uses the intel floating point unit; not later SSE instructions etc.

NASM is used to compile the ASM for the runtimes.

I found that modern openwatcom C version 2 does not work; earlier versions might work.

The design of the XDS compilers separates the front end (oberon-2 and modula-2) from the backend code generator.

A common front end; supports either modula-2 or oberon-2 depending on the language mode and configuration settings.

Different Backends (included are x86 and ansi C) generate the compiled code.

There were many backends available commercially (x86, m68k, SPARC, PowerPC and VAX); in the past.

The XDS compilers and runtimes are written in a mix modula-2, oberon-2, C and x86 asm.

The versions of the source languages are modula-2 ISO10514 and oberon-2.

modula-2 is an imperative procedural modular structured (safe) language in the pascal family; oberon is similar, smaller; even more minimal with simple object orientation extensions.

The XDS compilers will compile a project that contains modules written in both languages.


----

Excelsior recently (in 2019) open sourced their famous modula-2 and oberon-2 XDS compilers under the apache license.

The XDS compilers have been available as binary packages free of charge for a number of years.


Thes artefacts here were picked up from:- 

https://github.com/excelsior-oss/xds

https://github.com/excelsior-oss/xds-ide

And earlier binary archives from the Excelsior site back in the day.

The components in here with source code are open sourced by Exelsior (see links above.)

The components without source code including the older IDE were provided free of charge by Excelsior.
 
The 2.6 version of XDS comes included as the SDK with the release of the modern Java Eclipse based IDE; see above.

The open source version of XDS compilers/debuggers/linkers/resource builder appear to be the 2.52 version.



-------

## History

If you are interested in the history of computing in Europe.

Excelsior went on from modula-2 and oberon-2 to create the award winning Jet Java AOT compiler.

Jet was a compiler from Java Bytecode to executable code; I used the standard edition a few times to package java apps.

The same team create the Excelsior operating system for an early (1980s) Russian mini-computer system designed to run modula-2; similar in concept to the Swiss Lilith; but 32bit and using Russian hardware technology; rather than American.

http://www.kronos.ru

 


