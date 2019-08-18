/****************************************************************/
/* <oemit.c> 30 ������ 94  ��᫥���� ���������:   11 ���� 95  */
/*    ��楤��� ᡮન ��室���� ⥪�� �������஬ BurBeG      */
/*    �� ����७���� �।�⠢����� �室��� �ࠬ��⨪�           */
/****************************************************************/
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "oburg.h"              /* ����⠭��, ᮡ�⢥��� ⨯�  */
                                /* � ᯥ�䨪�樨 ��� ��楤�� */
                                /*      �室��� �ࠬ��⨪�:     */
int ntnumber = 0;               /* ��饥 �᫮ ���ନ�����     */
Nonterm start=NULL;             /* ��砫�� ���ନ���         */
Term terms=NULL;                /* ᯨ᮪ �ନ�����            */
Nonterm nts=NULL;               /* ᯨ᮪ ���ନ�����          */
Rule rules=NULL;                /* ᯨ᮪ �ࠢ��                */
int nrules=0;                   /* ��饥 �᫮ �ࠢ��           */
int costvl=1;                   /* ��饥 �᫮ �⮨���⥩       */
int *auxtype;                   /* ������ �㭪権 �⮨���⥩    */
                                /*     ����⥪�⮢� ��樨:     */
char *pronmac[STSIZE];          /* ����� ����ᮢ              */

/****************************************************************/
/*  ���ઠ �᭮����� ⥪�� ᥫ���� �� �몥 ���஭-2 ��� ��: */
/****************************************************************/
void emitnames(Nonterm nts,   /* ᯨ᮪ ���ନ�����      */
                     int ntnumber)  /* �᫮ ���ନ�����       */
{
  Nonterm p;                        /* ��।��� ���ନ���     */
    print ("<* IF ~nodebug THEN *>\nTYPE ArrayOfString = ARRAY NT OF ARRAY 20 OF CHAR;\n");
    print ("CONST\n    NTName* = ArrayOfString {\n      'XXX'");
    for (p = nts; p != NULL; p = p->link)
    {
      print (",\n      '%S'", p );
    }
    print("\n    };\n<* END *>\n\n");
}

void emitdmodule(
                 char *b,      /* ��� 䠩�� � �����            */
                 int l        /* ����� �⮣� �����             */
                )
{
  print ("-- source grammar = %s\n<*+WOFF*>\n", b);
  print("MODULE BurgNT;\nIMPORT ir, SYSTEM;\n",b);
//  b[l]='d';
  emitdefsd(nts, ntnumber);    /* ᡮઠ ��।������ ����.   */
  emitstruct(nts, ntnumber);  /* ᡮઠ ���.�������� state   */
  emitnames(nts, ntnumber);
  print ("END BurgNT.\n", b);
}

/****************************************************************/
void emitnmodule(
                 char *b,      /* ��� 䠩�� � �����            */
                 int l        /* ����� �⮣� �����             */
                )
{
  print ("-- source grammar = %s\n<*+WOFF*>\n", b);
  print("MODULE BurgTables;\n\nIMPORT ir, RD := RDefs, BurgNT, SYSTEM;\n",b);
//  b[l]='d';

  emitnts(rules, nrules);     /* ᡮઠ ᯨ᪠ 蠡�. ����.  */
  emitkids(rules, nrules);    /* ᡮઠ ��楤��� burm_kids   */
  emitterms(terms);           /* ᡮઠ ������� �ନ�����   */

  print ("END BurgTables.\n", b);
}

/****************************************************************/

int emitimodule()
{
Nonterm p;                      /* ��।��� ���ନ���         */
    if (start)                  /* �⬥⪠ ��� ���ନ�����,   */
      ckreach(start);           /* ���⨦���� �� ��砫쭮��     */
    for (p = nts; p; p = p->link)
      if (!p->reached)
        error("�����⨦��� ���ନ��� `%s'\n", p->name);
//    emitheader();               /* ᡮઠ ALLOC � burm_assert   */
//    emitdefs(nts, ntnumber);    /* ᡮઠ ��।������ ����.   */
//    emitstruct(nts, ntnumber);  /* ᡮઠ ���.�������� state   */
 //d    emitterms(terms);           /* ᡮઠ ������� �ନ�����   */
    if (Iflag) emitstring(rules); /*ᡮઠ ����. �⮨�. � �ࠢ��*/
//    emitrule0(nts);             /* ᡮઠ ��।������ �.�ࠢ�� */
 //d    emitnts(rules, nrules);     /* ᡮઠ ᯨ᪠ 蠡�. ����.  */
//    emitrule(nts);              /* ᡮઠ �.�ࠢ�� + burm_rule */
//  emitclosure (nts, b, j-2, bf1);
//    emitstate(terms, start, ntnumber,b, bf2); }
    return errcnt;
}

/****************************************************************/
/* emitaction - ᡮઠ ��������� ��楤��� action               */
/****************************************************************/
void emitactions()
{
  print("PROCEDURE %Pactions* (c: BurgNT.Rule; n: RD.DAGNODE);\n"
        "BEGIN\n"
        "  CASE c OF\n");
}

/****************************************************************/
/* emitactrule - ᡮઠ �ࠣ���� ��楤��� action ��           */
/*               ���譥�� ⥪�� � ��ࠬ��ࠬ�                  */
/****************************************************************/
void emitactrule(int x,         /* ���譨� ����� �ࠢ���        */
                Tree p)         /* 蠡��� �ࠢ���               */
{
char *stbp[DIMSTM];             /* �⥪ 㪠��⥫�� ⥫ ����ᮢ */
register m;                     /* ������ �⥪� ����ᮢ        */
//register i;                     /* ���稪� ����               */
int n=0;                        /* ����� ���ம�।������       */
char *t;                        /* ���� ����� �ࠣ����        */
char names[PVSIZE][PLSIZE];     /* ⠡��� ���� ��⮪           */
int fspace=0;                   /* �ਧ��� �ய�᪠ �஡���     */
  t = bp;
  while (* t == ' ' || * t == '\r' || * t == '\n') t ++;
  if (* t == '}') {
    bp = ++ t;
        return;
  }
//  print("%1(* : %T *)\n", p );
  
  print("    |BurgNT.Rule{ %d }:\n%1 ", x);
  emitactpar(p,"n",names);      /* ���樠�� ⠡���� ��ࠬ��஢ */
  m=0;
  while(*bp!='}')               /* �� ���譨�� �������          */
  {
    switch(*bp)
    {
      case '\n':                /* ����� ��ப� ��. ⥪��      */
nl:     *bp=0; get(); --bp;     /* �⥭�� ����� ��ப�          */
/*%1*/
        print("\n"); fspace=1; continue;
      case '@': t=bp;           /* ��뫪� �� ���� @[INT]       */
        for(n=0, ++bp; isdigit(*bp); ++bp) n=n*10+(*bp-'0');
        if(n>=PVSIZE)
        {
          error("�����४�� ����� ��ࠬ���: %s\n",t); goto cl;
        }
        print("%s",&names[n][0]); /* ���譥� ��� ��ࠬ���      */
        fspace=0; continue;
      case '%':
        t = bp;
        print(" %P");
        for(++bp; isalpha(*bp); ++bp)
          print("%c", *bp);
//        print("_NT");
        fspace=0; continue;

      case '$': t=bp;           /* ���ய���⠭���� $[INT]      */
        for(n=0, ++bp; isdigit(*bp); ++bp) n=n*10+(*bp-'0');
        if(n>=STSIZE)
        {
          error("�����४�� ����� �����: %s\n",t); goto cl;
        }
        if(m<DIMSTM)
        {
          stbp[m++]=bp; bp=pronmac[n];
        }
        else print("%s",pronmac[n]); /* ⥫� ���ம�।������   */
        fspace=0; continue;
      case 0:
        if(m>0)
        {
          bp=stbp[--m]; continue;
        }
        else goto nl;
      case ' ': case '\t': ++bp;
//        if(!fspace)
        print(" ");
        continue;
      default:                  /* ���⮥ ����஢���� �����   */
      cl: print("%c",*bp++);
          fspace=0; continue;
    }
  }
  print("\n"); ++bp;
}

