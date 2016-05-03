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
inline unsigned long getRoot(shared node* nodes, unsigned long i, unsigned long *index) {
  unsigned long root = nodes[index[i]].parent;
  while (root != 0 && nodes[index[nodes[index[root]].parent]].value == nodes[index[root]].value)
    root = nodes[index[root]].parent;
  return root;
}

// UPC Data structures
// Shared structures for holding nodes of the tree
shared node* nodes;
shared unsigned long n;
shared unsigned long elements_per_thread;

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
    unsigned long element_index;
    unsigned long value;
 
    // It's not possible (I believe) to dynamically allocate a shared array with UPC and then
    // access its elements in blocks on each thread, by default.  Sources:
    // * https://hpcrdm.lbl.gov/pipermail/upc-users/2011-December/000654.html 
    // * http://upc.lbl.gov/hypermail/upc-users/0067.html
    // * https://hermes.gwu.edu/cgi-bin/wa?A3=ind0510&L=UPC-HELP&E=0&P=505&B=--&T=TEXT%2FPLAIN;%20charset=US-ASCII&header=1
    // Because we want to look up elements by block to preserve locality of access and the
    // elegance of the problem's memory layout for PGAS, we make a (private!) array on each
    // machine that will provide fast lookup of a block-based index from its original cyclic index.
    unsigned long *index;

    // Read the nodes into a local list
    if (MYTHREAD == 0) {
      unsigned long element_count;
      nodes_file = fopen(input_filename, "r");
      fscanf(nodes_file, "%ld\n", &element_count);
      n = element_count;  // transfer the node count to the shared variable
      elements_per_thread = (n + THREADS - 1) / THREADS;
      printf("Number of nodes in file %s: %ld\n", input_filename, n);
    }
    upc_barrier;

    printf("Nodes per thread: %ld\n", elements_per_thread);
    nodes = (shared node*) upc_all_alloc(THREADS, elements_per_thread * sizeof(node));
    upc_barrier;

    // Create lookup from the typical cyclic indexing to block-based indexes. 
    unsigned long thread, phase;
    index = (unsigned long*) malloc(n * sizeof(unsigned long));
    for (int i = 0; i < n; i++) {
        thread = i / elements_per_thread;
        phase = i % elements_per_thread;
        index[i] = thread + phase * THREADS;
    }
    upc_barrier;

    // Now that we have our block index into the array, load in the data
    if (MYTHREAD == 0) {
      for (long i = 0; i < n; i++) {
          fscanf(nodes_file, "%ld\t%ld\n", &element_index, &value);
          nodes[index[element_index]].value = value;
          nodes[index[element_index]].parent = 0;  // all nodes start without a parent
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
    parallel_cartesian_tree(nodes, n, index);
    printf("Exited the Cartesian tree function\n");
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
      nodes[index[i]].parent = getRoot(nodes, i, index);
    printf("Set shortcuts through repeated parents\n");

    // Write the result to file
    FILE *cartesian_tree_file = fopen(output_filename, "w");
    fprintf(cartesian_tree_file, "%ld\n", n);  // the first line is the number of nodes
    for (long i = 0; i < n; i++) {
      fprintf(cartesian_tree_file,
        "%ld\t%ld\t%ld\t%ld\n",
        i,
        nodes[index[i]].value,
        nodes[index[i]].parent,
        nodes[index[nodes[index[i]].parent]].value
      );
    }
    fclose(cartesian_tree_file);
    printf("Output results to file\n");

  }
}
