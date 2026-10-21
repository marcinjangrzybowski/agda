Release notes for Agda version 2.10.0
=====================================

Highlights
----------

Installation
------------

* Agda supports GHC versions 9.2.8 to 9.14.1.

Pragmas and options
-------------------

* New `ONLY_UNFOLD` and `DONT_UNFOLD` pragmas control ordinary function
  unfolding during conversion while elaborating a function's signature
  and implementation, without changing its transparency at use sites.
  Policies nest by intersection and compose with reflection reduction
  controls. Restricted checking may refine only metas owned by the
  definition; cross-owner obligations are retained for ordinary solving.
  See [the manual](https://agda.readthedocs.io/en/latest/language/pragmas.html#elaboration-unfolding-pragmas)
  for the supported targets and phase boundaries.

Errors
------

Warnings
--------

Syntax
------

Changes to the Agda syntax.

Language
--------

Changes to type checker and other components defining the Agda language.

Builtins
--------

Reflection
----------

* `unquoteDecl` and `unquoteDef` now check that the meta-program
  actually defines all the given identifiers
  (issue [#8851](https://github.com/agda/agda/issues/8851)).
  Previously, an identifier that was not declared by the meta-program
  caused an internal error, and a data type that was only declared
  (via `declareData`) but not defined (via `defineData`)
  was silently accepted (see [#7576](https://github.com/agda/agda/issues/7576)).
  Now both are reported as missing definitions.

Library management
------------------

Interaction and emacs mode
--------------------------

Backends
--------

Issues closed
-------------

For 2.10.0, the following issues were
[closed](https://github.com/agda/agda/issues?q=is%3Aissue+milestone%3A2.10.0+is%3Aclosed)
(see [bug tracker](https://github.com/agda/agda/issues)):

### Consistency issues

### Internal errors

### Other regressions

### Other issues

Pull requests merged for 2.10.0
-------------------------------