/****************************************************************/
/* emitactpar - ᡮઠ ��楤���� �ࠣ���⮢ - ����            */
/* �⬥祭��� 㧫�� 蠡���� ��� ��ࠬ��஢                      */
/* �� ᮮ⢥������� 㧫�� ����뢠����� ��ॢ�                 */
/****************************************************************/
static void emitactpar(Tree t,  /* ��७� ��ॢ� 蠡����        */
                       char *v, /* ��室��� ��� 㧫� ��.��ॢ�  */
                       char names[PVSIZE][PLSIZE])
                                /* ⠡��� ���� ��⮪           */
{
//register i;                     /* ���稪 ����                */
  if(t->par>=0)                 /* 㧥� 蠡���� �⬥祭         */
  {
    if(strlen(v)>=PLSIZE)
    {
      error("����� ����� ��ࠬ��� %d �������⨬� ������",t->par);
      return;
    }
    if(t->par<PVSIZE) sprintf(&names[t->par][0],"%s\0",v);
    else error("����� ��ࠬ��� %d �������⨬� �����",t->par);
  }
  if(t->left) {
    char bs[BFSIZE];
    sprintf(bs,"%s.l",v);
    emitactpar(t->left,bs,names);
  }
  if(t->right) {
    char bs[BFSIZE];
    sprintf(bs,"%s.r",v);
    emitactpar(t->right,bs,names);
  }
}

/****************************************************************/
/* reach - �⬥⪠ ��� ��⥬������ � ��ॢ� t ��� ���⨦����   */
/****************************************************************/
static void reach(Tree t)
{
  Nonterm p = t->op;
  if (p->kind == NONTERM)
   if (!p->reached) ckreach(p);
  if (t->left)  reach(t->left);
  if (t->right) reach(t->right);
}
/****************************************************************/
/* ckreach - �⬥⪠ ��� ���ନ�����, ���⨦���� �� p         */
/****************************************************************/
static void ckreach(Nonterm p)
{
  Rule r;                       /* ��।��� �ࠢ���            */
  p->reached = 1;
  for (r = p->rules; r; r = r->decode) reach(r->pattern);
}

/****************************************************************/
/* emitaux -  ᡮઠ ⥪�� �������⥫��� �⮨���⥩ �ࠢ���   */
/*            � ��⠢� ����� case �㭪樨 state                */
/****************************************************************/
static void emitaux(Rule r,     /* �ࠢ���                      */
                    char *b)    /* ��� 䠩�� _d                 */
{
register i,j;                   /* ���稪                      */
int m;                          /* �᫮ ��㬥�⮢ �.�⮨���� */
  for(i=0; i<costvl-1; ++i)
  {
    print("%3c%d := ",i+1);
    switch(auxtype[i])
    {
      case 0:
        if(r->pattern->left)  emitcost1(r->pattern->left, "l",i,b);
        if(r->pattern->right) emitcost1(r->pattern->right,"r",i,b);
        break;
      case 1:
        m=0;
        if(r->pattern->left)  emitcost2(r->pattern->left, "l",i+1,&m,b);
        if(r->pattern->right) emitcost2(r->pattern->right,"r",i+1,&m,b);
        if(m>0) print(",0");
        for(j=0; j<m; ++j) print(")"); if(m>0) print("+");
        break;
    }
    print("%d;\n", r->auxc[i]);
  }
}

static void print_tabs (int n)
{
        while (n) {
                print ("\t");
                n --;
        }
}

