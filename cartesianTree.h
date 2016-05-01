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

//struct node { intT parent; intT value;};

void merge(node* N, uintT left, uintT right) {
  uintT head;
  if (N[left].value > N[right].value) {
    head = left; left = N[left].parent;}
  else {head = right; right= N[right].parent;}
  
  while(1) {
    if (left == 0) {N[head].parent = right; break;}
    if (right == 0) {N[head].parent = left; break;}
    if (N[left].value > N[right].value) {
      N[head].parent = left; left = N[left].parent;}
    else {N[head].parent = right; right = N[right].parent;}
    head = N[head].parent;}}

void cartesianTree(node* Nodes, uintT s, uintT n) { 
  if (n < 2) return;
  if(n == 2) {
    if (Nodes[s].value > Nodes[s+1].value) Nodes[s].parent=s+1;
    else Nodes[s+1].parent=s;
    return;
  }
  if (n > 1000){
    cilk_spawn cartesianTree(Nodes,s,n/2);
    cartesianTree(Nodes,s+n/2,n-n/2);
    cilk_sync;
  } else {
    cartesianTree(Nodes,s,n/2);
    cartesianTree(Nodes,s+n/2,n-n/2);
  }
  merge(Nodes,s+n/2-1,s+n/2);}
