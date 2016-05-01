// This code is part of the project "A Simple Parallel Cartesian Tree
// Algorithm and its Application to Parallel Suffix Tree
// Construction", ACM Transactions on Parallel Computing, 2014
// (earlier version appears in ALENEX 2011).  
// Copyright (c) 2014 Julian Shun and Guy Blelloch
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights (to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#include <iostream>
#include "gettime.h"
#include "sequence.h"
#include "utils.h"
#include "suffixTree.h"
#include "cartesianTree.h"
#include <sstream>
#include <fstream>
using namespace std;

inline ulong getRoot(node* nodes, ulong i) {
  ulong root = nodes[i].parent;
  while (root != 0 && nodes[nodes[root].parent].value == nodes[root].value)
    root = nodes[root].parent;
  return root;
}

suffixTree suffixArrayToTree (uintT* SA, uintT* LCP, long n, uintT* s){
  startTime();
  long m = 2*n;

  //initialize nodes
  node* nodes = newA(node,m);
  cilk_for(long i=1; i<n; i++){ 
    nodes[2*i].value = LCP[i-1];
    nodes[2*i+1].value = n-SA[i]+1; // length of string including 1 past end
    nodes[2*i].parent = 0;
    nodes[2*i+1].parent = 0;
  }
  nodes[0].value = 0;
  nodes[1].value = n-SA[0]+1;
  nodes[0].parent = nodes[1].parent = 0;
 
  free(LCP); free(SA);
  nextTime("Time to initialize nodes");
  
  cartesianTree(nodes, 1, m-1);
  nextTime("Time for building CT in parallel");

  // shortcut to roots of each cluster
  cilk_for(long i = 1; i < m; i++) 
    nodes[i].parent = getRoot(nodes, i);
  nextTime("Time for shortcuts");

  // insert into hash table  
  suffixTree ST = suffixTree(n, m, nodes, s);
  nextTime("Time for inserting into hash table");

  return ST;
}
