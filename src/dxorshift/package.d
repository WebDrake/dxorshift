/**
 * Xorshift uniform random number generators were introduced by George
 * Marsaglia in 2003, as a means of providing fast and lightweight
 * pseudo-random number generation with high statistical quality.
 *
 * This package complements the existing xorshift generators in phobos'
 * `std.random` with implementations of some of the  extended family of
 * generators that other researchers have developed from Marsaglia's
 * essential ideas.  Typically these address statistical flaws found
 * with the original xorshift designs.
 *
 * Generators in the package are implemented as input ranges with the
 * postblit and default constructors disabled.  This should help to
 * avoid accidental statistical correlations caused by unintended
 * copy-by-value of generator state, and ensure that generators cannot
 * be initialized unseeded.
 *
 * Authors:
 *     $(LINK2 http://braingam.es/, Joseph Rushton Wakeling)
 *
 * Copyright:
 *     Written in 2016 by Joseph Rushton Wakeling.
 *
 * License:
 *     $(LINK2 https://creativecommons.org/publicdomain/zero/1.0/legalcode, Creative Commons CC0)
 *     (public domain)
 */
module dxorshift;

public import dxorshift.splitmix64;
public import dxorshift.xoroshiro128plus;

unittest
{
    import std.random : isUniformRNG;
    assert(isUniformRNG!SplitMix64);
    assert(isUniformRNG!Xoroshiro128plus);
}
