(* Generators for the per-error boilerplate of the Packed_error pattern.
   An error module supplies its type, a printer, and a Factory_product
   describing the packed signature it wants; the functors below produce
   the [pack] / [repack] / [of_list] constructors so each error.ml
   doesn't hand-write them.

   See packed-error for the pattern; a hand-written pack (no factory)
   is fine for a single-constructor error, and the factory earns its
   keep once an error is wrapped, repacked across layers, or aggregated. *)

module type Factory_product = sig
  type t

  module type S

  val make : t -> (module Packed_error.S with type t = t) -> (module S)
end

module type Error_module = sig
  type t

  val pp : Format.formatter -> t -> unit

  module Factory_product : Factory_product with type t = t
end

module Make = struct
  module Base (X : Error_module) = struct
    let of_model (x : X.t) =
      (module struct
        type t = X.t

        let pp fmt = X.pp fmt x
      end : Packed_error.S
        with type t = X.t)
  end

  module With_pack (X : Error_module) = struct
    module B = Base (X)

    let pack (x : X.t) : (module X.Factory_product.S) =
      X.Factory_product.make x (B.of_model x)
  end

  module With_repack (X : Error_module) = struct
    module B = Base (X)

    let repack (type type_constraint_on_incoming_packed_error)
        (constructor_function : (module Packed_error.S) -> X.t)
        (error_to_repack :
          (module Packed_error.S
             with type t = type_constraint_on_incoming_packed_error)) :
        (module X.Factory_product.S) =
      let module E : Packed_error.S = (val error_to_repack : Packed_error.S
                                         with type t =
                                           type_constraint_on_incoming_packed_error)
      in
      let x = constructor_function (module E : Packed_error.S) in
      let base = B.of_model x in
      X.Factory_product.make x base
  end

  module With_of_list (X : Error_module) = struct
    let of_list (es : (module Packed_error.S) list) : (module Packed_error.S) =
      (module struct
        type t = (module X.Factory_product.S)

        let pp fmt =
          match es with
          | [] -> Format.pp_print_string fmt "No errors"
          | _ ->
              let pp_one fmt (module E : Packed_error.S) = E.pp fmt in
              Format.fprintf fmt "@[<v>%a@]"
                (Format.pp_print_list
                   ~pp_sep:(fun fmt () -> Format.fprintf fmt "@,")
                   pp_one)
                es
      end : Packed_error.S)
  end
end

let of_string s : (module Packed_error.S with type t = string) =
  (module struct
    type t = string

    let pp fmt = Format.pp_print_string fmt s
  end : Packed_error.S
    with type t = string)
