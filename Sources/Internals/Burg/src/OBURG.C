/****************************************************************/
/*  <oburg.c> 1 ������ 94   ��᫥���� ���������:  3 䥢ࠫ� 94 */
/*           Bottom-Up Rewriting Back-End Generator             */
/*    �������� BurBeG (����䨪��� ��⥬� iburg) �ந������   */
/*  ᡮ�� ᥫ���� ��� �롮� ��᫥����⥫쭮�� ������       */
/*  ��⨬��쭮� �⮨���� ��� �������� ���⪮� �ணࠬ�� �     */
/*  ��⠢� ������� ���� ��� �ந����쭮� 楫���� ��設�     */
/*  ��⮤�� ���室�饣� ।�����饣� ������� ��ॢ�           */
/*  ����७���� �।�⠢����� �������� ���⪮� 蠡������       */
/*  �ࠢ�� � �������᪨� �ࠢ������ �⮨���� ��� ���������   */
/*  ��ਠ�⮢ (�६� ࠡ��� �����⬠ ������� �� �⭮襭�� �    */
/*  ࠧ���� ����뢠����� ��ॢ�).                               */
/*    ��室�� ��⥬� ���� ⥪�� �� �몥 ���஭-2 ��� ��.  */
/*    �室�� ���� ⥪�� �� �몥 BURG+, ����뢠�騩 ����   */
/*  ।�������� �ࠬ��⨪� ������� ��ॢ쥢, ��⠢������ ��  */
/*  �ନ������ ᨬ����� �஬����筮�� �।�⠢����� �������� */
/*  ���⪮� ��室��� �ணࠬ��. � �⫨稨 �� ��⥬� iburg     */
/*  �������� ����祭�� �������⥫��� �������᪨� �᫮���      */
/*  �ਬ������ �ࠢ�� � �ଥ ��ࠦ���� ��� ���祭�ﬨ ��ਡ�⮢*/
/*  㧫�� ����뢠����� ��ॢ� (��� � ��⥬� BEG), � �室��    */
/*  ��ࠧ�� ����塞�� �������᪨� �⮨���⥩ �ࠢ��,         */
/*  �������� �� ⥪��� ���祭�� ��ਡ�⮢ ��室���� ��ॢ�,   */
/*  �� �������筮 ��।������� � ������ ���᫥��� ��⨬��쭮�� */
/*  �������. ��ࠦ���� �᫮��� � �������᪨� �⮨���⥩       */
/*  ���������� �� ���譥� �����㬥�⠫쭮� �몥 ॠ����樨     */
/*  楫����� ��������� (���஭�-2 ��� ��). �������� ����祭�� */
/*  � ⥪�� ���ᠭ�� �ࠬ��⨪� �ࠣ���⮢ ᥬ����᪮�        */
/*  ��ࠡ�⪨ �ࠢ�� �� ���譥� �몥 ॠ����樨, ���������   */
/*  ⥪�騬� ���祭�ﬨ ��ਡ�⮢ ����뢠����� ��ॢ�.          */
/*                                                              */
/*  (�) �.���㤨�, xTech Ltd., 1994    ����ᨡ���, �.35-11-53  */
/****************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "oburg.h"              /* ����⠭��, ᮡ�⢥��� ⨯�  */
                                /* � ᯥ�䨪�樨 ��� ��楤�� */
                                /*      ��樨 ��������:       */
char *prefix = "NT";          /* ��騩 ��䨪� ��室��� ����  */
int  Iflag = 0,                 /* 1=ᡮઠ �⫠��筮� ���ᨨ   */
     Tflag = 0,                 /* 1=ᡮઠ �������饩 ���ᨨ */
     Cflag = 0;                 /* 1=ᡮઠ ���ᨨ �� �몥 ��  */

char * computer = "386";

static FILE *infp = NULL;       /* ���� �室���� ⥪��         */
static FILE *outfp = NULL;      /* ���� ��室���� ⥪��        */
static FILE *outfp1 = NULL;     /* ���� ��室���� ⥪��        */
static FILE *incp = NULL;       /* ���� ��.⥪�� (include)     */

int    lexineno;                /* ����� �室��� ��ப�         */
static outline=0;               /* ����� ��室��� ��ப�        */

