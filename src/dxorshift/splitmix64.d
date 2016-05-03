/**
 * Implementation of the SplitMix64 uniform random number generator.
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
module dxorshift.splitmix64;

/**
 * This is a fixed-increment version of Java 8's SplittableRandom
 * generator.  It is a very fast generator passing BigCrush, and
 * can be useful if for some reason exactly 64 bits of state are
 * needed; otherwise, it is suggested to use Xoroshiro128plus
 * (for moderately parallel computations) or Xorshift1024star
 * (for massively parallel computations).
 *
 * The generator period is 2 ^^ 64.
 *
 * Credits:  This implementation is ported from the public-domain
 *           C implementation by Sebastiano Vigna, available at
 *           $(LINK http://xoroshiro.di.unimi.it/splitmix64.c)
 *
 *           For more details on the SplittableRandom generator,
 *           see $(LINK http://dx.doi.org/10.1145/2714064.2660195)
 *           and
 *    $(LINK http://docs.oracle.com/javase/8/docs/api/java/util/SplittableRandom.html)
 */
struct SplitMix64
{
  public:
    /// Marks this range as a uniform random number generator
    enum bool isUniformRandom = true;

    /// Smallest generated value (0)
    enum ulong min = ulong.min;

    /// Largest generated value
    enum ulong max = ulong.max;

    /* Copy-by-value is disabled to avoid unintended
     * duplication of random sequences; use the `dup`
     * property if you really wish to copy the state
     * of the RNG.
     */
    @disable this(this);

    // RNG can only be initialized with a seed
    @disable this();

    /**
     * Constructor (RNG instances can only be initialized
     * with a specified seed).
     */
    this(ulong s) @nogc @safe nothrow pure
    {
        this.seed(s);
    }

    /// Range primitives
    enum bool empty = false;

    /// ditto
    ulong front() @nogc @property @safe const nothrow pure
    {
        ulong z = this.state;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9uL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBuL;
        return z ^ (z >> 31);
    }

    /// ditto
    void popFront() @nogc @safe nothrow pure
    {
        this.state += 0x9E3779B97F4A7C15uL;
    }

    /**
     * Provides a copy of this RNG instance with identical
     * internal state.
     *
     * This property is provided in preference to `save`
     * so as to allow the user to duplicate RNG state
     * when explicitly desired, but without risking
     * unintended copies by functions that save forward
     * ranges provided as input.
     */
    typeof(this) dup() @nogc @property @safe nothrow pure
    {
        return typeof(this)(this);
    }

    /// (Re)seeds the generator.
    void seed(ulong s) @nogc @safe nothrow pure
    {
        this.state = s;
        popFront();
    }

  private:
    // 64 bits of state
    ulong state;

    // Helper constructor used to implement `dup`
    this(const ref typeof(this) that) @nogc @safe nothrow pure
    {
        this.state = that.state;
    }
}

///
unittest
{
    import std.array : array;
    import std.random : isUniformRNG, randomSample, uniform;
    import std.range : iota, take;
    import dxorshift.splitmix64;

    // splitmix64 generators must be initialized
    // with a specified seed
    auto gen = SplitMix64(123456);

    // verify it is indeed a uniform RNG as defined
    // in the standard library, whether accessed
    // directly or via a pointer
    static assert(isUniformRNG!(typeof(gen)));
    static assert(isUniformRNG!(typeof(&gen)));

    // since the postblit is disabled, we must
    // pass a pointer to any functionality that
    // would otherwise copy the RNG by value
    assert((&gen).take(2).array == [4172122716518060777uL,
                                    4753009419905186825uL]);

    // this means, of course, that we must guarantee
    // the lifetime of the pointer is valid for the
    // lifetime of any functionality that uses it
    auto sample = iota(100).randomSample(10, &gen).array;

    // however, we can pass the RNG as-is to any
    // functionality that takes it by ref and does
    // not try to copy it by value
    auto val = uniform!"()"(-0.5, 0.5, gen);

    // in circumstances where we really want to
    // copy the RNG state, we can use `dup`
    auto gen2 = gen.dup;
    assert((&gen).take(3).array == (&gen2).take(3).array);
}

unittest
{
    import std.array : array;
    import std.random : isUniformRNG, isSeedable;
    import std.range : take;

    static assert(isUniformRNG!SplitMix64);
    static assert(isSeedable!SplitMix64);
    static assert(isSeedable!(SplitMix64, ulong));

    // output comparisons to reference implementation,
    // using constructor, seeding, and duplication
    auto gen = SplitMix64(123456);
    assert((&gen).take(10).array == [4172122716518060777uL,  4753009419905186825uL,
                                     10875153875153110245uL, 13339995472625950266uL,
                                     7648109466873647511uL,  14419900863156435859uL,
                                     6946445154006067732uL,  16574328997999076320uL,
                                     13559424511686201017uL, 13754107039689013136uL]);

    gen.seed(123456);
    auto gen2 = gen.dup;
    assert((&gen).take(10).array == [4172122716518060777uL,  4753009419905186825uL,
                                     10875153875153110245uL, 13339995472625950266uL,
                                     7648109466873647511uL,  14419900863156435859uL,
                                     6946445154006067732uL,  16574328997999076320uL,
                                     13559424511686201017uL, 13754107039689013136uL]);

    assert((&gen2).take(10).array == [4172122716518060777uL,  4753009419905186825uL,
                                      10875153875153110245uL, 13339995472625950266uL,
                                      7648109466873647511uL,  14419900863156435859uL,
                                      6946445154006067732uL,  16574328997999076320uL,
                                      13559424511686201017uL, 13754107039689013136uL]);
}