/****************************************************************/
/* emitcase - ᡮઠ ������ case � ��⠢� �㭪樨 state ���    */
/*            ������ �室���� �ନ����, �ࠢ���饣� ࠧ��஬  */
/* � ���ᯥ稢��饣� ���᫥��� ࠧ��⪨ ���������� �����⨩   */
/* ��ॢ쥢, ��୥� ������ ���� ����� �ନ���, ���       */
/* ��� ���ନ�����, ��୥� 蠡���� ������ ���� �����    */
/* �ନ����� ᨬ���                                          */
/****************************************************************/
static void emitcase(   Term p,         /* �室��� �ନ���     */
                        int ntnumber,   /* �᫮ ���ନ�����   */
                        char *b,        /* ��� �� ᥫ����   */
                        int l)          /* ����� ����� 䠩��    */
{
  Rule r;                               /* ⥪�饥 �ࠢ���      */
  int i;
  int ntabs;
  char names[PVSIZE][PLSIZE];           /* ����� ��ࠬ��஢     */

  print ("\n"
         "PROCEDURE newstate_%S* (n: RD.DAGNODE); (* %d *)\n"
         "VAR     c0:   LONGINT;\n"
         "        p:    ir.TriadePtr;\n"
         "        l, r: RD.DAGNODE;\n",
         p, p -> esn
        );
  if (costvl > 1) {
    print ("VAR c1");
    for (i = 1; i < costvl - 1; ++ i)
      print (",c%d", i + 1);
    print (": INTEGER;\n");
  }

  print ("BEGIN\n"
         "%1n.cost := MaxCost;\n"
         "%1l := n.l;\n"
         "%1r := n.r;\n"
         "%1p := n.tr;\n"
    );

  switch (p->arity) {
    case -1:
    case 0:
    case 1:
    case 2:  break;
    default: assert(0);
  }

  for (r = p -> rules; r != NULL; r = r -> next) {  /*��� ��� �ࠢ�� � �⨬*/
                                                    /*�ନ����� � ����⢥ */
                                                    /*���� ��ॢ� 蠡����  */
    print("\n(* %R  %d *)\n", r, r->ern );
    ntabs = 1;
    switch (p -> arity) {
      case -1:
      case  0:
        if (r->cond || r -> dyncost)
          emitactpar (r -> pattern, "n", names);        /*���.��ࠬ��஢*/
        if (r -> cond)
          emitcond (r -> cond, ntabs ++, names);        /*��������. �᫮���*/
        if (costvl > 1)
          emitaux (r, b);                       /* �������⥫�� �⮨���� */
        print_tabs (ntabs);
        print ("c0 :=");
        break;                      /* ����� ��� �⮨���� ��⢥�*/
      case 1:
        if (r -> pattern -> nterms > 1) {
          print_tabs (ntabs);
          print ("IF ");
          emittest (r -> pattern -> left, ntabs * 8 + 3, 0, "l", " ");
          print_tabs (ntabs ++);
          print ("THEN\n");
        }
        if (r -> cond || r -> dyncost)
          emitactpar (r -> pattern, "n", names);      /*���.��ࠬ��஢*/
        if (r -> cond)
          emitcond (r -> cond, ntabs ++, names);      /*��������. �᫮���*/
        if (costvl > 1)
          emitaux (r, b);                     /* �������⥫�� �⮨���� */
        print_tabs (ntabs);
        print ("c0 := ");
        emitcost (r -> pattern -> left, "l", b);
        break;
      case 2:
        if (r -> pattern -> nterms > 1) {
          int was_text;
          print_tabs (ntabs);
          print ("IF ");
          was_text = emittest (r -> pattern -> left, ntabs * 8 + 3, 0, "l",
                               r -> pattern -> right -> nterms ? "&": " ");
          emittest (r -> pattern -> right, ntabs * 8 + 3, was_text, "r", " ");
          print_tabs (ntabs ++);
          print ("THEN\n");
        }
        if (r -> cond || r -> dyncost)
          emitactpar (r -> pattern, "n", names);        /*���.��ࠬ��஢*/
        if (r -> cond)
          emitcond (r -> cond, ntabs ++, names);        /*��������. �᫮���*/
        if (costvl > 1)
          emitaux (r, b);                       /* �������⥫�� �⮨���� */
        print_tabs (ntabs);
        print("c0 := ");
        emitcost (r -> pattern -> left,  "l", b);
        emitcost (r -> pattern -> right, "r", b);
        break;
      default:
        assert (0);
    }
    /* C���⢥���� �᭮���� �⮨����� �ࠢ��� � ��� �᫠      */
    /* �ᯮ�짮����� ������� १����:                        */
    print ("%d;\n", r -> cost);
    emitrecord (ntabs == 1 ? "\t" : ntabs == 2 ? "\t\t" : "\t\t\t",
                r, b, l, 1, names);  /* ᡮઠ ⥪�� ��� ��. �ࠢ.*/
    if (r -> cond != NULL) {
      print_tabs (-- ntabs);
      print ("END;\n");
    }
    if (r -> pattern -> nterms > 1) {
      print_tabs (-- ntabs);
      print ("END;\n");
    }
  }
  print ("END newstate_%S;\n", p );
}


/****************************************************************/
/* emitclosure - ᡮઠ ��楤�� closureX, ���ᯥ稢���� �롮� */
/* 楯��� �ࠢ�� ��� ��� ���ନ����� X �室��� �ࠬ��⨪�     */
/****************************************************************/
void emitclosure(Nonterm nts,  /* ᯨ᮪ ���ନ�����           */
                 char *b,      /* ��� 䠩�� � �����            */
                 int l,        /* ����� �⮣� �����             */
                 char *import) /* ��ப� ��� ᯨ᪠ ������ */
{
Nonterm p;                              /* ⥪�騩 ���ନ���   */
register int i;                         /* ���稪              */
char names[PVSIZE][PLSIZE];             /* ����� ��ࠬ��஢     */

//  print ("<*+WOFF*>\n");
//  print("MODULE %s;\n\n",b);
//  b[l-1]='d';
//  print("IMPORT D := %s, %s;\n",b, import);
//  b[l-1]='c';
  for (p = nts; p!=NULL; p = p->link)   /* ���⨯� ��楤��   */
    if (p->chain!=NULL)                 /* � ������� ���ନ����*/
                                        /* ���� 楯�� �ࠢ���  */
      {
        print(
    "PROCEDURE ^ %Pclosure_%S (n: RD.DAGNODE; ic0: LONGINT", p);
        for(i=0; i<costvl-1; ++i) print("; ic%d: INTEGER",i+1);
        print(");\n");
      }
  print("\n");
  for (p = nts; p!=NULL; p = p->link)   /* ᮡ�⢥��� ��楤��� */
    if (p->chain !=NULL)
    {
      Rule r;                           /* ��।��� �ࠢ���    */

      print("PROCEDURE %Pclosure_%S* (n: RD.DAGNODE; ic0: LONGINT", p);
      for(i=0; i<costvl-1; ++i) print("; ic%d: INTEGER",i+1);
      print(");\n"
        "VAR c0: LONGINT;\n");
      if(costvl>1)
        {
          print("VAR c1");
          for(i=1; i<costvl-1; ++i) print(", c%d", i+1);
          print(": INTEGER;\n");
        }
      print("BEGIN\n");
      for (r =p->chain;r!=NULL;r=r->chain)/* �� 楯�� �ࠢ��� */
      {                                   /* ������� ���ନ����*/
        if(r->cond!=NULL || r->dyncost!=NULL)
              emitactpar(r->pattern,"n",names);  /*���.��ࠬ��஢*/
        if(r->cond!=NULL)
                emitcond (r->cond, 0, names);         /*��������. �᫮���*/
        if(r->cost!=NULL) /* 楯��� �ࠢ��� ���㫥��� �⮨���� */
          print("%1c0 := ic0 + %d;\n",r->cost);
        else            /* 楯��� �ࠢ��� �㫥��� �⮨����     */
          print("%1c0 := ic0;\n");
        for(i=0; i<costvl-1; ++i)
        {
          switch(auxtype[i])
          {
            case 0: case 1:
          if(r->auxc[i]!=NULL)
                 /*�ࠢ��� ���㫥�. ���.�⮨����  */
                print("%1c%d := ic%d + %d;\n",i+1,i+1,r->auxc[i]);
              else           /*�ࠢ��� �㫥��� �⮨����       */
                print("%1c%d := ic%d;\n",i+1,i+1);
              break;
            case 2:
              print("%1c%d :=%d;\n",i+1,r->auxc[i]);
              break;
          }
        }
        emitrecord("\t",r,"D.",l,0,names);
        if(r->cond!=NULL)
          print ("%1END;\n");
      }
      print ("END %Pclosure_%S;\n\n", p);
    }
//  print ("END %s.\n", b);
}

