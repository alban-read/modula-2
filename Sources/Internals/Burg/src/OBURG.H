/****************************************************************/
/* <oburg.h> 1 ������ 94    ��᫥���� ���������  17 䥢ࠫ� 95 */
/*    ��।������ ����⠭�, ����७��� ⨯��, �������� �        */
/*  ᯥ�䨪�権 ��� ᮡ�⢥���� ��楤�� �������� BurBeG    */
/****************************************************************/
#ifndef BURG_INCLUDED
#define BURG_INCLUDED
#define PVSIZE 8                /* �⠭�. ࠧ��� ����� ��ࠬ. */
#define PLSIZE 64               /* ����. ����� ����� ��ࠬ���  */
#define STSIZE 128              /* ࠧ��� ⠡���� ����ᮢ      */
#define BFSIZE 128              /* ࠧ��� ⥪�⮢�� ���஢     */
#define HASHSIZE 211            /* ࠧ��� ��-⠡����           */
#define DIMSTM 8                /* ��㡨�� ���������� ����ᮢ */
/****************************************************************/
/*    ����७��� �।�⠢����� ����⮢ �室��� �ࠬ��⨪�:    */
/****************************************************************/
typedef enum
  { TERM=1, NONTERM } Kind;     /* �ਧ��� �ନ���|���ନ���  */
                                /* � ���ਯ�� ᨬ����        */

typedef struct rule *Rule;  /* 㪠��⥫� �� ����.�ࠢ���   */
typedef struct term *Term;  /* 㪠��⥫� �� ����.�ନ���� */
typedef struct nonterm *Nonterm;/* ����. �� ����. ���ନ�.*/
typedef struct tree *Tree;  /* 㪠��⥫� �� ����.��ॢ�    */
                                /* (� ��⠢� 蠡���� �ࠢ���)  */

struct term                     /* ���ਯ�� �ନ����         */
{
        char *name;             /* ��� �ନ����                */
        Kind kind;              /* �ਧ��� "�ନ���쭮��"=TERM*/
        int esn;                /* ���譨� ����� (���) ᨬ����  */
        int arity;              /* �୮��� ��� ������        */
        Term link;              /* ᫥���騩 ��. � ���浪� esn*/
        Rule rules;             /* ᯨ᮪ �ࠢ��, �� 蠡����   */
                                /* ��稭����� ����� �ନ����� */
};

struct nonterm                  /* ���ਯ�� ���ନ����       */
{
        char *name;             /* ��� �ନ����                */
        Kind kind;              /* ��."���ନ���쭮��"=NONTERM*/
        int number;             /* �����-�����䨪���          */
        int lhscount;           /* �᫮ �ࠢ��, �� 蠡����    */
                                /* ��稭����� �⨬ ���ନ����� */
        int reached;            /* �ਧ��� ���⨦����� �� start*/
        Rule rules;             /* ᯨ᮪ ⠪�� �ࠢ��          */
        Rule chain;             /* �.楯��� �ࠢ��, �� 蠡����*/
                                /* ��稭����� �⨬ ���ନ����� */
        Nonterm link;           /* ������騩 ���ନ��� �       */
                                /* ���浪� �����⠭�� ����஢  */
};

struct tree                     /* ���ਯ�� ��ॢ� � ��⠢�  */
{                               /* 蠡���� �ࠢ���              */
        void *op;               /* ��७� (����.��./����.) */
        Tree left, right;       /* ��⢨  ����                 */
        int nterms;             /* �᫮ �ନ����� � ��ॢ�    */
        int par;                /* ����� �ਯ�ᠭ���� ��ࠬ��� */
};

struct rule                     /* ���ਯ�� �ࠢ��� ᢥ�⪨   */
{
        Nonterm lhs;            /* १������騩 ���ନ���    */
                                /* ("����� ����" �ࠢ���)      */
        Tree pattern;           /* 蠡��� ������� �ࠢ���       */
                                /* ("�ࠢ�� ����" �ࠢ���)     */
        int ern;                /* ���譨� ����� �ࠢ���        */
        int packed;             /* ���������� ���譨� �����    */
        int cost;               /* �᭮���� �⮨�����           */
        int *auxc;              /* �������⥫�� �⮨����     */
        Rule link;              /* ������饥 �ࠢ��� � ���浪�  */
                                /* �����⠭�� ern ����஢      */
        Rule next;              /* ������饥 �ࠢ��� � ⥬ ��   */
                                /* ��୥� 蠡����               */
        Rule chain;             /* ������饥 楯��� �ࠢ��� �   */
                                /* ����� ����� ������� �ࠢ��� */
                                /* � ����⢥ ᢮�� �ࠢ�� ���*/
        Rule decode;            /* ������饥 �ࠢ��� � ⥬ ��   */
                                /* १������騬 ���ନ�����  */
        Rule kids;              /* ������饥 �ࠢ��� � ⥬ ��   */
                                /* 蠡����� ���ନ�����-��⥩  */
        char *cond;             /* ���譨� ⥪�� ���.�᫮���    */
        char *dyncost;          /* ���譨� ⥪�� ���.�⮨����  */
};
extern int ntnumber;            /* ��饥 �᫮ ���ନ�����     */
extern Nonterm start;           /* ��砫�� ���ନ���         */
extern Term terms;              /* ᯨ᮪ �ନ�����            */
extern Nonterm nts;             /* ᯨ᮪ ���ନ�����          */
extern Rule rules;              /* ᯨ᮪ �ࠢ��                */
extern int nrules;              /* ��饥 �᫮ �ࠢ��           */
extern char *pronmac[STSIZE];   /* ���ம�।������         */
extern int costvl;              /* ����� ����� �⮨���⥩     */
extern int *auxtype;            /* ⨯� �㭪権 ���.�⮨���⥩  */
                                /*   (��।����� � oemit.c)     */
