(* An error as a first-class module: the value packed together with its
   printer. [pp] takes only a formatter -- the error it prints is the one
   packed inside -- so a caller can display, log or wrap an error without
   knowing (or depending on) the type underneath.

   [S] is deliberately minimal. The optional capabilities below follow the
   same pattern as any other capability signature: include them alongside
   [S] when a layer needs to recover the value ([With_value]) or downcast
   back to a bare packed error ([With_forget]). *)

module type S = sig
  type t

  val pp : Format.formatter -> unit
end

module With_value = struct
  module type S = sig
    type t

    val e : t
    val pp : Format.formatter -> unit
  end
end

module With_forget = struct
  module type S = sig
    type t

    val forget : unit -> (module S)
  end
end