/****************************************************************/
/* emitcond - ᡮઠ ⥪�� �������⥫쭮�� �᫮���             */
/****************************************************************/
static void emitcond(char *s,        /* ⥪�� ���譥�� �᫮���  */
                     int ntabs,
                     char names[PVSIZE][PLSIZE]) /* ����� ��ࠬ.*/
{
  print_tabs (ntabs);
  print ("IF ");
  if (emitxtxt (s, ntabs * 8 + 3, names)) {
    print ("\n");
    print_tabs (ntabs);
    print ("THEN\n");
  }
  else
    print (" THEN\n");
}

/****************************************************************/
/* emitcost - ᡮઠ ��楤�୮�� �ࠣ���� ��� ���᫥���      */
/*            �᭮���� �⮨���� �ࠢ��� � 蠡����� t           */
/****************************************************************/
static void emitcost (Tree t,           /* ��ॢ� 蠡����       */
                      char * v,         /* ⥪�⮢�� ��� ����  */
                      char * b)         /* ��� 䠩�� _d         */
{
  Nonterm p = t -> op;                  /* ⥪�騩 㧥� ��ॢ�  */

  if (p -> kind == TERM) {
    if (t -> left)
      emitcost (t -> left,  stringf ("%s.l", v), b);
    if (t -> right)
      emitcost (t -> right, stringf ("%s.r", v), b);
  }
  else
    print ("VAL (LONGINT, %s.cost [%P%S]) + ", v, p);
}

/****************************************************************/
/* emitcost1 - ᡮઠ ��楤�୮�� �ࠣ���� ��� ���᫥���     */
/*             �������⥫쭮� �⮨���� �ࠢ��� � 蠡����� t    */
/****************************************************************/
static void emitcost1(  Tree t,         /* ��ॢ� 蠡����       */
                        char *v,        /* ⥪�⮢�� ��� ����  */
                        int n,          /* ����� ���.�⮨����  */
                        char *b)        /* ��� 䠩�� _d         */
{
  Nonterm p = t->op;                    /* ⥪�騩 㧥� ��ॢ�  */
  if (p->kind == TERM)                  /* �� �ନ���         */
  {
    if (t->left)
      emitcost1(t->left, stringf(Cflag?"%s->l":"%s.l",v),n,b);
    if (t->right)
      emitcost1(t->right,stringf(Cflag?"%s->g":"%s.r",v),n,b);
  }
  else                                  /* ���ନ���-��⮬��   */
  {
    if(Cflag)
      print("\n%3%s->auxc[%P%S][%d] + ", v, p, n);
    else
      print("\n%3%s.auxc[%s%P%S][%d] + ", v, b, p, n);
  }
}

/****************************************************************/
/* emitcost2 - ᡮઠ ��楤�୮�� �ࠣ���� ��� ���᫥���     */
/* ᯥ樠�쭮� �������⥫쭮� �⮨���� �ࠢ��� � 蠡����� t    */
/****************************************************************/
static void emitcost2(  Tree t,         /* ��ॢ� 蠡����       */
                        char *v,        /* ⥪�⮢�� ��� ����  */
                        int n,          /* ����� ���.�⮨����  */
                        int *m,         /* �᫮ ��㬥�⮢     */
                        char *b)        /* ��� 䠩�� _d         */
{
  Nonterm p = t->op;                    /* ⥪�騩 㧥� ��ॢ�  */
  if (p->kind == TERM)                  /* �� �ନ���         */
  {
    if (t -> left)
      emitcost2 (t->left,  stringf ("%s.l", v), n, m, b);
    if (t -> right)
      emitcost2 (t->right, stringf ("%s.r", v), n, m, b);
  }
  else                                  /* ���ନ���-��⮬��   */
  {
    if(* m > 0)
      print (",\n");
    print ("\n%3%s%Pfcost%d (%s, %s%P%S", b, n, v, b, p);
    ++ (* m);
  }
}

/****************************************************************/
/* emitdefsd - ᡮઠ ��室��� ��।������ ���ନ�����          */
/****************************************************************/
void emitdefsd(Nonterm nts,   /* ᯨ᮪ ���ନ�����      */
                     int ntnumber)  /* �᫮ ���ନ�����       */
{
  Nonterm p;                        /* ��।��� ���ନ���     */
    print ("TYPE NT *= (\n     NTnowhere,\n");
    for (p = nts; p->link != NULL; p = p->link)
    {
      print ("     %P%S,\n", p );
//kevin      print ("CONST %P%S *= %d;\n", p, p -> number);
    }
    print("     %P%S\n     );\n", p);
//    print("CONST %Pmax *= %P%S;\n\n", p);
}

/****************************************************************/
/* emitdefsi - ᡮઠ ��室��� ��।������ ���ନ�����          */
/****************************************************************/
void emitdefsi(Nonterm nts,   /* ᯨ᮪ ���ନ�����      */
                     int ntnumber)  /* �᫮ ���ନ�����       */
{
  Nonterm p;                        /* ��।��� ���ନ���     */
    print ("\nTYPE NT = BurgNT.NT;\nCONST NTnowhere = BurgNT.NTnowhere;\n");
    for (p = nts; p != NULL; p = p->link)
    {
      print ("CONST %P%S = BurgNT.%P%S;\n", p, p);
    }
    print("\n\n");
}

/****************************************************************/
/* emitheader - ᡮઠ ��।������ ALLOC � burm_assert          */
/****************************************************************/
//static void emitheader(void)
//{
//}

/****************************************************************/
/* computekids - ���᫥��� ��� ��⥩ � "����"-���ନ�����   */
/****************************************************************/
static char *computekids(Tree t,        /* 㧥� ��ॢ�          */
                         char *v,       /* ��� ��� "ॡ����"    */
                         char *bp,      /* ���ୠ� ��ப�      */
                         int *ip)       /* ⥪�饥 �᫮ ��⥩- */
{                                       /* ���ନ����� 蠡���� */
  Term p = t->op;                       /* ⥪�騩 㧥� ��ॢ�  */
  if (p->kind == NONTERM)    /* ���ନ���, ���뢠�騩 ����    */
  {                          /* �� ������ ��⢨ ��ॢ�          */
    sprintf(bp, "\t\tkids[%d] := %s;\n", (*ip)++, v);
    bp += strlen(bp);
  }
  else          /* �ନ���: ४��ᨢ�� ��室 �த��������     */
    if (p->arity > 0)
    {
      bp = computekids(t->left,
           stringf("%s.l", v), bp, ip);
      if (p->arity == 2)
        bp = computekids(t->right,
           stringf("%s.r",v), bp, ip);
    }
  return bp;    /* �����頥��� ᢮����� 墮�� ����          */
}

