MODULE TestMemoryUsage;
<* +main *>
<* heaplimit="0" *>

(* ------------------------------------------------ ------------------------ 
 * (C) 2011 by Alexander Iljin 
 * ----------------- -------------------------------------------------- ----- *) 

IMPORT oberonRTS, Out; 

TYPE 
   Chain = POINTER TO ChainDesc; 
   ChainDesc = RECORD 
      (* data size is 1 MByte minus pointer variable size *) 
      data: ARRAY 1024 * 1024 DIV SIZE (LONGINT) - 1 OF LONGINT; 
      next: Chain; 
END;

PROCEDURE CheckMaxHeapSize();
VAR 
   root, new:Chain;
   i:INTEGER;
BEGIN 
   root :=NIL;
   new := NIL;
   NEW (root); 
   root.next := NIL;
   i := 1;
   Out.Int (i, 0); 
   Out.Char (''); 
   LOOP 
      NEW (new); 
      new.next := root;
      root := new;
      INC (i);
      Out.Int (i, 0); 
      Out.Char (''); 
   END 
END CheckMaxHeapSize; 

PROCEDURE CheckCollector();
(* The newly allocated blocks are not rooted in any global variable. The local 
 * variable 'root' references only one block at a time, and oberonRTS.Collect 
 * is called after every allocation, but still the heap is exhausted very 
 * quickly ( the numbers go to 1205 instead of 1066). This demonstrates a bug 
 * in XDS memory management. *) 
VAR 
   root: Chain; 
   i: INTEGER; 
BEGIN 
   root:= NIL;
   NEW (root); 
   root.next  := NIL;
   i := 1;
   Out.Int (i, 0); 
   Out.Char (''); 
   LOOP
      NEW (root.next); 
      root:= root.next; (* Note: the previous value of 'root' is lost, therefore can be garbage-collected. *)
      INC (i); 
      Out.Int (i, 0); 
      Out.Char (''); 
      oberonRTS.Collect; 
   END 
END CheckCollector; 

BEGIN 

   ASSERT (SIZE (ChainDesc) = 1024 * 1024, 20); 
   Out.Open; 
   CheckMaxHeapSize;
   (* CheckCollector; *)
 
END TestMemoryUsage.