/* Peg_lib */

#include <stdlib.h>
#include <stdio.h>

#include <alloc.h>
#include <peg.h>
#include <peg_lib.h>
#include <cnog.h>

void peg_dump_context(FILE *f, peg_context_t *cx)/*{{{*/
{
  int i,j;
  int m;

  m = cx->cx_input_length;
  fprintf(f, "Context:\n");
  fprintf(f, "  Input length: %d\n", m);
  fprintf(f, "  Number of productions: %d\n", cx->cx_num_productions);
  fprintf(f, "  Number of alternatives: %d\n", cx->cx_num_alternatives);
  fprintf(f, "  Results:\n");
  for(i = 0; i < cx->cx_num_productions; i ++) {
    fprintf(f, "    Result %d:\n", i);
    for(j = -cx->cx_input_length; j <= 0; j++) {
      fprintf(f, "      %d (%3d) : ", j + m, j);
      switch(cx->cx_results[i][j]) {
        case R_FAIL:
          fprintf(f, "FAIL\n");
          break;
        case R_BUSY:
          fprintf(f, "BUSY\n");
          break;
        case R_UNKNOWN:
          fprintf(f, "UNKNOWN\n");
          break;
        case R_EOF:
          fprintf(f, "EOF\n");
          break;
        default:
          fprintf(f, "%d\n", cx->cx_results[i][j] + m);
          break;
      }
    }
  }
  fprintf(f, "  Alternatives:\n");
  for(i = 0; i < cx->cx_num_alternatives; i ++) {
    fprintf(f, "    Alternative %d:\n", i);
    for(j = -cx->cx_input_length; j <= 0; j++) {
      fprintf(f, "      %d (%3d) : ", j + m, j);
      if(cx->cx_alternatives[i][j] == A_UNDEFINED)
        fprintf(f, "UNDEFINED\n");
      else
        fprintf(f, "%d\n", cx->cx_alternatives[i][j]);
    }
  }
}/*}}}*/
peg_context_t *peg_create_context(alloc_t *alloc, nog_program_t *pg, peg_builder_t *pb, info bi, letter_t *input, int input_length)/*{{{*/
{
  int i;
  peg_context_t *cx;
  choice_t *alternatives;
  result_t *results;
  int num_alternatives;
  int num_productions;

  cx = alloc_malloc(alloc, sizeof(peg_context_t));
  if(!cx) return 0;

  cx->cx_alloc = alloc;

  cx->cx_input = input;
  cx->cx_input_length = input_length;

  num_alternatives = pg->np_num_choices;
  num_productions = pg->np_num_productions;

  cx->cx_num_alternatives = num_alternatives;
  cx->cx_num_productions = num_productions;

  cx->cx_alternatives = alloc_malloc(alloc, sizeof(choice_t *) * num_alternatives);
  if(!cx->cx_alternatives) return 0;
  alternatives = alloc_malloc(alloc, sizeof(choice_t) * (input_length + 1) * num_alternatives);
  if(!alternatives) return 0;
  for(i = 0; i < num_alternatives * (input_length + 1); i ++) {
    alternatives[i] = A_UNDEFINED;
  }
  for(i = 0; i < num_alternatives; i ++) {
    cx->cx_alternatives[i] = alternatives + i * (input_length + 1);
  }

  cx->cx_results = alloc_malloc(alloc, sizeof(result_t *) * num_productions);
  if(!cx->cx_results) return 0;
  results = alloc_malloc(alloc, sizeof(result_t) * (input_length + 1) * num_productions);
  if(!results) return 0;
  for(i = 0; i < num_productions * (input_length + 1); i ++) {
    results[i] = R_UNKNOWN;
  }
  for(i = 0; i < num_productions; i ++) {
    cx->cx_results[i] = results + i * (input_length + 1);
  }

  cx->cx_builder = pb;
  cx->cx_builder_info = bi;

  /* XXX: Give a reasonable upper bound on the stack size */
  cx->cx_stack_size = (input_length + 1) * num_productions;
  cx->cx_stack = alloc_malloc(alloc, sizeof(symbol_t) * cx->cx_stack_size);

  return cx;
}/*}}}*/
void peg_delete_context(peg_context_t *cx)/*{{{*/
{
  if(cx) {
    if(cx->cx_num_alternatives) alloc_free(cx->cx_alloc, (*cx->cx_alternatives));
    alloc_free(cx->cx_alloc, (*cx->cx_results));
    alloc_free(cx->cx_alloc, (cx->cx_alternatives));
    alloc_free(cx->cx_alloc, (cx->cx_results));
    alloc_free(cx->cx_alloc, (cx->cx_stack));
    alloc_free(cx->cx_alloc, (cx));
  }
}/*}}}*/