/****************************************************************/
/* emitkids - ᡮઠ ��楤��� burm_kids                        */
/****************************************************************/
static void emitkids(   Rule rules,     /* ᯨ᮪ �ࠢ��        */
                        int nrules)     /* �᫮ �ࠢ��         */
{
int f=0;                /*�ਧ��� ᠬ��� ��ࢮ�� case �� �뢮��*/
/****************************************************************/
/* ���᫥��� ����୮ ��ᮢ������� ⥪�⮢�� �ࠣ���⮢ ����   */
/* kids[i]=v;... ��������� ��⥩-���ନ����� � ��⠢�     */
/* 蠡����� ��� �ࠢ�� �室��� �-�ࠬ��⨪�:                   */
int i,ix;              /* ���稪 �ࠢ�� � �࠭�� ����������   */
Rule r,                /* ��।��� �ࠢ���                     */
    *rc;       /* �ࠢ���, ᮯ��⠢����� �ࠣ���⠬:           */
char **str;    /*⥪��� ��楤���� �ࠣ���⮢ ���� kids[i]=v;..*/
  int maxNKids = 0;

  rc = alloc((nrules + 1)*sizeof *rc);
  for(i=0; i<=nrules; ++i) rc[i]=NULL;
  str=(char **)alloc((nrules + 1)*sizeof *str);
  for(i=0; i<=nrules; ++i) str[i]=NULL;

  for (r = rules; r!=NULL; r = r->link)
  {
    int d = 0;      /*�᫮ ��⥩(���ନ�����) 蠡���� �ࠢ��� */
    register j;     /*�ᯮ����⥫�� ���稪                   */
    char buf[1024], /*���� ��� ����������  ⥪�� kids[i]=v;...*/
         *bp = buf; /*㪠��⥫� �� ᢮������ ���� � �⮬ ����*/

    /* ���᫥��� ⥪�� �ࠣ���� kids[i]=v;...������� �ࠢ���:*/
       *computekids(r->pattern, "n", bp, &d) = 0;
    if( maxNKids < d ) 
      maxNKids = d;
    /* �ࠢ����� ����祭���� �ࠣ���� � 㦥 �������騬�:     */
    for (j = 0; str[j]!=0 && strcmp(str[j], buf)!=0; j++);
    if (str[j] == NULL)         /* ������ �ࠣ���� �� �� �뫮 */
      str[j]=strcpy(alloc(strlen(buf)+1),buf);  /*���������� ���*/
    r->kids = rc[j];    /* �����⠢����� �ࠢ��� ��� �ࠣ����  */
    rc[j] = r;          /* �����⠢����� �ࠣ����� ��� �ࠢ���  */
  }
/****************************************************************/
/* C��ઠ ࠭�� ����������� ⥪�⮢�� �ࠣ���⮢:               */
  print ("PROCEDURE %Pkids* (n: RD.DAGNODE; eruleno: BurgNT.Rule;\n"
                           "%2VAR kids: ARRAY OF RD.DAGNODE);\n"
         "BEGIN\n"
         "    CASE eruleno OF\n");

  for (i = 0; (r = rc [i]) != NULL; i ++) {    /* �� ᯨ�� �ࠣ���⮢ */
    ix = 0;
    for (f = 0; r != NULL; r = r -> kids) {    /* ��� ��� �ࠢ��,��樤.�ࠣ�.*/
      ix = 1;
      if (f)
        print (",\n%1 BurgNT.Rule{ %d }%1(* %R *)", r -> ern, r);
      else {
        print    ("%1|BurgNT.Rule{ %d }%1(* %R *) ", r -> ern, r);
        f = 1;
      }
    }
    if (ix)
      print (":\n%s\n", str [i]);
  }
  print("    END;\n");
  print("END %Pkids;\n");
  print("CONST MAXNKIDS *= %d;\n\n", maxNKids);
}

/****************************************************************/
/* closure - ���������� ����� �⮨���⥩ � �ࠢ�� १���⠬�  */
/* 楯��� �ࠢ�� � ���ନ����� p � ����⢥ �ࠢ�� ���       */
/****************************************************************/
static void closure(int cost[], Rule rule[], Nonterm p, int c)
{
  Rule r;                               /* ��।��� �ࠢ���    */
  for (r = p->chain; r; r = r->chain)
    if (c + r->cost < cost[r->lhs->number])
    {
      cost[r->lhs->number] = c + r->cost;
      rule[r->lhs->number] = r;
      closure(cost, rule, r->lhs, c + r->cost);
    }
}

/****************************************************************/
/* computents - �뢮� � ��ப� bp ���� ��� ���ନ����� ��     */
/*              蠡���� �ࠢ���, ��������� ��ॢ�� t            */
/****************************************************************/
static char *computents(Tree t,         /* ��ॢ� 蠡����       */
                        char *bp,       /* ���� ��� �뢮��     */
                        int *k)         /* �᫮ ���ନ����� � */
{                                       /* 蠡����              */
  if (t)
  {
    Nonterm p = t->op;                  /* ⥪�騩 㧥� ��ॢ�  */
    if (p->kind == NONTERM)
    {
      sprintf(bp, "BurgNT.%s%s, ", prefix, p->name);
      bp += strlen(bp); ++*k;
    }
    else bp = computents(t->right, computents(t->left,  bp, k), k);
  }
  return bp;
}

