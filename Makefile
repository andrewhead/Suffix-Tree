# // This code is part of the project "A Simple Parallel Cartesian Tree
# // Algorithm and its Application to Parallel Suffix Tree
# // Construction", ACM Transactions on Parallel Computing, 2014
# // (earlier version appears in ALENEX 2011).  
# // Copyright (c) 2014 Julian Shun and Guy Blelloch
# //
# // Permission is hereby granted, free of charge, to any person obtaining a
# // copy of this software and associated documentation files (the
# // "Software"), to deal in the Software without restriction, including
# // without limitation the rights (to use, copy, modify, merge, publish,
# // distribute, sublicense, and/or sell copies of the Software, and to
# // permit persons to whom the Software is furnished to do so, subject to
# // the following conditions:
# //
# // The above copyright notice and this permission notice shall be included
# // in all copies or substantial portions of the Software.
# //
# // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# // OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# // MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# // NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# // LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# // OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# // WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

ifdef LONG
INTT = -DLONG
endif

CC = g++
LFLAGS =
CFLAGS = -O2 $(INTT)

ifdef OPENMP
PCC = g++
PCFLAGS = -fopenmp -O2 -DOPENMP $(INTT)
PLFLAGS = -fopenmp

else ifdef GCILK
PCC = g++
PCFLAGS = -lcilkrts -fcilkplus -O2 -DCILKP $(INTT)
PLFLAGS = -lcilkrts -fcilkplus

else ifdef CILK
PCC = cilk++
PCFLAGS = -O2 -DCILK -Wno-cilk-for $(INTT)
PLFLAGS =

else ifdef IPPROOT
PCC = icpc
PCFLAGS = -O2 -DCILKP $(INTT)
PLFLAGS =
CC = icpc
LFLAGS =
CFLAGS = -O2

else 
PCC = $(CC)
PLFLAGS = $(LFLAGS)
PCFLAGS = $(CFLAGS)
endif


BASIC = cilk.h utils.h
SEQUENCE = sequence.h $(BASIC) seq.h
INTSORT = blockRadixSort.h transpose.h
STRINGGEN = $(ITEMGEN) stringGen.h
ALL= suffixArray suffixTree

all : $(ALL)

suffixArrayTest.o: suffixArrayTest.C $(STRINGGEN) $(SEQUENCE)
	$(PCC) $(PCFLAGS) -c suffixArrayTest.C

mergeSuffixArrayToTree.o: mergeSuffixArrayToTree.C suffixTree.h cartesianTree.h $(SEQUENCE) $(INTSORT) hash.h 
	$(PCC) $(PCFLAGS) -c mergeSuffixArrayToTree.C

suffixTreeTest.o: suffixTreeTest.C $(STRINGGEN) $(SEQUENCE) hash.h suffixTree.h 
	$(PCC) $(PCFLAGS) -c suffixTreeTest.C

suffixTree:  mergeSuffixArrayToTree.o suffixArray.o suffixTreeTest.o
	$(PCC) $(PLFLAGS) -o $@ mergeSuffixArrayToTree.o suffixArray.o suffixTreeTest.o 

suffixArray.o: rangeMin.h suffixArray.C merge.h $(INTSORT) $(SEQUENCE)
	$(PCC) $(PCFLAGS) -c suffixArray.C

suffixArray : suffixArrayTest.o suffixArray.o
	$(PCC) $(PLFLAGS) -o $@ suffixArrayTest.o suffixArray.o 

clean :
	rm -f *.o $(ALL)
