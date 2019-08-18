#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#define REG register

#define structassign(d,s) d=s

typedef enum
{
        Ident1, Ident2, Ident3, Ident4, Ident5
} Enumeration;
typedef int     OneToThirty;
typedef int     OneToFifty;
typedef char    CapitalLetter;
typedef char    String30[31];
typedef int     Array1Dim[51];
typedef int     Array2Dim[51][51];

struct Record
{
        struct Record  *PtrComp;
                        Enumeration Discr;
                        Enumeration EnumComp;
                        OneToFifty IntComp;
                        String30 StringComp;
};

typedef struct Record   RecordType;
typedef struct Record  *RecordPtr;
typedef int     boolean;

#define NULL 0
#define TRUE 1
#define FALSE 0
#ifndef REG
#define REG
#endif

void Proc8 (Array1Dim a0, Array2Dim a1, OneToFifty o0, OneToFifty o1);
void Proc7 (OneToFifty o0, OneToFifty o1, OneToFifty *o2);
void Proc6 (Enumeration e0, Enumeration *e1 );
void Proc5 (void);
void Proc4 (void);
void Proc3 (RecordPtr *r);
void Proc2 (OneToFifty *o0);
void Proc1 (RecordPtr r);
void Proc0 (void);

Enumeration Func1 ( CapitalLetter l0, CapitalLetter l1 );
boolean Func2 ( String30 s0, String30 s1 );

main ()
{
        Proc0 ();
}

int     IntGlob;
boolean BoolGlob;
char    Char1Glob;
char    Char2Glob;
Array1Dim Array1Glob;
Array2Dim Array2Glob;
RecordPtr PtrGlob;
RecordPtr PtrGlobNext;

void Proc0 ()
{
        OneToFifty IntLoc1;
        REG OneToFifty IntLoc2;
        OneToFifty IntLoc3;
        REG char        CharLoc;
        REG char        CharIndex;
            Enumeration EnumLoc;
        String30 String1Loc;
        String30 String2Loc;

#define LOOPS 400000000
        long    starttime;
        long    benchtime;
        long    nulltime;
        long    i;

        printf ("Please, wait about 60 seconds\n");

        starttime = time (0L);
        for (i = 0; i < LOOPS; ++i);
        nulltime = time (0L) - starttime;

        PtrGlobNext = (RecordPtr) malloc (sizeof (RecordType));
        PtrGlob = (RecordPtr) malloc (sizeof (RecordType));
        PtrGlob -> PtrComp = PtrGlobNext;
        PtrGlob -> Discr = Ident1;
        PtrGlob -> EnumComp = Ident3;
        PtrGlob -> IntComp = 40;
        strcpy (PtrGlob -> StringComp, "DHRYSTONE PROGRAM, SOME STRING");
	strcpy (String1Loc, "DHRYSTONE PROGRAM, 1'ST STRING");

        starttime = time (0L);
        for (i = 0; i < LOOPS; ++i)
        {
                Proc5 ();
                Proc4 ();
                IntLoc1 = 2;
                IntLoc2 = 3;
                strcpy (String2Loc, "DHRYSTONE PROGRAM, 2'ND STRING");
                EnumLoc = Ident2;
                BoolGlob =! Func2 (String1Loc, String2Loc);
                while (IntLoc1 < IntLoc2)
                {
                        IntLoc3 = 5 * IntLoc1 - IntLoc2;
                        Proc7 (IntLoc1, IntLoc2, &IntLoc3);
                        ++IntLoc1;
                }
                Proc8 (Array1Glob, Array2Glob, IntLoc1, IntLoc3);
                Proc1 (PtrGlob);
                for (CharIndex = 'A'; CharIndex <= Char2Glob; ++CharIndex)
                        if (EnumLoc == Func1 (CharIndex, 'C'))
                                Proc6 (Ident1, &EnumLoc);
                IntLoc3 = IntLoc2 * IntLoc1;
                IntLoc2 = IntLoc3 / IntLoc1;
                IntLoc2 = 7 * (IntLoc3 - IntLoc2) - IntLoc1;
                Proc2 (&IntLoc1);
        }
        benchtime = time (0L) - starttime - nulltime;
        printf ("Dhrystone time for %ld passes = %ld\n", (long) LOOPS, benchtime);
        printf ("This machine benchmarks at %ld dhrystones/second\n",
                        ((long) LOOPS) / benchtime);
}

void Proc1 (PtrParIn)
REG RecordPtr PtrParIn;
{
#define NextRecord (*(PtrParIn->PtrComp))
        structassign (NextRecord, *PtrGlob);
        PtrParIn -> IntComp = 5;
        NextRecord.IntComp = PtrParIn -> IntComp;
        NextRecord.PtrComp = PtrParIn -> PtrComp;
        Proc3 (&NextRecord.PtrComp);
        if (NextRecord.Discr == Ident1)
        {
                NextRecord.IntComp = 6;
                Proc6 (PtrParIn -> EnumComp, &NextRecord.EnumComp);
                NextRecord.PtrComp = PtrGlob -> PtrComp;
                Proc7 (NextRecord.IntComp, 10, &NextRecord.IntComp);
        }
        else
                structassign (*PtrParIn, NextRecord);
#undef NextRecord
}

