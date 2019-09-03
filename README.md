# modula-2 oberon-2 XDS compilers

These XDS compilers were created by Excelsior in Russia: XDS is Copyright 1991-2019 Excelsior, LLC.

If you like the modula-2 and oberon-2 languages; these are useful tools and available now as open source.

I think that modula-2 and oberon-2 are better languages than many that came before them; and better than many that came after them.

These languages are small, simple, consistent; strongly typed and readable.

Also these compilers support multithreading allowing more than one processor to be used; essential now that every PC (and even phones) have several CPUs (2019.)

I plan to use them for some projects; and will track any changes here.

If you like compilers XDS is an interesting framework: http://oberon2005.oberoncore.ru/paper/vm1999.pdf


----
## Compatability

XDS compiles and run on the latest versions of Windows 10.

Works with the MSVC compiler; either VS2015, or VS2017 when set to use the windows x86 10.0.17763.0 SDK.

# Installation 

Clone repo and Unpack the XDS ZIP.

Unzip the XDS ZIP to the XDS folder.

# Other Requirements

You need NASM (in S:\NASM) or change config files.

You need MSVC 2015 or 2017. 


# How to Compile these - see wiki 

https://github.com/alban-read/modula-2/wiki

## XDS Features

These are optimizing compilers

In XDS the strings are not unicode; which helps explain some very small exe sizes.

The native compiler generates 32bit code; (for 386; 486; pentium or pentium-pro); the ansi C compiler; compiles to C and uses the systems C compiler to create the exe file.

Low and controlled memory usage: these are originally from the 1990s an era when powerful PC workstations had 16Mb of RAM. 

I suspect on 64bit Windows 10; you might be able to get as much as 4GB ram per 32bit process; if you update the exe.

e.g. to set the large address mode:- editbin /largeaddressaware my.exe 


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


----

These artefacts here were picked up from:- 

* https://github.com/excelsior-oss/xds

* https://github.com/excelsior-oss/xds-ide

And earlier binary archives from the Excelsior site back in the day.

The components in here with source code are open sourced by Exelsior (see links above.)

The components without source code including the older IDE were provided free of charge by Excelsior.
 
A 2.6 binary version of XDS comes included as the SDK with the release of the modern Java Eclipse based IDE; see above.

The open source release of XDS compilers/debuggers/linkers/resource builder appear to be the 2.52 version.



-------

## History

If you are interested in the history of computing.

N. With (Switzerland) created PASCAL; then MODULA-2 and OBERON; on conjuction with hardware and Operating Systems.

Excelsior (Russia) went on from MODULA-2 and oberon-2 to create the award winning Jet Java AOT compiler.

Jet was a compiler from Java Bytecode to executable code; I used the standard edition a few times to package my java apps.

The same team created the Excelsior operating system for an early (1980s) Russian mini-computer system designed to run modula-2; 

similar in concept to the Swiss Lilith; but 32bit and using Russian hardware technology; rather than American.

http://www.kronos.ru



---

It is interesting to speculate how fast a kronos computer might run now; if the same design was implemented using modern processes.


