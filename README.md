Extended Xorshift Pseudo-Random Number Generators
=================================================

Xorshift uniform random number generators were introduced by George Marsaglia
in 2003, as a means of providing fast and lightweight pseudo-random number
generation with high statistical quality.

Marsaglia's own xorshift generators are already implemented in the standard
library of the D programming language.  The `dxorshift` package provides
instead implementations of some of the extended family of generators that
other researchers have developed from Marsaglia's essential ideas.

Generators in the package are implemented as input ranges with the postblit
and default constructors disabled.  This should help to avoid accidental
statistical correlations caused by unintended copy-by-value of generator
state, and ensure that generators cannot be initialized unseeded.