/****************************************************************/
/* emitnts - ᡮઠ ��।������ ���ᨢ� burm_nts ����୮        */
/* ��ᮢ������� ᯨ᪮� ���ନ����� �� 蠡����� �ࠢ��,       */
/* ���ᨢ�� burm_nts_i ��� ᯨ᪮� � ���.���樠樥� ��� ��   */
/* ���ᨨ � ᡮમ� ��楤��� burm_nts_init ��� ���஭-2 ���ᨨ */
/****************************************************************/
static void emitnts(Rule rules, /* ᯨ᮪ �ࠢ��                */
                    int nrules) /* �᫮ �ࠢ��                 */
{
Rule r;                         /* ⥪�饥 �ࠢ���              */
int i, j,
   k,  /* �᫮ ���ନ�����, ���������� � 蠡���� �ࠢ���   */
   l,  /* �㬬�ୠ� ����� ���ᨢ� nts_n (��� ���ᨨ O-2)        */
   m,  /* �᫮ �⫨������ ����� ᮡ�� ᯨ᪮� ���ନ�����   */
   *nts = alloc(nrules*sizeof *nts), /* ����� ᯨ᪮� �ࠢ��   */
   *lts= alloc(nrules*sizeof *nts);        /* ����樨 ᯨ᪮�   */
char **str = alloc(nrules*sizeof *str);    /* ⥪��� ᯨ᪮�    */
  for (m = l = k = i = 0, r = rules; r!=NULL;r = r->link,k = 0)
  {
    char buf[1024]; /* ���� ��� ⥪�饣� ⥪�� ᯨ᪠         */
    *computents(r->pattern,buf,&k) = 0; /* �ନ஢���� ⥪��  */
    /*     �ࠢ����� � 㦥 ����騬��� ᯨ᪠�� ���ନ�����:    */
    for (j = 0; j<m && strcmp(str[j], buf); j++);
    if (j==m)           /* ���᮪ ࠭�� �� ����砫��           */
    {
      /* ����������� ������ ᯨ᪠ ���� ��� ����஬ j:          */
      str[j] = strcpy(alloc(strlen(buf) + 1), buf);
      ++m; lts[j]=l++; l+=k;
    }
    nts[i++] = j;       /* ᮯ��⠢����� �ࠢ��� ��� 蠡����    */
  }
  print("TYPE Index *= INTEGER;\n");
  print("TYPE NTnts_nType = ARRAY OF BurgNT.NT;\n");
  print("CONST %Pnts_n*= NTnts_nType {\n");
  for(j=0; j<m; j++) print("%1%sBurgNT.NTnowhere%s (*%d*)\n",
                     str[j], j<m-1?" ,":" ", j);
  print("};\n");

  print("CONST nRules = BurgNT.Rule{ %d };\n", nrules);
  print("TYPE RuleRange   = BurgNT.Rule[BurgNT.Rule{0}..nRules];\n");
  print("     %PntsType = ARRAY RuleRange OF Index;\n");
  print("CONST %Pnts*= %PntsType {\n");
  for (i = j = 0, r = rules; r!=NULL; r = r->link, ++i, ++j)
  {
    for ( ; j < r->ern; j++)  print("%1Index{ 0 }, (*%d*)\n", j);
    print("%1Index{ %d }%s (*%d->%d*) \n",
    lts[nts[i]], r->link? "," : " ", j, nts[i]);
  }
  print("};\n");

  print("<* IF ~nodebug THEN*>\n");
  print("TYPE RuleNamesType = ARRAY RuleRange OF ARRAY 64 OF CHAR;\n");
  print("CONST RuleNames *= RuleNamesType {\n    'zerorule'");
  for (r = rules; r!=NULL; r = r->link)
  {
    print(",\n    '%R'", r);
  }
  print("\n    };\n");
  print("<* END *>\n");
}

/****************************************************************/
/* emitrecord - ᡮઠ ��楤�୮�� �ࠣ����, ���ᯥ稢��饣�  */
/* ���᫥��� �⮨���⭮�� �᫮��� �롮� �ࠢ��� r ��� 㧫� "p"*/
/* � ����室���� �⬥⮪ � ����� ��ਠ���� ��ਡ�⮢ 㧫� "p"*/
/* � ����⢨� �� ॠ����樨 �롮� r->"p" � ����� ࠧ��⪨  */
/* (� ��⠢� �ࠣ���� case �㭪樨 state � � ��⠢� �㭪権  */
/* �롮� 楯��� �ࠢ�� closure ��� ࠧ��� ���ନ�����).       */
/****************************************************************/
static void emitrecord( char *pre,      /* ⥪�⮢� �����     */
                        Rule r,         /* �ࠢ��� ��� �롮�   */
                        char *b,        /* ��� 䠩�� closure    */
                        int l,          /* ����� ����� 䠩��    */
                        int f,          /* �ਧ��� case-�맮��  */
                        char names[PVSIZE][PLSIZE]) /* ����� ��ࠬ.*/
{
  register int i;                       /* ���稪              */

  if(Tflag)
  {
      print("%s%Ptrace(%s%Pnp, %d, c0,", b,b,r->ern);
      for(i=0; i<costvl-1; ++i)   /* �������⥫�� �⮨����   */
        print("c%d,\n",i+1);
      print("n.cost[%P%S]", r->lhs);
      for(i=0; i<costvl-1; ++i)   /* �������⥫�� �⮨����   */
        print(", n.auxc[%s%P%S][%d]\n", b, r->lhs, i);
      print(");\n", r->lhs);
  }

  /**************************************************************/
  /*     �᫮��� �롮� �ࠢ��� r ��� 㧫� "p":                 */
  print("%sIF (c0 < n.cost[%P%S])", pre, r -> lhs);
  for(i = 0; i < costvl - 1; ++ i)      /* �������⥫�� �⮨����     */
    print(
      " OR\n%s((c%d=n.cost[%P%S]) &\n"
      "%s ((c%d<p.auxc[%s%P%S][%d])",
      pre,i,r->lhs, pre,i+1,b, r->lhs,i);
  for (i = 0; i < costvl - 1; ++ i)
    print ("))");
  print(" THEN\n");

  /**************************************************************/
  /* ⥪�� ����⢨�, �।�ਭ������� � ��砥 �ᯥ譮�� �롮�: */
  /* 1) �᭮���� �⮨����� �롮� �ࠢ��� r ��� 㧫� "p":       */
  print("%s%1n.cost[%P%S] := VAL (INTEGER, c0);\n",
         pre, r->lhs);

  /* 2) �⬥⪠ ����� �ࠢ���, ���饣� min �����⨥ ��� 㧫�   */
  /* "p" � १������饣� ���ନ���� �ࠢ��� r:               */
  print("%s%1n.rule[%P%S] := BurgNT.Rule { %d };\n", pre, r->lhs, r->packed);

  for(i=0; i<costvl-1; ++i)     /* 3) �������⥫�� �⮨����  */
                                /*    ������� �롮�:           */
     print("%s%1n.auxc[%s%P%S][%d] := c%d;\n", pre, b, r->lhs, i, i+1);

  /* 4) �⫠��筮� ᮮ�饭�� �� �ᯥ� �롮�                   */
  if(Tflag)
      print("%s%1%s%PPLUS(\"%S\");\n",pre,b,r->lhs);
  if(r->dyncost)
  {
      print("\n"); emitxtxt(r->dyncost, 0, names); print("\n");
  }

  /* 5) �맮� ��楤��� ��ࠡ�⪨ 楯��� �ࠢ�� ���             */
  /*    १������饣� ���ନ���� ������� �ࠢ��� r:          */
  if (r->lhs->chain)    /* ᯨ᮪ 楯��� �ࠢ�� ��� ���� ������:*/
  {
    if(f)               /* �ࠣ���� � ⥫� ����� _s            */
    {
      print("%s%1%Pclosure_%S(n, c0", pre, r->lhs);
    }
    else                /* �ࠣ���� � ⥫� ����� _c            */
      print("%s%1%Pclosure_%S(n, c0", pre, r->lhs);
    for(i=0; i<costvl-1; ++i)   /* �������⥫�� �⮨����     */
      print(",c%d",i+1);
    print(");\n");
  }

  /* 6) �⫠��筮� ᮮ�饭�� �� ���ᯥ� �롮�                 */
  if(Tflag)
      print("%sELSE%1%s%PMINUS(\"%S\");\n%sEND;\n",
            pre,b,r->lhs,pre);
  else
      print("%sEND;\n", pre);
}

