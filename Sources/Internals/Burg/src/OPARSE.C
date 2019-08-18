/****************************************************************/
/* <oparse.c> 22-������-94 ��᫥���� ���������  20 䥢ࠫ� 94  */
/*   ��������� ��室���� ���ᠭ�� �ࠬ��⨪� �� �몥 BURG+ �  */
/*   ������� �� ����७���� �।�⠢����� � ��⥬� BurBeG.   */
/*   � ����� ������� ᮡ�ࠥ� ⥪�� ��楤��� actions.       */
/****************************************************************/
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <assert.h>
#include "oburg.h"      /* ��।������ ⨯�� � ����⠭�         */
#include "burgpt.h"     /* �᭮���� ⠡��� ������� BURG-⥪�� */
#include "treept.h"     /* ⠡�.������� ���ᠭ�� ��ॢ� 蠡���� */

static int ppercent=0;  /* �ਧ��� ⥪�� ��᫥ %%              */

static union
{
  int n;                /* ���祭�� 楫��� �᫠                */
  char *string;         /* ��ப� ����� �����䨪���          */
}
lexval;                 /* ����饭��� �����᪮� ���祭��      */

struct entry            /* ���ਯ�� ����� ��-⠡����         */
{
   union
   {
     char *name;                /* ��ப� �室���� �����        */
     struct term t;             /* ���ਯ�� �ନ����         */
     struct nonterm nt;         /* ���ਯ�� ���ନ����       */
   } sym;
   struct entry *link;          /* ᫥���騩 ����� ᯨ᪠     */
                                /* ����. ������������ ����    */
};                              /* ��-⠡��� ��� ���ᨢ       */
                                /* ���ᮢ ᯨ᪮� ���ਯ�஢ */
static struct entry *table[HASHSIZE];  /* ⥫� ��-⠡���� ���� */
extern int lexineno;

