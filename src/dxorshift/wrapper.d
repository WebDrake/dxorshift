/**
 * Provides a convenient safety wrapper for uniform random number
 * generators that should guarantee reference-type, input range
 * semantics, and is usable in `@safe` code if the underlying
 * uniform RNG is itself `@safe`.
 *
 * Example:
 * --------
 * import std.random : Random;
 * import std.range : take;
 *
 * import dxorshift.xoroshiro128plus : Xoroshiro128plus;
 * import dxorshift.wrapper : uniformRNG;
 *
 * auto gen = Xoroshiro128plus(123456);
 *
 * // RNGs defined in the dxorshift package
 * // cannot be copied by value.  Passing
 * // them via pointer like this is not
 * // permitted in `@safe` code:
 * auto unsafeTake = (&gen).take(10);
 *
 * // however, the `uniformRNG` wrapper can
 * // be used in `@safe` code:
 * auto safeTake = gen.uniformRNG.take(10);
 *
 * // it can also be used to wrap generators
 * // from phobos' `std.random` to guarantee
 * // they will have reference-type, input
 * // range semantics
 * auto gen2 = Random(123456);
 * auto phobosTake = gen2.uniformRNG.take(10);
 * --------
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
module dxorshift.wrapper;

import std.random : isUniformRNG;

/**
 * Safety wrapper that ensures reference-type, input-range
 * access to the underlying uniform random number generator.
 *
 * This can be used for two distinct purposes.  First, it
 * can be used to wrap RNGs whose postblit has been disabled
 * (such as those in dxorshift), allowing them to be used in
 * `@safe` code; second, it can be used to wrap random number
 * generators from Phobos' `std.random` in a way that should
 * prevent the main sources of unintended copying of the RNG
 * (both direct copy-by-value, and use of the `save` property).
 *
 * Template_Params:
 *     BaseRNG = underlying type of uniform random number
 *               generator
 */
public struct SafeUniformRNG (BaseRNG)
    if (isUniformRNG!BaseRNG)
{
  public:
    /**
     * Constructor
     *
     * Params:
     *     gen = uniform random number generator instance
     *           to wrap; its lifetime must be guaranteed
     *           throughout the corresponding lifetime of
     *           the `SafeUniformRNG` instance
     */
    this (return ref BaseRNG gen) @trusted
    {
        this.generator = &gen;
    }

    /// Marks this range as a uniform random number generator
    enum isUniformRandom = BaseRNG.isUniformRandom;

    /// Smallest generated value
    enum min = BaseRNG.min;

    /// Largest generated value
    enum max = BaseRNG.max;

    static if (isInfinite!BaseRNG)
    {
        /// Range primitives
        enum bool empty = false;
    }
    else
    {
        // unlikely that any RNG type will not
        // be an infinite range, but let's at
        // least take care of the possibility

        /// Range primitives
        bool empty() @property
        {
            return this.generator.empty;
        }
    }

    /// ditto
    auto front() @property
    {
        return this.generator.front;
    }

    /// ditto
    auto popFront()
    {
        this.generator.popFront();
    }

    /**
     * (Re)seeds the underlying generator, if it
     * supports the provided seed type
     *
     * Template_Params:
     *     Seed = type of seed to pass to the
     *            underlying generator
     *
     * Params:
     *     s = seed to pass to the underlying
     *         generator
     */
    void seed(Seed...)(Seed s)
    {
        this.generator.seed(s);
    }

  private:
    // pointer to underlying uniform RNG
    BaseRNG* generator;

    invariant()
    {
        assert(this.generator !is null);
    }

    import std.range.primitives : isInfinite;
}

/**
 * Generates a safe wrapper for an existing uniform random
 * number generator instance, guaranteeing reference-type,
 * input-range semantics.  This can/should be used:
 *
 *   $(UL $(LI as a `@safe` alternative to passing a
 *             pointer to an RNG instance;)
 *        $(LI as a means to avoid the forward-range
 *             semantics implemented by many RNGS in
 *             phobos and elsewhere.))
 *
 * Template_Params:
 *     BaseRNG = underlying type of uniform random
 *               number generator
 *
 * Params:
 *     generator = uniform random number generator
 *                 instance to wrap; its lifetime
 *                 must be guaranteed for the
 *                 entire lifetime of the wrapper
 *                 returned
 *
 * Returns:
 *     input-range uniform RNG wrapping a pointer
 *     to `generator`
 */
public auto uniformRNG(BaseRNG)(return ref BaseRNG generator)
{
    return SafeUniformRNG!BaseRNG(generator);
}

///
unittest
{
    import std.array : array;
    import std.random : isUniformRNG;
    import std.range : take;

    import dxorshift.xoroshiro128plus: Xoroshiro128plus;
    import dxorshift.wrapper : uniformRNG;

    auto gen = Xoroshiro128plus(123456);

    // demonstrate that `uniformRNG` can be
    // used in @safe code if the underlying
    // RNG type supports it
    auto takeTwo () @nogc @property @safe nothrow pure
    {
        return gen.uniformRNG.take(2);
    }

    assert(takeTwo.array == [14854895758870614632uL, 2102156639392820999uL]);

    // the safely-wrapped generator has reference
    // type, input range semantics
    auto safeGen = gen.uniformRNG;

    static assert(isUniformRNG!(typeof(safeGen)));
    static assert(!is(typeof(safeGen.save)));

    // seeds will be passed on to the underlying RNG
    safeGen.seed(123456);

    // reference type semantics mean that the
    // generator will not accidentally be copied
    // by value into other functionality
    auto takeA = safeGen.take(10).array;
    auto takeB = safeGen.take(10).array;
    assert(takeA != takeB);

    // however, by reseeding, we can recreate
    // the same sequences
    safeGen.seed(123456);
    auto takeC = safeGen.take(10).array;
    auto takeD = safeGen.take(10).array;
    assert(takeC != takeD);
    assert(takeC == takeA);
    assert(takeD == takeB);
}