char inbuf[BFSIZE];             /* ���� �室���� ⥪��        */
char *bp;                       /* �����⥫� �� ��砫� ���ᥬ�  */
int errcnt=0;                   /* ��᫮ ������� �訡��      */

char bf1 [80], bf2 [80];

/****************************************************************/
/* ������ ��⥬�: ������ ��������� ��ப�, ����⨥ 䠩���    */
/*                  �맮� 䠧 �������஢����                   */
/****************************************************************/
void main(int argc, char *argv[])
{
int i, j;                       /* �ᯮ����⥫�� ���稪�     */
char b[BFSIZE];                 /* ���� ��� ����䨪�樨 ����   */
char bb[BFSIZE];                /* ���� ��� ����䨪�樨 ����   */
char *a;                        /* 㪠�. �� ��.��ப� ��ࠬ��� */
int c;                          /* ���ୠ� ���� ��.⥪��    */
/****************************************************************/
/* �����祭�� ��権 � ���� 䠩��� �� ��������� ��ப� MS-DOS    */
/****************************************************************/
  if(argc<2) goto empty;
  for (i = 1; i < argc; i++)
    if (strcmp(argv[i], "-I") == 0)      Iflag = 1;
    else if (strcmp(argv[i], "-T") == 0) Tflag = 1;
    else if (strcmp(argv[i], "-C") == 0) Cflag = 1;
    else if (strncmp(argv[i], "-p", 2) == 0 && argv[i][2])
             prefix = &argv[i][2];
    else if (strncmp(argv[i], "-p", 2) == 0 && i + 1 < argc)
             prefix = argv[++i];
    else if (strncmp(argv[i], "-m", 2) == 0 && argv[i][2])
         computer = &argv[i][2];
    else if (strncmp(argv[i], "-m", 2) == 0 && i + 1 < argc)
         computer = argv[++i];
    else if (*argv[i] == '-' && argv[i][1])
            {
    empty:    error("�맮�: %s [-T | -I | -� | -p prefix | -m machine]... "
                    "input[.b] [output[.o|.c]]\n",argv[0]);
              exit(1);
            }
    else if (infp == NULL)      /* 䠩� �室���� ⥪��         */
         {
           if (strcmp(argv[i], "-") == 0) infp = stdin;
           else
           {
             for(a=argv[i],j=0;*a!=0 && *a!='.';++a) b[j++]=*a;
             if(*a==0) b[j++]='.',b[j++]='b',b[j]=0;
             else { for(;*a!=0;++a) b[j++]=*a; b[j]=0; }
             if ((infp = fopen(b, "r")) == NULL)
             {
                error("%s: �� ���뢠���� ��� �⥭�� 䠩� `%s'\n",
                        argv[0],b);
                exit(1);
             }
           }
         }
    else if (outfp == NULL)     /* 䠩� ��室���� ⥪��        */
         {
           if (strcmp(argv[i], "-") == 0)  outfp = stdout;
           else
           {
             for(a=argv[i],j=0; *a!=0 && *a!='.';++a) b[j++]=*a;
             if(*a==0)
             {
               b[j++]='_'; b[j++]='d'; b[j++]='.';
               b[j++]=Cflag?'c':'o'; b[j]=0;
             }
             else
             {
               b[j++]='_'; b[j++]='d';
               for(;*a!=0;++a) b[j++]=*a;
               b[j]=0;
             }
    ow:      if ((outfp = fopen("Burg.o", "w")) == NULL)
             {
               error("%s: �� ���뢠���� ��� ����� 䠩� `%s'\n",
                       argv[0], b);
               exit(1);
             }
           }
         }
    if (infp == NULL)  exit(1);
    if (outfp == NULL)  /* �� ��� ��室���� 䠩�� ���饭�    */
      if(j>2)
      {
//        b[j-2]='.';  
//        b[j-1]=Cflag?'c':'o';
          b[j]=0; goto ow;
      }
      else outfp=stdout;

    fputs ("<*+WOFF*>\n", outfp);
    print ("-- source grammar = %s\n", b);
    print ("MODULE Burg;\n");
    print ("IMPORT BurgNT;\n");

/****************************************************************/
    lexineno=1;
    terms=NULL; nts=NULL; rules=NULL;
    bp=inbuf;
    *bp=0; get(); --bp; /* �ய�� ⥪�� �ॠ���� � ���.䠩�  */

/****************************************************************/
    parse();          /* ������ �室���� ���ᠭ�� �� �몥 BURG,*/
                      /* ������� ����७���� �।�⠢����� �  */
                      /* ᡮઠ ��⥩ ��楤��� actions        */
/****************************************************************/
    printf("�஠������஢��� ��ப: %d. ������� �訡��: %d\n",
            lexineno, errcnt);
    if(errcnt)
    {
el:    printf("��室��� 䠩� �� ����� ���� ���४⭮ �ᯮ�짮���!\n");
       exit(1);
    }
    if(Cflag) print("  }\n}\n\n");      /* 墮�� ��� actions    */
    else print("  ELSE\n  END;\nEND %Pactions;\n\n");
/****************************************************************/
    emitimodule();        /* ���ઠ �᭮����� ⥪�� ᥫ����    */
//    emit();
//    b[j-2]=0;             
    emitclosure (nts, b, j-2, bf1);
//    b[j-2]=0;
    emitstate(terms, start, ntnumber,b, bf2); 
    outfp1=outfp;
//e386d.o
//    b[j-2]='d'; b[j-1]='.'; b[j]=Cflag?'c':'o';
    if ((outfp = fopen("BurgNT.o", "w")) == NULL)
    {
      error("%s: �� ���뢠���� ��� ����� 䠩� `%s'\n",
      argv[0],b); exit(1);
    }
//    b[j-1]=0;             /*ᡮઠ ��楤�� closure � ��.���㫥*/
//    strcpy (bf1, "ir, R := r");
//    strcat (bf1, computer);
    emitdmodule(b,j-2);
//    emitdefs(nts, ntnumber);    /* ᡮઠ ��।������ ����.   */
//    emitstruct(nts, ntnumber);  /* ᡮઠ ���.�������� state   */

//    emitclosure (nts, b, j-2, bf1);
    fclose(outfp);
//e386n.o
//    b[j-2]='n'; b[j-1]='.'; b[j]=Cflag?'c':'o';
    if ((outfp = fopen("BurgTables.o", "w")) == NULL)
    {
      error("%s: �� ���뢠���� ��� ����� 䠩� `%s'\n",
      argv[0],b); exit(1);
    }
//    b[j-1]=0;             /*ᡮઠ ��楤�� closure � ��.���㫥*/
//    strcpy (bf1, "ir, R := r");
//    strcat (bf1, computer);
    emitnmodule(b,j-2);
    fclose(outfp);

//    b[j-3]='s'; b[j-2]='.'; b[j-1]=Cflag?'c':'o'; b[j]=0;
//    if ((outfp = fopen(b, "w")) == NULL)
//    {
//      error("%s: �� ���뢠���� ��� ����� 䠩� `%s'\n",
//      argv[0],b); exit(1);
//    }
//    if (start)  /* ᡮઠ ��楤��� state � �⤥�쭮� ���㫥    */
//      { b[j-2]=0;
//    strcpy (bf2, "ir, StdIO := opIO, R := r");
//    strcat (bf2, computer);
//    emitstate(terms, start, ntnumber,b, bf2); }
//
//    fclose(outfp);
//
    outfp=outfp1;
/****************************************************************/
    if (!feof(infp))  /* �뢮� ⥪�� ����-�ਯ�㬠 � ���.䠩� */
      while (fgets(inbuf, sizeof inbuf, infp))
      {
        fputs(inbuf, outfp); ++outline;
      }
    print("END Burg.\n");

    printf("���࠭� ��ப: %d. ������� �訡��: %d\n",
            outline, errcnt);
    if(errcnt) goto el;
    else printf("�ᯥ譠� ᡮઠ\n");
}
/****************************************************************/
/* �⥭�� ��।��� ����� � �ய�᪮� ⥪�� %{...}% � ���.䠩�*/
/****************************************************************/
int get(void)
{
  if (*bp == 0)                         /* ��ப� ���௠��     */
  {
rl: if (fgets(inbuf, sizeof inbuf, infp) == NULL)
    {
ri:   if(incp==NULL) return EOF;
      infp=incp; incp=NULL; goto rl;
    }
    bp = inbuf;
    lexineno++;
    while (inbuf[0] == '%' && inbuf[1] == '{' && inbuf[2] == '\n')
    {
      for (;;)
      {
        if (fgets(inbuf, sizeof inbuf, infp) == NULL)
        {
          warn("���ࢠ��� ⥪�� %{...%}\n");
          goto ri;
        }
        lexineno++;
        if (strcmp(inbuf, "%}\n") == 0) break;
        fputs(inbuf, outfp); ++outline;
      }
      if (fgets(inbuf, sizeof inbuf, infp) == NULL) goto ri;
      lexineno++;
    }
  }
  return *bp++;
}
/****************************************************************/
/*  ����祭�� ⥪�⮢��� 䠩�� � �।���� �ॠ����             */
/****************************************************************/
void include ()
{
char *bf;
  if(incp)
  {
     error("�������� %include �������⨬�\n");
     return;
  }
  incp=infp;
  while(*bp==' '|| *bp=='\t') ++bp; bf=bp;
  while(*bp!=' '&& *bp!='\t' && *bp!='\n' && *bp!=0 && *bp!='/')
    ++bp; *bp=0;
  if ((infp = fopen(bf, "r")) == NULL)
  {
     error("�� ���뢠���� ��� �⥭�� include-䠩� `%s'\n",bf);
     exit(1);
  }
  *bp=0;
}
/****************************************************************/
/*  ����饭�� �������� �� �訡��                              */
/****************************************************************/
void error(char *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  if (lexineno > 0)
    fprintf(stderr, "��ப� %d: ", lexineno);
  vfprintf(stderr, fmt, ap);
  if (fmt[strlen(fmt)-1] != '\n') fprintf(stderr, "\n");
  errcnt++;
}
/****************************************************************/
/*  �।�०����� �������� �� �訡��                         */
/****************************************************************/
void warn(char *fmt, ...)
{
        va_list ap;

        va_start(ap, fmt);
        if (lexineno > 0) fprintf(stderr, "��ப� %d: ", lexineno);
        fprintf(stderr, "�।�०�����: ");
        vfprintf(stderr, fmt, ap);
}
/****************************************************************/
/* alloc - ����祭�� nbytes ����� � ����⮬ � ��砥 ��㤠�   */
/****************************************************************/
void *alloc(int nbytes)
{
    void *p = malloc(nbytes);
        if (p == NULL)
        {
                error("�� 墠⠥� �����!\n");
                exit(1);
        }
        return p;
}
/****************************************************************/
/* stringf - �ଠ�� �뢮� � ����� ��ப� ����室���� �����   */
/****************************************************************/
char *stringf(char *fmt, ...)
{
va_list ap;
char *s,
     buf[512];          /* ���� ��� �ଠ⭮�� �뢮��          */
  va_start(ap, fmt);
  vsprintf(buf, fmt, ap);
  va_end(ap);
  return strcpy((char *)alloc(strlen(buf) + 1), buf);
}
/****************************************************************/
/* print - ᮡ�⢥��� �ଠ�஢���� �뢮� ��������         */
/****************************************************************/
void print(char *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  for ( ; *fmt; fmt++)
  {
    if (*fmt == '\n') ++outline;   /*  ������ �᫠ ���. ��ப */
    if (*fmt == '%')
      switch (*++fmt)
      {
        case 'd': fprintf(outfp, "%d", va_arg(ap, int)); break;
        case 's': fputs(va_arg(ap, char *), outfp); break;
        case 'c': fprintf(outfp, "%c", va_arg(ap, int)); break;
        case 'P': fprintf(outfp, "%s", prefix);
                  break;
        case 'T': {
                    Tree t = va_arg(ap, Tree);
                    print("%S", t->op);
                    if (t->left && t->right)
                      print("(%T,%T)", t->left, t->right);
                    else if (t->left)
                           print("(%T)", t->left);
                    break;
                  }
        case 'R': {
                    Rule r = va_arg(ap, Rule);
                    print("%S: %T", r->lhs, r->pattern);
                    break;
                  }
        case 'S': fputs(va_arg(ap, Term)->name, outfp); break;
        case '1': case '2': case '3': case '4': case '5':
                  {
                    int n = *fmt - '0';
                    while (n-- > 0) putc('\t', outfp);
                    break;
                  }
        default:  putc(*fmt, outfp); break;
      }
    else putc(*fmt, outfp);
  }
  va_end(ap);
}