int parse()
/****************************************************************/
/*         �������� ��������� ��室���� ⥪��                 */
/*       �����頥� �᫮ �����㦥���� � ⥪�� �訡��          */
/****************************************************************/
{
char *plex;             /* ������ ⥪�饩 ���ᥬ� � ����     */
int sts;                /* ⥪�饥 ���ﭨ� ࠧ���            */
int stl;                /* ������ �⥪� ࠧ���                 */
char *name;             /* ��ப� ����� �����䨪���          */
Tree  p;                /* 蠡��� �ࠢ���                       */
char *c;                /* �ਯ��. �ࠢ��� ⥪�� ���.�᫮���    */
char *d;                /* �ਯ��. �ࠢ��� ⥪�� ���.�⮨����  */
int x;                  /* ���譨� ����� �ࠢ���                */
int cc;                 /* ����⠭⭠� �⮨����� �ࠢ���        */
int *auxc;              /* ����� �������⥫��� �⮨���⥩     */
register i,l;           /* ���稪 ����                        */
int ximpl;              /* ��� ���稪 �ࠢ��               */
int naux;               /* ���稪 �������⥫��� �⮨���⥩    */
int oper,type;          /* ᥬ����᪮� ����⢨� � ��.���ᥬ�  */
  sts=0; stl=0; plex=inbuf;
  costvl=1; ximpl=0;
  do
  {
    type=lex();
rl: oper=qikpas(type,&sts,&stl,burgpt);
/*
printf("*** type=%d op=%d %s\n",type,oper,plex);
*/
    switch(oper)
    {
      case 1 : *bp=0; break;            /* ����� ��ப�         */
      case 2 : break;                   /* �ய�� ���ᥬ�      */
      case 3:  return errcnt;           /* ����� �室���� ⥪��*/
      case 4 : error("C��⠪��᪠� �訡��:\n %s",plex);
               *bp=0; break;
      case 5 : name=lexval.string;      /* ��� �ନ����        */
               break;
      case 6 : term(name, lexval.n);    /* ���譨� �����        */
               break;                   /* �ନ����            */
      case 7 : emitdefsi(nts, ntnumber);    /* ᡮઠ ��।������ ����.   */
               emitactions();      /* ᡮઠ ��������� ��楤��� actions   */
               start=                   /* � �������        */
                 nonterm(lexval.string);/* ���⮢� ���ନ��� */
               break;
      case 8 : name=lexval.string;      /* ��� १������饣�  */
               if(start==NULL)          /* ���ନ���� �ࠢ���  */
                  start=nonterm(name);  /* ���⮢� ���ନ���,*/
               c=d=NULL; cc=0;          /*   ������� ���    */
               if(costvl>1)             /* ᯨ᮪ ���.�⮨���⥩*/
               { auxc = (int *)alloc((sizeof(int)*(costvl-1)));
                 for(i=0; i<costvl-1; ++i) auxc[i]=0;
               }
               else auxc =NULL;
               break;
      case 9 : p=treeparse(0);          /* ��ॢ� 蠡����:�����*/
               plex=bp; continue;       /* ४��.������������!*/
      case 10: x=lexval.n; break;       /* ����.����� �ࠢ���  */
      case 11: rule(name,p,x,0,c,d,auxc); /*�ࠢ��� �⮨���� 0 */
               break;
      case 12: cc=lexval.n; break;      /* ����⠭⭠� �⮨�����*/
      case 13: c=xtext(); break;        /* ⥪�� �᫮��� �ࠢ���*/
      case 14: emitactrule(x,p); break; /* 1-e ᥬ.�����.�ࠢ���*/
      case 15: d=xtext(); break;        /* �������᪠� �⮨�-��*/
      case 16: rule(name,p,x,cc,c,d,auxc); /* �ࠢ��� ࠧ��࠭� */
               break;                   /* ���������            */
      case 17: if(lexval.n>=STSIZE)     /* 楫� ����� �����  */
               {
                 error("�������⨬� ����� ����� %s\n",plex);
                 *bp=0; break;
               }
               x=lexval.n; goto mbody;
      case 18: bp=plex; x=0;            /* 0 ����� (��� �����)*/
      mbody:   {                        /* ⥫� �����         */
               char buf[1024];
                 l=0;
                 while(1)
                 {
                   while(*bp!='\n' && *bp!='/' && *bp!='\\' && l<1023)
                     buf[l++]= *(bp++);
                   if(*bp=='\\')        /* ���������� ����� */
                   {
                     buf[l++]='\n'; *bp=0; get(); continue;
                   }
                   else break;
                 };
                 d=pronmac[x]=alloc(l+1);
                 for(i=0;i<l;++i) d[i]=buf[i]; d[i]=0;
                 *bp=0; break;
               }
      case 19: cc=0; emitactrule(x,p); /* ⥪�� ��ࠡ.�ࠢ���   */
               break;                  /* �� ���饭��� �⮨�.  */
      case 20: include(); break;       /* ����祭�� 䠩��       */
      case 21: costvl=lexval.n;        /* ����� ����.�⮨����  */
               if(costvl>1)
               {
                 auxtype=(int *)alloc((sizeof(int)*(costvl-1)));
               }
               else auxtype=NULL;
               break;
      case 22: x= ++ximpl; goto rl;    /* ��� ����� �ࠢ��� */
                                       /*������ � ��� �� ������!*/
      case 23: naux=0; break;          /* ��砫� ᯨ᪠ �⮨���.*/
      case 24: if(++naux>=costvl)      /* ᫥��� ���.�⮨����� */
               { warn("����� �⮨����� �ࠢ���:\n %s",bp); }
               break;
      case 25: if(costvl>1 && naux<costvl)    /* ���.�⮨�����  */
                 auxc[naux-1]=lexval.n;
               break;
      case 26: rule(name,p,++ximpl,cc,c,d,auxc); /*���� �ࠢ���*/
               break;
      case 27: auxtype[lexval.n-1]=1;  /* ᯥ�.�㭪�� �⮨����*/
               break;
      case 28: auxtype[lexval.n-1]=2;  /* ����� �㭪�� �⮨�. */
               break;
      case 29: emitactrule(-x,p); break; /*2-e ᥬ.�����.�ࠢ���*/
      case 30: cc=0; emitactrule(-x,p); /* ⥪�� 2-�� ����⢨�  */
               break;                   /* �� ���饭��� �⮨�. */
      case 31: addnonterm(lexval.string);      /* ��� ���ନ����        */
               break;
    }
    plex=bp;            /* ���室 � �롮થ ᫥���饩 ���ᥬ�  */
  }
  while(stl>=0);
}
/****************************************************************/
/*          �����᪨� ��������� �������� OBURG:            */
/*  �������� ��� ࠧ����⥫� ' ' \f \t                        */
/*  �������� �������ਨ /... � ���� ��ப�                  */
/*  �뢮��� � ��室��� ⥪�� �ॠ���� %{...}%  (��ᢥ��� � get)*/
/*  �����頥� ��� 楫�� �᫮ ��� ⨯� ��।��� ���ᥬ�:      */
/*  - ��������� ���ᥬ�: ( ) { } < > , ; = :                 */
/*  - START ��� TERM  ��। ���ᠭ��� �ࠬ��⨪� (��᫥ %...)   */
/*  - MACRO ��। ���ᠭ��� �ࠬ��⨪� (��᫥ %define)          */
/*  - �OST  ��। ���ᠭ��� �ࠬ��⨪� (��᫥ %cost)            */
/*  - INCLUDE ��। ���ᠭ��� �ࠬ��⨪� (��᫥ %include)       */
/*  - PPERCENT - ��砫� ���ᠭ�� �ࠬ��⨪� (��᫥ ��ࢮ�� %%)  */
/*  - INT ��� 楫��� �᫠  (���祭�� � lexval.n)               */
/*  - ID ��� �����䨪��� (⥫� ��ப� � lexval.string)       */
/*  - 1 - ��� ���� ��ப�  (\n)                                */
/*  - 0 - ���ᠭ�� ���௠��     (��᫥ ��ண� %% ��� EOF)     */
/*  �� ��稥 ����� ������� �訡��묨 � �ய�᪠���� �     */
/*  �뢮��� ᮮ�饭�� �� �訡��                                 */
/****************************************************************/
static int lex(void)
{
int c;
  while ((c = get()) != EOF)    /* ��।���  ���� ⥪��     */
  {
    switch (c)
    {
      case ' ': case '\f': case '\t':   continue;
      case '\n':case 0:   case '/':     return 1;
      case '(': case ')': case '{': case '}':
      case '<': case '>': case ',':
      case ';': case '=': case ':':     return c;
    }
    if (c == '%' && *bp == '%')
    {
      bp++; return ppercent++ ? 0 : PPERCENT;
    }
    else
      if (c == '%' && strncmp(bp, "define", 6) == 0
                   && isspace(bp[6]))
      { bp +=6; return MACRO; }
    else
      if (c == '%' && strncmp(bp, "include", 7) == 0
                   && isspace(bp[7]))
      { bp +=7;
        lexineno=1;
        return INCLUDE; }
    else
      if (c == '%' && strncmp(bp, "nonterm", 7) == 0
                   && isspace(bp[7]))
      { bp += 7; return NTERM; }
    else
      if (c == '%' && strncmp(bp, "term", 4) == 0
                   && isspace(bp[4]))
      { bp += 4; return TERM; }
    else
      if (c == '%' && strncmp(bp, "start", 5) == 0
                   && isspace(bp[5]))
      { bp += 5; return START; }
    else
      if (c == '%' && strncmp(bp, "cost", 4) == 0
                   && isspace(bp[4]))
      { bp += 4; return COST; }
    else
      if (c == '%' && strncmp(bp, "special", 7) == 0
                   && isspace(bp[7]))
      { bp += 7; return SPEC; }
    else
      if (c == '%' && strncmp(bp, "empty", 5) == 0
                   && isspace(bp[5]))
      { bp += 5; return EMPTY; }
    else
      if (isdigit(c))
      {
        int n = 0;
        do
        {
          n = 10*n + (c - '0');
          c = get();
        }
        while (isdigit(c));
        if (n > 32767)
          error("楫�� %d ����� 祬 32767\n", n);
        bp--;
        lexval.n = n;
        return INT;
      }
    else
      if (isalpha(c))
      {
        char *p = bp - 1;
        while (isalpha(c) || isdigit(c) || c == '_')
          c = get();
        bp--;
        lexval.string = (char *)alloc(bp - p + 1);
        strncpy(lexval.string, p, bp - p);
        lexval.string[bp - p] = 0;
        return ID;
      }
    else
      if (isprint(c))
         error("�����᪨ �������⨬�� ���� `%c'\n", c);
      else
         error("�����᪨ �������⨬� (�������) ᨬ��� `\0%o'\n",
               c);
  }
  return 0;
}
/****************************************************************/
/*  ��楤�� 蠣� ᨭ⠪��᪮�� ������� ⥪��               */
/*      �����頥� ��� ᥬ����᪮� ����樨                   */
/****************************************************************/
static int qikpas(swt,sts,stl,pat)
int swt;                        /* ��४���⥫� ࠧ���        */
int *sts;                       /* ���� �⥪� ���ﭨ� ࠧ���*/
int *stl;                       /* ������ �⥪� ࠧ���         */
int *pat;                       /* ⠡��� ࠧ���              */
{
register int j;                 /* ���稪 ���ﭨ� ���室�   */
register int i;                 /* �᫮ ���ﭨ� ���室�     */
register int l;                 /* ������ �⥪� ࠧ���         */
int *sp;                        /* 㪠��⥫� �� ⠡���� ࠧ��� */
int jump;                       /* ��� ����⢨� ���室�        */
/****************************************************************/
        l= *stl;
//        printf("swt=%d\tsts=%d\n", swt, sts[l]);
        do
        {
                sp=pat+sts[l]*4;
                while(1)
                {
                        switch(*(sp++))
                        {
                                case 0: sp ++;
                                        goto jmp;
                                case 1: if(swt== *(sp++)) goto jmp;
                                        break;
                                case 2: if(swt>= *(sp++))
                                          if(swt<=*(sp++))
                                            goto jmp;
                                          else break;
                                        sp++;break;
                        }
                        sp += 2;
                }
           jmp: jump= *(sp++);i= 1;//*(sp++);
                if(i>0)
                    for(j=0;j<i;++j)
                        sts[l++]= *(sp++);
                --l;
        }
        while(jump==0 && l>=0);
        *stl=l;
//        printf("\t\t\t\tnewsts=%d\tjump=%d\n", sts[l], jump);
        return(jump);
}

