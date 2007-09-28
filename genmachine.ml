(* Genmachine *)

open Util.Syntax;;
open Pffpsf;;

type arg =
| Int
| Attribute
| Node
| Char
| Label
| Labels
;;

type kind =
| Labelable
| Multi_labelable
| Unlabelable

let arg_of_char = function
| 'i' -> Int
| 'a' -> Attribute
| 'n' -> Node
| 'c' -> Char
| 'l' -> Label
| c -> invalid_arg (sf "Unknown attribute %C" c)
;;

let load_opcodes =
  let rex1 = Str.regexp "^.*%opcode{\\([ULM]\\)\\([0-9]+\\)\\([a-z]*\\)}.*| *\\([A-Z_]+\\) .*$" in
  fun fn ->
  pf "Loading opcodes from %s\n" fn;
  let result = ref [] in
  Util.with_file_input fn (fun ic -> Util.iter_over_lines ic (fun u ->
    if Str.string_match rex1 u 0 then
      begin
        let f i = Str.matched_group i u in
        let kind =
          match f 1 with
          | "L" -> Labelable
          | "M" -> Multi_labelable
          | "U" -> Unlabelable
          | k  -> failwith (sf "Unknown kind %S" k)
        in
        let opcode = int_of_string & f 2
        and flags = f 3
        and name = f 4
        in
        let m = String.length flags in
        let flags' = Array.init m (fun i -> arg_of_char flags.[i]) in
        result += (kind, name, opcode, flags')
        (*Printf.printf ">> 0x%02x %S %S\n" opcode flags name*)
      end
  ));
  !result
;;

let gen_c_unpacker ops fn =
  pf "Generating C unpacker to %s\n" fn;
  Util.with_file_output (fn^".h") (fun och ->
    Util.with_file_output (fn^".c") (fun occ ->
      fp och "/* cnog_unpack.h\n";
      fp och " *\n";
      fp och " * Generated by genmachine.ml, do not edit.\n";
      fp och " *\n";
      fp och " */\n";
      fp och "\n";
      fp och "#ifndef CNOG_UNPACK_H\n";
      fp och "#define CNOG_UNPACK_H\n";
      fp och "\n";
      fp och "#include <pack.h>\n";
      fp och "#include <cnog.h>\n";
      fp och "\n";
      fp och "bool cnog_unpack_instruction(packer_t *pk, nog_instruction_t *ins);\n";
      fp och "\n";
      fp och "#endif\n";


      fp occ "/* cnog_unpack.c\n";
      fp occ " *\n";
      fp occ " * Generated by genmachine.ml, do not edit.\n";
      fp occ " *\n";
      fp occ " */\n";
      fp occ "\n";
      fp occ "#include <stdlib.h>\n";
      fp occ "#include <cnog_unpack.h>\n";
      fp occ "\n";
      fp occ "bool cnog_unpack_instruction(packer_t *pk, nog_instruction_t *ins)\n";
      fp occ "{\n";
      fp occ "  int opcode;\n";
      fp occ "  u64 arg;\n";
      fp occ "  size_t length;\n";
      fp occ "  u8 *string;\n";
      fp occ "\n";
      fp occ "  if(!pack_read_int(pk, &opcode)) return false;\n";
      fp occ "  switch(opcode) {\n";

      List.iter
        begin fun (kind, name, opcode, args) ->
          fp occ "    case 0x%02x: /* %s */\n" opcode name;

          fp occ "      ins->ni_opcode = NOG_%s;\n" name;

          let args = Array.to_list args in

          let args = match kind with
            | Labelable -> Label :: args
            | Unlabelable -> args
            | Multi_labelable -> Labels :: args
          in

          let args = Array.of_list args in

          Array.iteri
            begin fun i x ->
              match x with
              | Labels ->
                  fp occ "      if(!pack_read_uint64(pk, &arg)) return false;\n";
                  fp occ "      ins->ni_arg[%d].na_table.nt_length = arg;\n" i;
                  fp occ "      ins->ni_arg[%d].na_table.nt_elements = pk->p_malloc(sizeof(int) * arg);\n" i;
                  fp occ "      if(!ins->ni_arg[%d].na_table.nt_elements) return false;\n" i;
                  fp occ "      {\n";
                  fp occ "        int i, m;\n";
                  fp occ "        \n";
                  fp occ "        m = arg;\n";
                  fp occ "        for(i = 0; i < m; i ++) {\n";
                  fp occ "          if(!pack_read_int(pk, ins->ni_arg[%d].na_table.nt_elements + i)) return false;\n" i;
                  fp occ "        }\n";
                  fp occ "      }\n"
              | Int|Char|Label ->
                  fp occ "      if(!pack_read_uint64(pk, &arg)) return false;\n";
                  fp occ "      ins->ni_arg[%d].na_int = arg;\n" i
              | Node|Attribute ->
                  fp occ "      if(!pack_read_string(pk, &string, &length)) return false;\n";
                  fp occ "      ins->ni_arg[%d].na_string.ns_chars = (char *) string;\n" i;
                  fp occ "      ins->ni_arg[%d].na_string.ns_length = length;\n" i
            end
            args;

          fp occ "      break;\n";
        end
        ops;

      fp occ "    default:\n";
      fp occ "      abort(); /* Unknown opcode */\n";
      fp occ "  }\n";
      fp occ "  return true;\n";
      fp occ "}\n";
  ))
;;

let gen_ocaml_packer ops fn =
  pf "Generating Ocaml packer to %s\n" fn;
  let string_of_arg i = sf "a%d" i in
  Util.with_file_output fn (fun oc ->
    fp oc "(* %s *)\n" fn;
    fp oc "(* Auto-generated; do not edit. *)\n";
    fp oc "\n";
    fp oc "open Machine;;\n";
    fp oc "\n";
    fp oc "let pack_instruction ~resolve pk = function\n";
    List.iter
      begin fun (kind, name, opcode, args) ->
        let arg_offset =
          match kind with
          | Labelable ->
              fp oc "  | L(a0, %s" name;
              1
          | Unlabelable ->
              fp oc "  | U(%s" name;
              0
          | Multi_labelable ->
              fp oc "  | M(a0, %s" name;
              1
        in
        let args = Array.to_list args in
        begin match args with
          | [] -> fp oc ")"
          | _ ->
              let i = ref arg_offset in
              fp oc "(%s))" (String.concat ", " (List.map (fun _ -> incr i; string_of_arg (!i - 1)) args))
        end;
        fp oc " ->\n";
        fp oc "      Pack.write_uint pk 0x%02x;\n" opcode;
        begin
          match kind with
          | Labelable ->
              fp oc "      Pack.write_uint pk (resolve %s);\n" (string_of_arg 0)
          | Unlabelable -> ()
          | Multi_labelable ->
              fp oc "      Pack.write_uint pk (Array.length %s);\n" (string_of_arg 0);
              fp oc "      Array.iter (fun x -> Pack.write_uint pk (resolve x)) %s;\n" (string_of_arg 0)
        end;
        let i = ref (arg_offset - 1) in
        List.iter
          begin fun x ->
            incr i;
            match x with
            | Labels ->
                fp oc "      Pack.write_uint pk (Array.length %s);\n" (string_of_arg !i);
                fp oc "      Array.iter (fun x -> Pack.write_uint pk (resolve x)) %s);\n" (string_of_arg !i)
            | Int ->            fp oc "      Pack.write_uint pk %s;\n" (string_of_arg !i)
            | Char ->           fp oc "      Pack.write_uint pk (Char.code %s);\n" (string_of_arg !i)
            | Node|Attribute -> fp oc "      Pack.write_string pk %s;\n" (string_of_arg !i)
            | Label ->          fp oc "      Pack.write_uint pk (resolve %s);\n" (string_of_arg !i)
          end
          args;
        fp oc "      ()\n"
      end
      ops;
    (*fp oc "  | _ -> ()\n";*)
    fp oc ";;\n")
;;

let _ =
  List.iter Unix_util.mkdirhier ["nog"; "backends"; "cnog"];
  let ops = load_opcodes "nog/machine.ml" in
  gen_ocaml_packer ops "backends/nog_packer.ml";
  gen_c_unpacker ops "cnog/cnog_unpack"
;;