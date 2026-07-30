(lang dune 3.8)

(name packed)

(generate_opam_files true)

(source
 (github imandra-ai/packed))

(license MIT)

(authors "Sebastian Provenzano <sebastian@imandra.ai>")

(maintainers
 "Sebastian Provenzano <sebastian@imandra.ai>"
 "Imandra <tech@imandra.ai>")

; The three packages release in lockstep (one tag, one dune-release
; invocation, same version number), containers/containers-data style.
; They are separate packages because their dependency footprints
; differ: packed-error must stay dependency-free.

(package
 (name packed-error)
 (synopsis "Errors as first-class modules that carry their own printer")
 (description
  "Small module-type vocabulary for passing errors around as first-class modules: an error value packed together with its pretty-printer, so layers above can display or wrap it without depending on the type underneath. Extracted from imandra-web.")
 (depends
  dune
  (ocaml
   (>= 4.08))))

(package
 (name packed-caqti)
 (synopsis "Db-connection capability and transaction plumbing for Caqti")
 (description
  "A first-class-module seam between repository code and Caqti: a Db_connection capability that is either a pool or an open transaction, uniform apply/with_tx over both, a unit-of-work with an unforgeable in-transaction witness, and a COALESCE-friendly update combinator. Extracted from imandra-web.")
 (depends
  dune
  (ocaml
   (>= 4.08))
  (caqti
   (>= 2.0))
  (caqti-lwt
   (>= 2.0))
  lwt
  (packed-error
   (= :version))))

(package
 (name packed-id)
 (synopsis "Typed entity ids as first-class modules")
 (description
  "Capability signatures for entity ids (Id_model) and a factory-factory (Id_factory_factory) that builds per-entity id factories over any string-representable backend, plus a Caqti bridge for storing such ids in text columns. Ids become abstract per entity, so mixing a user id into a group query is a compile error. Extracted from imandra-web.")
 (depends
  dune
  (ocaml
   (>= 4.08))
  caqti))