static char *xtext()
/****************************************************************/
/* �롮ઠ �� �室���� 䠩�� ���譥�� ⥪�� � �ଥ {...}      */
/* ��������� ��譨� �஡��� � ⠡��樨                         */
/* �����頥� ���� ᪮��஢������ � ������ �ࠣ����           */
/****************************************************************/
{
char buf[1024];                 /* �६���� ⥪�⮢� ����    */
register i,m;                   /* ���稪� ����               */
char *s;                        /* ���� �ࠣ���� �� ��.⥪�� */
char *t;                        /* ���� ����� �ࠣ����        */
int f;                          /* �ਧ��� ������塞��� ࠧ���. */
  f=m=0;
l:for(s=bp; *bp!='}' &&  *bp!='\n' && m<1023; ++bp)
  {
    if(*bp==' ' || *bp=='\t')
    {
      if(f==0) { f=1;  buf[m++]=' '; continue; }
      else continue;
    }
    buf[m++]=*bp; f=0;
  }
  if(m==1024)
  {
    error("���誮� ������ ���譨� ⥪��:\n %s", s);
    *bp=0; return NULL;
  }
  if(*bp=='\n')
  {
    buf[m++]=*bp; *bp=0;
    if(get()==EOF)
    {
      error("���� ���譥�� ⥪��:\n %s", s);
      *bp=0; exit(0);
    }
    f=0; goto l;
  }
  if(m>0) t= (char *)alloc(m+1); else t=NULL;
  for(i=0; i<m; ++i) t[i]=buf[i]; t[i]=0;
  ++bp; return t;
}

