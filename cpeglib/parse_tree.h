/* parse_tree.h
 *
 */

#ifndef PARSE_TREE_H
#define PARSE_TREE_H

#include <stdio.h>
#include <base_types.h>

typedef enum {
  TREE_NODE,
  TREE_TOKEN,
} tree_kind;

typedef char *string;

struct _tree;

typedef struct {
  int s_begin;
  int s_end;
} substring;

struct _attribute;

typedef struct _attribute {
  struct _attribute *a_sibling;
  string a_name;
  substring a_value;
} attribute;

typedef struct {
  string n_name;
  attribute *n_attributes;
  struct _tree *n_children;
} node;

typedef substring token;

typedef struct _tree {
  tree_kind t_kind;
  struct _tree *t_sibling;
  union {
    node t_node;
    token t_token;
  } t_element;
} tree;

typedef struct _info {
  char tpi_nothing;
} info;

#define BUILDER_TYPES_DEFINED 1

#include <peg.h>

tree *ptree_token(info *pti, int t_begin, int t_end);
tree *ptree_create_node(info *pti, char *name);
void ptree_delete_attribute(info *pti, attribute *at);
void ptree_delete_tree(info *pti, tree *tr);
void ptree_attach_attribute(info *pti, node *nd, char *name, int v_begin, int v_end);
void ptree_add_children(info *pti, node *nd, tree *tr);
void ptree_reverse_sibling(info *pti, node *nd);
void ptree_reverse_tree(info *pti, tree *tr);
void ptree_dump_tree(info *pti, FILE *f, char *input, tree *tr, int indent);
void ptree_dump_context(info *pti, FILE *f, peg_context_t *cx);

#endif