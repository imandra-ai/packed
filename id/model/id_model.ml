(* Capability signatures for entity ids carried as first-class modules.
   A per-entity id type is an (often recursive) module type composed
   from these -- e.g.

     module rec R : sig
       module type S = sig
         include Id_model.Base.S
         include Id_model.With_to_string.S
         include Id_model.With_pp.S
         include Id_model.With_equal with module type SELF := R.S
       end
     end = R

     module type S = R.S

   which makes each entity's id abstract and distinct: passing a user id
   where a group id is expected is a compile error, even though both are
   uuids underneath. Factories that mint values of such a type live in
   Id_factory_factory (packed-id.factory). *)

module Base = struct
  module type S = sig
    type t

    val x : t
  end
end

module With_to_string = struct
  module type S = sig
    val to_string : unit -> string
  end
end

module With_pp = struct
  module type S = sig
    val pp : Format.formatter -> unit
  end
end

module With_gen = struct
  module type S = sig
    type t

    val v : unit -> t
  end
end

module With_nil = struct
  module type S = sig
    type t

    val nil : unit -> t
  end
end

(* Included with [with module type SELF := ...] (OCaml >= 4.13) so
   [equal] compares against the entity's own id type, not a foreign
   one. *)
module type With_equal = sig
  module type SELF

  val equal : (module SELF) -> bool
end