/****************************************************************/
/*emitrule0 - ᡮઠ ᯨ᪮� �ࠢ�� ��� ���ନ����� (�ࠢ��)   */
/****************************************************************/
//static void emitrule0(Nonterm nts)      /* ᯨ᮪ ���ନ�����  */
//{
//  Nonterm p;                            /* ⥪�騩 ���ନ���   */
//
//  /*    ���ઠ ᯨ᪠ �ࠢ��, ��樤����� ���ନ�����          */
//  for (p = nts; p!=NULL; p = p->link)
//  {
//    Rule r;                             /* ⥪�饥 �ࠢ���      */
//
//    print("CONST %Pdecode_%S*= ARRAY OF INTEGER {\n%10", p);
//    for (r = p->rules; r!=NULL; r = r->decode)
//      print(",\n%1%d", r->ern);
//    print("\n};\n\n");
//  }
//}

/****************************************************************/
/* emitrule - ᡮઠ ��楤��� burm_rule, �������饩 �� ������*/
/*       ���ନ���� � ����� 㧫� ��ॢ� ������� ����� �ࠢ���*/
/****************************************************************/
//static void emitrule(Nonterm nts)       /* ᯨ᮪ ���ନ�����  */
//{
//  Nonterm p;                            /* ⥪�騩 ���ନ���   */
//
//  print("PROCEDURE %Prule*(state: RD.DAGNODE; goalnt: NT):INTEGER; \n"
//        "BEGIN\n"
///*        "  ASSERT ((goalnt >= 1) & (goalnt <= %d));\n"*/
///*      "  IF state=NIL THEN RETURN 0 END;\n" */
//        "  CASE goalnt OF\n", ntnumber);
//
//  for (p = nts; p!=NULL; p = p->link)
//      print("    | %P%S:\n"
////kevin      "        RETURN %Pdecode_%S [state.rule.%P%S]\n", p, p, p);
//      "        RETURN state.rule.%P%S\n", p, p);
//  print("  END;\n"
//        "  RETURN 0\n"
//        "END %Prule;\n"
//        "\n");
//} */

/****************************************************************/
/* emitstate - ᡮઠ ��楤��� newstate, ᮧ���饩 ���� 㧥�  */
/* ����뢠�饣� ��ॢ� � ������饩 ��� ��ਡ��� (������      */
/* �⮨���⥩ � �롮� ���������� A-�����⨩) � ����ᨬ��� �� */
/* ���ନ���� �� �室� � ���祭�� ᮮ⢥������� ��ਡ�⮢    */
/* �뭮��� ������� 㧫� � ����뢠�饬 ��ॢ�                    */
/****************************************************************/
void emitstate(  Term terms,            /* ᯨ᮪ �ନ�����    */
                        Nonterm start,  /* ��砫�� ���ନ��� */
                        int ntnumber,   /* �᫮ ���ନ�����   */
                        char *b,        /* ��� ��� 䠩�� _s     */
                        char *import)   /* ᯨ᮪ ������       */
{
  int i, l, N;                          /* �ᯮ���. ���稪     */
  Term p;                               /* ��।��� �ନ���   */

//  print ("<*+WOFF*>\n\n"
//         "MODULE %s;\n\n", b);
  for (l = 0; b [l] != 0; l ++)
    ;
//  b [l - 1] = 'c'; print ("IMPORT C := %s, ", b);
//  b [l - 1] = 'd'; print ("D := %s, %s, SYSTEM;\n", b, import);
//  b [l - 1] = 's';
  print ("\n"
     "TYPE newstate_proc *= PROCEDURE (n: RD.DAGNODE);\n"
         "\n"
         "CONST MaxCost = BurgNT.CostArray {\n"
         "%10,\n"
    );
  for (i = 1; i <= ntnumber; i ++) {
    print ("%1MAX (INTEGER)");
    print (i == ntnumber ? "\n" : ",\n");
  }
  print ("};\n");

/****************************************************************/
  N = 0;
  for (p = terms; p!=NULL; p = p->link)
  {
    if (p -> esn > N)
        N = p -> esn;
    emitcase (p, ntnumber,"D.",l);      /* ᡮઠ ������ case   */
  }
/****************************************************************/

#if 1
  print("TYPE NewstatesType = ARRAY BurgNT.OpRange OF newstate_proc;\n");
  print("CONST newstates *= NewstatesType {\n");
  for (i = 0; i <= N; i ++) {
    print (i ? "%1," : "%1 ");
    for (p = terms; p; p = p -> link)
      if (p -> esn == i) {
        print ("newstate_%S\n", p);
        goto next;
      }
    print ("NIL\n");
next:;
  }
  print ("};\n"
         "\n");
//     "END %s.\n", b);
#else
  print("\nVAR newstates* : ARRAY %d OF newstate_proc;\n\nBEGIN\n", N + 1);
  for (p = terms; p; p = p -> link)
    print("%1newstates [%d] := newstate%d;\n", p -> esn, p -> esn);
  print ("END %s.\n", b);
#endif
}

/****************************************************************/
/* emitstring - ᡮઠ ���ᨢ�� �ࠢ�� � �⮨���⥩             */
/****************************************************************/
static void emitstring(Rule rules)      /* ᯨ᮪ �ࠢ��        */
{
  Rule r;
  int k;

  print("CONST %Pcost= {\n");
  for (k = 0, r = rules; r!=NULL; r = r->link)
  {
    for ( ; k < r->ern; k++)            /* ���������� ࠧ�뢮�  */
      print("%10,%1(* %d *)\n", k);
    print("%1%d%s%1(* %d = %R *)\n", r->cost, r->link ? ",":" ", k++, r);
  }
  print("};\n\n");
}