void Proc2 (IntParIO)
OneToFifty * IntParIO;
{
        REG OneToFifty IntLoc;
        REG Enumeration EnumLoc;

        IntLoc = *IntParIO + 10;
        for (;;)
        {
                if (Char1Glob == 'A')
                {
                        --IntLoc;
                        *IntParIO = IntLoc - IntGlob;
                        EnumLoc = Ident1;
                }
                if (EnumLoc == Ident1)
                        break;
        }
}

void Proc3 (PtrParOut)
RecordPtr * PtrParOut;
{
        if (PtrGlob != NULL)
                *PtrParOut = PtrGlob -> PtrComp;
        else
                IntGlob = 100;
        Proc7 (10, IntGlob, &PtrGlob -> IntComp);
}

void Proc4 ()
{
        REG boolean BoolLoc;

        BoolLoc = Char1Glob == 'A';
        BoolLoc |= BoolGlob;
        Char2Glob = 'B';
}

void Proc5 ()
{
        Char1Glob = 'A';
        BoolGlob = FALSE;
}

boolean Func3 (Enumeration e0);

void Proc6 (EnumParIn, EnumParOut)
REG Enumeration EnumParIn;
REG Enumeration * EnumParOut;
{
        *EnumParOut = EnumParIn;
        if (!Func3 (EnumParIn))
                *EnumParOut = Ident4;
        switch (EnumParIn)
        {
                case Ident1:
                        *EnumParOut = Ident1;
                        break;
                case Ident2:
                        if (IntGlob > 100)
                                *EnumParOut = Ident1;
                        else
                                *EnumParOut = Ident4;
                        break;
                case Ident3:
                        *EnumParOut = Ident2;
                        break;
                case Ident4:
                        break;
                case Ident5:
                        *EnumParOut = Ident3;
        }
}

void Proc7 (IntParI1, IntParI2, IntParOut)
OneToFifty IntParI1;
OneToFifty IntParI2;
OneToFifty *IntParOut;
{
        REG OneToFifty IntLoc;

        IntLoc = IntParI1 + 2;
        *IntParOut = IntParI2 + IntLoc;
}

void Proc8 (Array1Par, Array2Par, IntParI1, IntParI2)
Array1Dim Array1Par;
Array2Dim Array2Par;
OneToFifty IntParI1;
OneToFifty IntParI2;
{
        REG OneToFifty IntLoc;
        REG OneToFifty IntIndex;

        IntLoc = IntParI1 + 5;
        Array1Par[IntLoc] = IntParI2;
        Array1Par[IntLoc + 1] = Array1Par[IntLoc];
        Array1Par[IntLoc + 30] = IntLoc;
        for (IntIndex = IntLoc; IntIndex <= (IntLoc + 1); ++IntIndex)
                ++Array2Par[IntLoc][IntLoc - 1];
        Array2Par[IntLoc + 20][IntLoc] = Array1Par[IntLoc];
        IntGlob = 5;
}

Enumeration Func1 (CharPar1, CharPar2)
CapitalLetter CharPar1;
CapitalLetter CharPar2;
{
        REG CapitalLetter CharLoc1;
        REG CapitalLetter CharLoc2;

        CharLoc1 = CharPar1;
        CharLoc2 = CharLoc1;
        if (CharLoc2 != CharPar2)
                return (Ident1);
        else
                return (Ident2);
}

boolean Func2 (StrParI1, StrParI2)
String30 StrParI1;
String30 StrParI2;
{
        REG OneToThirty IntLoc;
        REG CapitalLetter CharLoc;

        IntLoc = 1;
        while (IntLoc <= 1)
                if (Func1 (StrParI1[IntLoc], StrParI2[IntLoc + 1]) == Ident1)
                {
                        CharLoc = 'A';
                        ++IntLoc;
                }
        if (CharLoc >= 'W' && CharLoc <= 'Z')
                IntLoc = 7;
        if (CharLoc == 'X')
                return (TRUE);
        else
        {
                if (strcmp (StrParI1, StrParI2) > 0)
                {
                        IntLoc += 7;
                        return (TRUE);
                }
                else
                        return (FALSE);
        }
}

boolean Func3 (EnumParIn)
REG Enumeration EnumParIn;
{
        REG Enumeration EnumLoc;

        EnumLoc = EnumParIn;
        if (EnumLoc == Ident3)
                return (TRUE);
        return (FALSE);
}