static Tree treeparse(int p)            /* ����� ��⪨-��ࠬ���*/
/****************************************************************/
/* ��������� ���ᠭ�� ��ॢ� � ��⠢� 蠡���� �ࠢ���         */
/* �����頥�: ���� ���ਯ�� ���� ��ॢ� � ��⠢� 蠡���� */
/*             NULL � ��砥 �訡��                             */
/****************************************************************/
{
char *plex;             /* ������ ⥪�饩 ���ᥬ� � ����     */
int sts;                /* ���ﭨ� ࠧ���                    */
int stl;                /* ������ �⥪� ࠧ���                 */
char *name;             /* ��ப� ����� �����䨪���          */
Tree l;                 /* ���� ���ਯ�� ������ �����ॢ�   */
Tree r;                 /* ���� ���ਯ�� �ࠢ��� �����ॢ�  */
/*
int type, oper;
*/
  sts=0; stl=0; plex=bp;
  do
  {
/*
type=lex();
oper=qikpas(type,&sts,&stl,treept);
printf("<TREEPARSE> type=%d op=%d %s\n",type,oper,plex);
switch(oper)
*/
    switch(qikpas(lex(),&sts,&stl,treept))
    {
      case 1: *bp=0; break;             /* ����� ��ப�         */
      case 2: break;                    /* �ய�� ���ᥬ�      */
      case 3: name=lexval.string;       /* 㧥� ��ॢ� 蠡����  */
              break;
      case 4: error("���⠪��᪠� �訡�� ���ᠭ�� 蠡����: %s",
              plex); break;
      case 5: l=treeparse(-1);          /* ����� �����ॢ�      */
                                        /* (४��ᨢ�� ���)  */
              plex=bp; continue;        /* ���ᥬ� ��⠭������! */
      case 6: --bp;                             /* �������      */
              return tree(name,NULL,NULL,p);    /* ����         */
      case 7: return tree(name,l,NULL,p);       /* ������. �� */
      case 8: r=treeparse(-1);          /* �ࠢ�� �����ॢ�     */
                                        /* (४��ᨢ�� ���)  */
              plex=bp; continue;        /* ���ᥬ� ��⠭������! */
      case 9: return tree(name,l,r,p);  /* ������ ��ॢ�        */
      case 10:--bp; return NULL;        /* ������� ��᫥ �訡�� */
      case 11:p=lexval.n; break;        /* ����� ��ࠬ���      */
    }
    plex=bp;            /* ���室 � �롮થ ᫥���饩 ���ᥬ�  */
  }
  while(stl>=0);
}
/****************************************************************/
/* hash - ���᫥��� ��-�㭪樨 ��� ⥪�⮢�� 楯�窨 str      */
/****************************************************************/
static unsigned hash(char *str)
{
   unsigned h = 0;
   while (*str) h = (h<<1) + *str++;
        return h;
}
/****************************************************************/
/* lookup - ���� ����� ��ꥪ� �室���� ⥪�� � ��-⠡���   */
/****************************************************************/
static void *lookup(char *name)
{
  struct entry *p;

  /* ������� ���� �� �ᥬ� ᯨ�� ���ਯ�஢, �易���� �   */
  /* ������ ��-����樥� ��᫥ ��ࢨ筮�� ��஢���� �����     */

  for (p=table[hash(name)%HASHSIZE]; p!=NULL; p = p->link)
    if (strcmp(name, p->sym.name) == 0)
      return &p->sym;     /* ��� �������, �����頥��� ����    */
  return NULL;            /* ���� �������� ����ᯥ��         */
}
/****************************************************************/
/* install - ����祭�� ������ ����� � ��-⠡����               */
/****************************************************************/
static void *install(char *name)
{
  struct entry *p = alloc(sizeof *p);  /* ᮧ����� ���ਯ��  */
  int i = hash(name)%HASHSIZE;  /* ������ ����� � ��-⠡���  */
  p->sym.name = name;           /* ��� ��ନ஢����� ��-�㭪��*/
  p->link = table[i]; /* ���᭥��� 㦥 �������饣� ᯨ᪠    */
                      /* ����, ��樤����� ������ ��-����樨   */
  table[i] = p;       /* ����. ��� ����� ������ �⮣� ᯨ᪠   */
  return &p->sym;     /* ���� ����� ᮧ������� ���ਯ��     */
}
/****************************************************************/
/* nonterm - ���� ���ନ���� �� ����� � ��-⠡���; ᮧ����� */
/* ������ ���ਯ�� �����, �᫨ �� ��������� � ����祭��    */
/* �⮣� ���ਯ�� � 墮�� ��饣� ᯨ᪠ ���ନ�����         */
/****************************************************************/
static Nonterm nonterm(char *id)/* �室��� ��� ���ନ����  */
{
Nonterm p;              /* ���� ���ਯ�� ���ନ����*/
  p = lookup(id);           /* ���� ���ਯ�� ���ନ����*/
  if ((p!=NULL) && p->kind==NONTERM) /*���ନ��� 㦥 �������*/
  {
    return p;                   /* �����頥� ���� ���ਯ�� */
  }
  if ((p!=NULL) && p->kind == TERM)
    error("`%s' - ��� ࠭�� ��।�������� �ନ����\n", id);
  error("`%s' - �� ��।������ ���ନ���\n", id);
  return addnonterm(id);
}