/****************************************************************/
/* emitstruct - ᡮઠ ��।������ �������� state              */
/*              (㧥� �������᪮�� ��ॢ� �������)            */
/****************************************************************/
void emitstruct( Nonterm nts,    /* ᯨ᮪ ���ନ�����  */
                        int ntnumber)   /* �᫮  ���ନ�����  */
{
  Term p;
  print("TYPE\n%1CostArray   *= ARRAY NT OF INTEGER;\n");
  print("%1NTSet       *= PACKEDSET OF NT;\n");
  print("%1Rule        *= INTEGER;\n");
  print("%1RuleArray   *= ARRAY NT OF Rule;\n");
  for (p = terms; p->link != NULL; p = p->link) {}
  print("%1OpRange     *= ir.Operation[ir.o_invalid..ir.%S];\n\n",p);


//        "%1%Pstate_p *= POINTER TO %Pstate;\n"
//        "%1%Pstate   *= RECORD\n"
//        "%3op*:   INTEGER;\n"
//        "%3l*,\n"
//        "%3g*:    %Pstate_p;\n"
//        "%3cost*: cost_array;\n" );
//  if(costvl>1) print("%3auxc*: ARRAY %d OF ARRAY %d OF INTEGER;\n",
//        ntnumber + 1, costvl - 1);
//  print("%3rule*: ARRAY NT OF INTEGER\n%2END;\n\n");

/*
  print("%3rule*: RECORD\n");

  for (;nts!=NULL; nts=nts->link)
  {
      int n=1, m=nts->lhscount;
      while ((m>>=1)>0) n++;
      print("%4%P%S*: INTEGER;\n", nts);
  }
  print("%3END\n%2END;\n\n");
*/
}

/****************************************************************/
/* emitterms - ᡮઠ ������� ������ ��� �ନ�����            */
/****************************************************************/
static void emitterms(Term terms)       /* ᯨ᮪ �ନ�����    */
{
  Term p;                               /* ⥪�騩 �ନ���     */
  int k;

  print("TYPE %Parity_type = ARRAY BurgNT.OpRange OF SHORTINT;\n");
  print("CONST %Parity*= %Parity_type {\n");
  for (k = 0, p = terms; p!=NULL; p = p->link)
  {
    for ( ; k < p->esn; k++)    /* ���������� ࠧ�뢮� ��ﬨ   */
      print("%10,%1(* %d *)\n", k);
      print("%1%d%s%1(* %d=%S *)\n",
            p->arity < 0 ? 0 : p->arity, p->link ? ",":" ", k++, p);
  }
  print("};\n\n");
}

/****************************************************************/
/* emittest - ᡮઠ ��楤�୮�� �ࠣ���� ���  �஢�ન       */
/*            ᮢ������� � ��ࠧ殬                             */
/****************************************************************/
static int emittest(Tree t,            /* 蠡��� ��� �ࠢ����� */
                    int nblanks,
                    int print_blanks,
                    char *v,           /* ᨬ�.��� 㧫�        */
                    char *suffix)      /* 墮�� �������樨    */
{
  Term p = t -> op;                     /* ⥪�騩 㧥� 蠡���� */
  int i;

  if (p -> kind != TERM)
    return 0;
  if (print_blanks)
    for (i = 0; i < nblanks; i ++)
      print (" ");
  print("(%s.op = ir.%S (* %d *)) %s\n",
        v, p, p -> esn, t -> nterms > 1 ? "&" : suffix);
  if (t -> left)
     emittest (t -> left, nblanks, 1, stringf ("%s.l", v),
               t -> right && t -> right -> nterms ? "&" : suffix);
  if (t -> right)
     emittest (t -> right, nblanks, 1, stringf ("%s.r", v), suffix);
  return 1;
}

/****************************************************************/
/*emitxtxt - �뢮� ���譥�� ⥪�� � ।���஢����� ���⮨�����*/
/****************************************************************/
static int emitxtxt (char *s, int nblanks, char names [PVSIZE][PLSIZE])
{
  char *stbp [DIMSTM];          /* �⥪ 㪠��⥫�� ⥫ ����ᮢ */
  register m;                   /* ������ �⥪� ����ᮢ        */
  char * q;
  int i, nlines;

  nlines = m = 0;
  while (* s && (* s == ' ' || * s == '\t' || * s == '\r' || * s == '\n'))
    s ++;
l:
  while (* s) {
    if (* s == '@') {                           /* ���⮨����� @INT  */
      int n = 0;                                /* ����� ��ࠬ���   */
      char * ss = s;
      for (s ++; isdigit (*s); s ++)
        n = n * 10 + (* s - '0');
      if (n >= PVSIZE) {
        error ("�����४�� ����� �����: %s\n", ss);
        goto cl;
      }
      q = & names [n][0];                       /* ⥫� ���ம�।��.*/
      if (* q == 'n' && * (q + 1) == '.') {
        if (* (q + 2) == 'l')
          q += 2;
        else if (* (q + 2) == 'g') {
          print ("r");
          q += 3;
    }
      }
      else if (* q == 'n' && * (q + 1) == 0 &&
           * s == '^' && * (s + 1) == '.' && * (s + 2) == 'p' &&
           ! isalpha (* (s + 3)) && ! isdigit (* (s + 3))) {
      q ++;
      s += 2;
      }
      print("%s", q);
    }
    if (* s == '$') {                           /* ���⮨�����  $    */
      int n = 0;                                /* ����� ���⮨����� */
      char * ss = s;
      for (s ++; isdigit (* s); s ++)
        n = n * 10 + (* s - '0');
      if (n >= STSIZE) {
        error ("�����४�� ����� �����: %s\n", ss);
        goto cl;
      }
      if (m < DIMSTM) {
        stbp [m ++] = s;
        s = pronmac [n];
        if (!s) {
          error ("��������� ����� �����: %d\n", n);
          exit(1);
        }
        goto l;
      }
    }
    if (* s == '%') {                           /* ���⮨�����  %    */
        print(" %P");
        for(++s; isalpha(*s); ++s)
          print("%c", *s);
//        print("_NT");
    }
cl: if (* s == '\r' || * s == '\n') {
      nlines ++;
      print ("\n");
      do {
        s ++;
      } while (* s && (* s == ' ' || * s == '\t' || * s == '\r' || * s == '\n'));
      if (* s || m > 0)
        for (i = 0; i < nblanks; i ++)
          print (" ");
    }
    else
      print ("%c", * s ++);                     /*�� ��㣠� ����*/
  }
  if (m > 0) {
    s = stbp [-- m];
    goto l;
  }
  return nlines;
}