/****************************************************************/
/*                  ��樨 � ����-�뢮�                          */
/****************************************************************/
extern int                      /*      ��樨 ��������:       */
     Iflag,                     /* 1=ᡮઠ �⫠��筮� ���ᨨ   */
     Tflag,                     /* 1=ᡮઠ �������饩 ���ᨨ */
     Cflag;                     /* 1=ᡮઠ ���ᨨ �� �몥 ��  */
extern char *prefix;            /* ��騩 ��䨪� ��室��� ����  */
extern int errcnt;              /* �᫮ ������� �訡��      */
extern char inbuf[BFSIZE];      /* ���� �室���� ⥪��        */
extern char *bp;                /* 㪠��⥫� �� ��砫� ���ᥬ�  */
                                /*   (��।�����  � oburg.c)    */
/****************************************************************/
/*                      �����᪨� ������                      */
/****************************************************************/
/*   ���� �����᪨� ⨯�� (��אַ ᮮ⭮����� � burgdf.q):     */

#define NTERM 267     /* ���祢�� ᫮�� "exrtaNT"             */
#define TERM 257        /* ���祢�� ᫮�� "term"                */
#define START 258       /* ���祢�� ᫮�� "start"               */
#define PPERCENT 259    /* ���ᥬ� %%                           */
#define ID 260          /* �����䨪���                        */
#define INT 261         /* 楫�� �᫮                          */
#define INCLUDE 262     /* ������ ����祭�� ⥪�             */
#define MACRO 263       /* ��८�।������ ᢮�.���⮨�����     */
#define COST 264        /* ��।������ ����� ����� �⮨����  */
#define SPEC 265        /* ��।������ ᯥ�.�㭪樨 �⮨����   */
#define EMPTY 266       /* ��।������ ���.�㭪樨 �⮨����    */
/****************************************************************/
/*     ����䨪�樨 ᮡ�⢥���� ��楤�� �஥�� BurBeG:        */
/****************************************************************/
/*  �������� ����� oburg.c (�࣠������ ��饣� ��⮪� ������): */
void main(int argc, char *argv[]);
int  get(void);
void include();
void error(char *fmt, ...);
void warn(char *fmt, ...);
void *alloc(int nbytes);
char *stringf(char *fmt, ...);
void print(char *fmt, ...);
/****************************************************************/
/* oparse.c (ࠧ��� �室���� ⥪�� � ������� ��.�।�⠢�.): */
/****************************************************************/
int parse(void);
int lex(void);                                          /*static*/
int qikpas(int swt,int *sts, int *stl,
           int *pat);                                   /*static*/
char *xtext();                                          /*static*/
Tree treeparse(int p);                                  /*static*/
unsigned hash(char *str);                               /*static*/
void *lookup(char *name);                               /*static*/
void *install(char *name);                              /*static*/
Nonterm nonterm(char *id);                              /*static*/
Nonterm addnonterm(char *id);                           /*static*/
Term term(char *id, int esn);                           /*static*/
Tree tree(char *op, Tree left, Tree right, int par);    /*static*/
Rule rule(char *id, Tree pattern, int ern, int cost,    /*static*/
          char *c, char *d, int *auxc);
/****************************************************************/
/*        M���� oemit.c (ᡮઠ ��室���� ⥪��):             */
/****************************************************************/
//int emit();
int emitimodule();
void emitdmodule(char* b, int l);
void emitnmodule(char* b, int l);

void emitactrule();
void emitactions();
void emitstate(Term terms, Nonterm start, int ntnumber,
               char *b, char *i);
void emitclosure(Nonterm nts,char *b, int l, char *i);
void emitcase1(Term p, int ntnumber, char *b, int l, char *bb);

void emitactpar(Tree t,char *v,
                       char names[PVSIZE][PLSIZE]);     /*static*/
void reach(Tree t);                                     /*static*/
void ckreach(Nonterm p);                                /*static*/
void emitaux(Rule r, char *b);                          /*static*/
void emitcase(Term p, int ntnumber, char *b, int l);    /*static*/
void emitcond(char *s, int n, char names[PVSIZE][PLSIZE]); /*static*/
void emitcost(Tree t, char *v, char *b);                /*static*/
void emitcost1(Tree t, char *v, int n, char *b);        /*static*/
void emitcost2(Tree t, char *v, int n, int *m, char *b);/*static*/
void emitdefsd(Nonterm nts, int ntnumber);               /*static*/
void emitdefsi(Nonterm nts, int ntnumber);               /*static*/
void emitfuncs(void);                                   /*static*/
void emitheader(void);                                  /*static*/
char *computekids(Tree t, char *v, char *bp, int *ip);  /*static*/
void emitkids(Rule rules, int nrules);                  /*static*/
void emitlabel(Nonterm start);                          /*static*/
void closure(int cost[], Rule rule[], Nonterm p, int c);/*static*/
void emitleaf(Term p, int ntnumber, char *b);           /*static*/
static char *computents(Tree t, char *bp, int *k);      /*static*/
void emitnts(Rule rules, int nrules);                   /*static*/
void emitrecord(char *pre, Rule r, char *b,int l,int f,
                char names[PVSIZE][PLSIZE]);            /*static*/
void emitrule0(Nonterm nts);                            /*static*/
void emitrule(Nonterm nts);                             /*static*/
void emitstring(Rule rules);                            /*static*/
void emitstruct(Nonterm nts, int ntnumber);             /*static*/
void emitterms(Term terms);                             /*static*/
int  emittest(Tree t, int nb, int pb, char * v, char *suffix); /*static*/
int  emitxtxt(char *s, int nb, char names[PVSIZE][PLSIZE]);    /*static*/

#endif