static Nonterm addnonterm(char* id)
{
Nonterm p,              /* ���� ���ਯ�� ���ନ����*/
    *q;                 /* ���� ���� �.ᯨ᪠ ����.*/
  q = &nts;                 /* ���� ���� �.ᯨ᪠ ����.*/
  p = install(id);              /* ᮧ����� ������ ���ਯ��  */
  p->kind = NONTERM; p->number = ++ntnumber;
  p->lhscount=0; p->reached=0;
  p->rules = NULL; p->chain = NULL; p->link = NULL;
  /*            ���� 墮�� ᯨ᪠ ���ନ����� :              */
  while (*q!=NULL && (*q)->number < p->number) q = &(*q)->link;
  assert(*q == NULL || (*q)->number != p->number);
  p->link = *q;                 /* �����. ���ਯ�� � ����⢥*/
  *q = p;                       /* 墮�� ᯨ᪠ ���ନ�����   */
  p->rules=NULL;
  return p;
}
/****************************************************************/
/* term - ���� ����� �ନ���� � ��-⠡���; ᮧ����� ������  */
/* ���ਯ�� �����, �᫨ �� ��������� � ����祭�� ��� �     */
/* ��騩 ᯨ᮪ �ନ����� � ᮮ⢥��⢨� � ���譨� ����஬ esn */
/****************************************************************/
static Term term(char *id,  /* ��� �ନ����                */
            int esn)            /* ���譨� ᨬ�����᪨� �����  */
{
  Term p = lookup(id),          /* ���� ���ਯ�� �ନ����  */
      *q = &terms;              /* ���� ���� ��饣� ᯨ᪠ �.*/
  if (p) error("����୮� ��।������ �ନ����`%s'\n", id);
  else p = install(id);         /* ᮧ����� ������ ���ਯ��  */
  p->kind = TERM; p->esn = esn; p->arity = -1;
  p->rules = NULL;
  /* ���� ���� � ��饬 ᯨ᪥ �ନ�����, 㯮�冷祭��� ��    */
  /* ���譨� ����ࠬ                                            */
  while ((*q!=NULL) && (*q)->esn < esn) q = &(*q)->link;
  if ((*q!=NULL) && (*q)->esn == esn)
    error("�㡫�஢���� ���譥�� ����� �ନ����`%s=%d'\n",
    p->name, p->esn);
  p->link = *q;                 /* ����祭�� ���ਯ�� � ��騩*/
  *q = p;                       /* ᯨ᮪ �ନ�����            */
  return p;
}
/****************************************************************/
/* tree - ᮧ����� ���ਯ�� 㧫� ��ॢ� ��� 蠡���� �ࠢ���  */
/****************************************************************/
static Tree tree(char *id,      /* �室��� ��� 㧫�             */
                 Tree left,     /* ����� �����ॢ�              */
                 Tree right,    /* �ࠢ�� �����ॢ�             */
                 int par)       /* ����� �ਯ�ᠭ���� ��ࠬ��� */
{
  Tree t = alloc(sizeof *t);    /* ᮧ����� ���ਯ�� 㧫�    */
  Term p = lookup(id);          /* ���� ����� 㧫� � ⠡���   */
  int arity = 0;                /* 䠪��᪠� �୮��� 㧫�     */
  if (left && right) arity = 2;
  else if (left) arity = 1;
  if (p == NULL && arity > 0)
  {
    error("����।������ �ନ���`%s'\n", id);
    p = term(id, -1);
  }
  else if (p == NULL && arity == 0) p = (Term)nonterm(id);
       else if (p && p->kind == NONTERM && arity > 0)
            {
              error("`%s'࠭�� ��।������ ���ନ���`%s'\n",
                      id);
              p = term(id, -1);
            }
  if (p->kind == TERM && p->arity == -1) p->arity = arity;
  if (p->kind == TERM && arity != p->arity)
    error("�������⨬�� �୮��� ��� ���ନ���� `%s'\n", id);
  t->op = p; t->par=par;
  t->nterms = p->kind == TERM;
  if (t->left = left) t->nterms += left->nterms;
  if (t->right = right) t->nterms += right->nterms;
  return t;
}
/****************************************************************/
/* rule - ᮧ����� � ���樠������ ���ਯ�� �ࠢ���          */
/****************************************************************/
static Rule rule(char *id,      /* १. ��� �ࠢ���(���ନ���) */
                 Tree pattern,  /* ��ॢ� 蠡���� �ࠢ���       */
                 int ern,       /* ���譨� ����� �⮣� �ࠢ���  */
                 int cost,      /* ����⠭⭠� �⮨�����        */
                 char *c,       /* ⥪�� �᫮��� �ࠡ��뢠���   */
                 char *d,       /* ⥪�� �������᪮� �⮨���� */
                 int  *auxc)    /* ����� ��������. �⮨���⥩  */
{
  Rule r, *q;
  Term p;
  r = alloc(sizeof *r);         /* ᮧ����� ���ਯ�� �ࠢ��� */
  p = pattern->op;          /* �����誠 ��ॢ� 蠡����      */
  nrules++;                     /* ��饥 �᫮ �ࠢ�� �ࠬ��⨪�*/
  r->lhs = nonterm(id);         /* ���� ����.���ନ�. �ࠢ���*/
//kevin  r->packed = ++r->lhs->lhscount;
  r->packed = nrules;

  /* ���� 墮�� ᯨ᪠ �ࠢ�� �ࠬ��⨪� � ⥬ ��             */
  /* १������騬 ���ନ�����, �� � � ������� �ࠢ���       */

  for (q = &r->lhs->rules; *q!=NULL; q = &(*q)->decode);
  *q = r;
  r->pattern = pattern; r->ern = ern; r->cost = cost;
  r->auxc = auxc; r->cond=c; r->dyncost=d;
  r->decode=NULL; r->chain=NULL; r->kids=NULL; r->link=NULL;
  if (p->kind == TERM)
  {
    r->next = p->rules;
    p->rules = r;
  }
  else if (pattern->left == NULL && pattern->right == NULL)
       {
         Nonterm p = pattern->op;
         r->chain = p->chain;
         p->chain = r;
       }
  /*     ���� 墮�� ��饣� ᯨ᪠ �ࠢ�� �-�ࠬ��⨪�:        */
  for (q = &rules; *q!= NULL && (*q)->ern<r->ern;q =&(*q)->link);
  if (*q && (*q)->ern == r->ern)
    error("�㡫�஢���� ���譨� ����� �ࠢ��� `%d'\n", r->ern);
  r->link = *q;
  *q = r;
  print("%1(* %R *)\n\n", r); 
  return r;
}