// test `uniformRNG`'s behavior with phobos RNGs
@safe unittest
{
    import std.array : array;
    import std.random : isUniformRNG, isSeedable, PseudoRngTypes;
    import std.range.primitives : isInfinite, isInputRange, isForwardRange;
    import std.range : take;

    foreach (RNG; PseudoRngTypes)
    {
        alias SafeRNG = SafeUniformRNG!RNG;

        static assert(isUniformRNG!SafeRNG);
        static assert(isSeedable!SafeRNG == isSeedable!RNG);
        static assert(isInfinite!SafeRNG == isInfinite!RNG);

        static assert(isInputRange!SafeRNG);
        static assert(!isForwardRange!SafeRNG);
        static assert(!is(typeof(SafeRNG.save)));

        // assuming RNG is seedable, we validate
        // expected differences between phobos
        // RNGs' normal behaviour and how they
        // behave when wrapped by `uniformRNG`
        static if (isSeedable!RNG)
        {
            RNG gen;
            gen.seed(123456);

            // if we pass any normal phobos RNG
            // directly into a range chain, it
            // will (sadly) be copied by value
            auto take1 = gen.take(10).array;
            auto take2 = gen.take(10).array;
            assert(take1 == take2);

            gen.seed(123456);

            // if however we wrap it with `uniformRNG`
            // it will be passed by reference
            auto safeGen = uniformRNG(gen);
            auto take3 = safeGen.take(10).array;
            auto take4 = safeGen.take(10).array;
            assert(take3 == take1); // because we start from the same seed
            assert(take3 != take4);

            // validate we can however re-seed the
            // safely wrapped generator and get
            // the same results once again
            safeGen.seed(123456);
            auto take5 = safeGen.take(10).array;
            auto take6 = safeGen.take(10).array;
            assert(take5 == take3);
            assert(take6 == take4);
        }
    }
}

// validate `uniformRNG` works with dxorshift RNGs
// and allows them to work in @safe code
@safe nothrow pure unittest
{
    import std.array : array;
    import std.meta : AliasSeq;
    import std.random : isUniformRNG, isSeedable;
    import std.range.primitives : isInfinite, isInputRange, isForwardRange;
    import std.range : take;

    import dxorshift : SplitMix64, Xoroshiro128plus, Xorshift1024star;

    foreach (RNG; AliasSeq!(SplitMix64, Xoroshiro128plus, Xorshift1024star))
    {
        alias SafeRNG = SafeUniformRNG!RNG;

        static assert(isUniformRNG!SafeRNG);
        static assert(isSeedable!SafeRNG);
        static assert(isInfinite!SafeRNG);
        static assert(isInputRange!SafeRNG);
        static assert(!isForwardRange!SafeRNG);
        static assert(!is(typeof(SafeRNG.save)));

        // dxorshift generators must be constructed
        // with a seed
        auto gen = RNG(123456);

        // we can't copy dxorshift RNGs by value,
        // and it's not safe to just take the
        // pointer address, so let's just jump
        // to wrapping them in `uniformRNG`
        auto safeGen = uniformRNG(gen);
        auto take1 = safeGen.take(10).array;
        auto take2 = safeGen.take(10).array;
        assert(take1 != take2);

        // re-seeding should give us the same
        // results once over
        gen.seed(123456);
        auto take3 = safeGen.take(10).array;
        auto take4 = safeGen.take(10).array;
        assert(take3 == take1);
        assert(take4 == take2);

        // re-seeding via the safe wrapper
        // should produce the same results
        safeGen.seed(123456);
        auto take5 = safeGen.take(10).array;
        auto take6 = safeGen.take(10).array;
        assert(take5 == take1);
        assert(take6 == take2);
    }
}

// test the very unlikely scenario of a finite RNG
// (just to make sure `SafeUniformRNG.empty` can
// handle it)
unittest
{
    import std.array : array;
    import std.random : isUniformRNG, PseudoRngTypes;
    import std.range.primitives : isInfinite;

    import dxorshift.wrapper : uniformRNG;

    struct FiniteRNG (BaseRNG)
        if (isUniformRNG!BaseRNG)
    {
      public:
        this(uint s)
        {
            this.gen = BaseRNG(s);
            this.count = 0;
        }

        enum isUniformRandom = BaseRNG.isUniformRandom;

        enum min = BaseRNG.min;

        enum max = BaseRNG.max;

        bool empty() @property
        {
            return this.gen.empty || this.count >= 10;
        }

        auto front() @property
        {
            return this.gen.front;
        }

        auto popFront()
        {
            this.gen.popFront();
            this.count++;
        }

      private:
        BaseRNG gen;

        int count;
    }

    foreach (RNG; PseudoRngTypes)
    {
        auto finiteGen = FiniteRNG!RNG(123456);

        static assert(isUniformRNG!(FiniteRNG!RNG));
        static assert(!isInfinite!(FiniteRNG!RNG));

        assert(finiteGen.uniformRNG.array.length == 10);
    }
}
