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

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include "cilk.h"
#include "cartesianTree.h"

// Reused from mergeSuffixArrayToTree
inline unsigned long getRoot(shared node* nodes, unsigned long i) {
  unsigned long root = nodes[i].parent;
  while (root != 0 && nodes[nodes[root].parent].value == nodes[root].value)
    root = nodes[root].parent;
  return root;
}

// UPC Data structures
// Shared structures for holding nodes of the tree
shared node* nodes;
shared unsigned long n;
shared unsigned long nodes_per_thread;

// Adapted from the `cilk_main` code from suffixTreeTest.C.
// Most of this is the same code, but it uses only C instead of C++, and performs
// only construction of the Cartesian tree instead of the full suffix tree from a file.
int main(int argc, char **argv) {

  if (argc < 2) {
    printf("Usage: ./cartesianTree <input filename> <output filename>\n");
  }
  else {

    // Filename arguments
    char* input_filename = (char*)argv[1];
    char* output_filename = (char*)argv[2];

    // For iterating through the nodes in a data file
    FILE *nodes_file;
    unsigned long index;
    unsigned long value;
  
    // Read the nodes into a local list
    printf("Before the split\n");
    if (MYTHREAD == 0) {
      unsigned long num_nodes;
      nodes_file = fopen(input_filename, "r");
      fscanf(nodes_file, "%ld\n", &num_nodes);
      n = num_nodes;  // transfer the node count to the shared variable
      printf("Number of nodes in file %s: %ld\n", input_filename, n);
      nodes_per_thread = (n + THREADS - 1) / THREADS;
    }
    upc_barrier;

    nodes = (shared node*) upc_all_alloc(THREADS, nodes_per_thread * sizeof(node));
    upc_barrier;

    if (MYTHREAD == 0) {
      for (long i = 0; i < n; i++) {
          fscanf(nodes_file, "%ld\t%ld\n", &index, &value);
          nodes[index].value = value;
          nodes[index].parent = 0;  // all nodes start without a parent
      }
      fclose(nodes_file);
      printf("Read nodes from file\n");
    }
    upc_barrier;
    
    // Start a timer.  This code is reused from the gettime.h file
    struct timeval now;
    struct timezone tzp;
    double start_time;
    if (MYTHREAD == 0) {
      gettimeofday(&now, &tzp);
      start_time = ((double) now.tv_sec) + ((double) now.tv_usec)/1000000.;
    }

    // Construct the Cartesian tree
    parallel_cartesian_tree(nodes, n);
    upc_barrier;

    // Update report the time taken to construct the tree
    if (MYTHREAD == 0) {
      gettimeofday(&now, &tzp);
      double end_time = ((double) now.tv_sec) + ((double) now.tv_usec)/1000000.;
      printf("Cartesian tree construction runtime: %lf\n", end_time - start_time);
    }

    // This was used in the original mergeSuffixArrayToTree code to, I expect,
    // essentially coalesce repeated nodes.  We repeat it here so that we can compare
    // our new test output against the previous test output.
    cilk_for(long i = 1; i < n; i++) 
      nodes[i].parent = getRoot(nodes, i);
    printf("Set shortcuts through repeated parents\n");

    // Write the result to file
    FILE *cartesian_tree_file = fopen(output_filename, "w");
    fprintf(cartesian_tree_file, "%ld\n", n);  // the first line is the number of nodes
    for (long i = 0; i < n; i++) {
      fprintf(cartesian_tree_file, "%ld\t%ld\t%ld\t%ld\n", i, nodes[i].value, nodes[i].parent, nodes[nodes[i].parent].value);
    }
    fclose(cartesian_tree_file);
    printf("Output results to file\n");

  }
}
