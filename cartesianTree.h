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


#include <sys/syscall.h>
#include <upc.h>


typedef struct node {
  unsigned long firstChar;
  unsigned long parent;
  unsigned long value; 
} node;


// This is equivalent to the former "merge" method except that it takes
// in a pointer to a shared array of nodes, instead of just a list of nodes.
void parallel_merge(shared node* N, unsigned long left, unsigned long right) {
  unsigned long head;
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


// This is where my new code for this algorithm is.
// The point of this is to show that there is an elegant PGAS implementation that
// can make use of iteration instead of thread-level recursion, that can easily
// be extended across multiple compute nodes.
void parallel_cartesian_tree(shared node* Nodes, unsigned long n) {

  int tree_size;
  int middle;

  for (int step = 2; step < n * 2; step *= 2) {
  
    upc_forall(int start = 0; start < n; start += step; &Nodes[start]) {

      // Compute the size of the set of nodes that will be merged
      if (n - start >= step) {
        tree_size = step;
      } else {
        tree_size = n - start;
      }

      // We preserve this special case from the original code
      if (tree_size == 2) {
        if (Nodes[start].value > Nodes[start + 1].value) {
          Nodes[start].parent = start + 1;
        } else {
          Nodes[start + 1].parent = start;
        }
      } else if (tree_size > step / 2) {
        middle = start + (step / 2) - 1;
        parallel_merge(Nodes, middle, middle + 1);
      }

    }

    // We have to make sure to synchronize here.
    // We can't merge on the next level of the tree until we have merged all
    // of the subtrees on the lowest levels.
    upc_barrier;

  }

}

void merge(node* N, unsigned long left, unsigned long right) {
  unsigned long head;
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


void cartesianTree(node* Nodes, unsigned long s, unsigned long n) { 
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
