/**
 * Implementation of the xoroshiro128+ uniform random number generator.
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
module dxorshift.xoroshiro128plus;

/**
 * The xoroshiro128+ uniform random number generator is the
 * fastest full-period generator passing the BigCrush test
 * suite without systematic failures.
 *
 * Due to the relatively short period (2 ^^ 128 - 1) it is
 * acceptable only for applications with a mild amount of
 * parallelism; for applications requiring many parallel
 * random sequences, `Xorshift1024star` is recommended
 * instead.
 *
 * Besides passing BigCrush, this generator passes the
 * PractRand test suite up to (and including) 16TB, with
 * the exception of binary rank tests, which fail due to
 * the lowest bit being a linear feedback shift register
 * (LFSR).  All other bits pass all tests.
 *
 * Credits:  This code is ported from the public-domain
 *           reference implementation by David Blackman
 *           and Sebastiano Vigna, available online at
 *    $(LINK http://xorshift.di.unimi.it/xoroshiro128plus.c)
 */
struct Xoroshiro128plus
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

    /// ditto
    this(ulong s0, ulong s1) @nogc @safe nothrow pure
    {
        this.seed(s0, s1);
    }

    /// ditto
    this(ulong[2] s) @nogc @safe nothrow pure
    {
        this.seed(s);
    }

    /// ditto
    this(R)(R range)
        if (isInputRange!R && is(Unqual!(ElementType!R) == ulong))
    {
        this.seed(range);
    }

    /// Range primitives
    enum bool empty = false;

    /// ditto
    ulong front() @nogc @property @safe const nothrow pure
    {
        return this.state[0] + this.state[1];
    }

    /// ditto
    void popFront() @nogc @safe nothrow pure
    in
    {
        assert(this.state != [0uL, 0uL]);
    }
    do
    {
        immutable ulong s1 = this.state[1] ^ this.state[0];
        this.state[0] = rotateLeft(this.state[0], 55) ^ s1 ^ (s1 << 14);
        this.state[1] = rotateLeft(s1, 36);
    }

    /**
     * Jump function, equivalent to 2 ^^ 64 calls to
     * `popFront()`; can be used to generate 2 ^^ 64
     * non-overlapping subsequences for
     * parallel computation.
     */
    void jump() @nogc @safe nothrow pure
    {
        enum ulong[2] jump_ = [0xbeac0467eba5facb, 0xd86b048b86aa9922];
        ulong s0 = 0;
        ulong s1 = 0;

        foreach (jmp; jump_)
        {
            for (int b = 0; b < 64; ++b)
            {
                if (jmp & 1uL << b)
                {
                    s0 ^= this.state[0];
                    s1 ^= this.state[1];
                }
                popFront();
            }
        }

        this.state[0] = s0;
        this.state[1] = s1;
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
        return typeof(this)(&this);
    }

    /// (Re)seeds the generator.
    void seed(ulong s) @nogc @safe nothrow pure
    {
        import dxorshift.splitmix64 : SplitMix64;
        this.seed(SplitMix64(s));
    }

    /// ditto
    void seed(ulong s0, ulong s1) @nogc @safe nothrow pure
    in
    {
        // seeds are not both 0
        assert(!(!s0 && !s1));
    }
    do
    {
        this.state[0] = s0;
        this.state[1] = s1;
        popFront();
    }

    /// ditto
    void seed(ulong[2] s) @nogc @safe nothrow pure
    in
    {
        assert(!(!s[0] && !s[1]));
    }
    do
    {
        seed(s[0], s[1]);
    }

    /// ditto
    void seed(R)(R range)
        if (isInputRange!R && is(Unqual!(ElementType!R) == ulong))
    {
        foreach (ref s; this.state)
        {
            import std.range.primitives : empty, front, popFront;
            assert(!range.empty, "Insufficient elements to populate RNG state!");
            s = range.front;
            range.popFront();
        }
        assert(this.state != typeof(this.state).init, "Seed elements cannot all be zero!");
        this.popFront();
    }

  private:
    // 128 bits of state
    ulong[2] state;

    // Helper constructor used to implement `dup`
    this(const(typeof(this)*) that) @nogc @safe nothrow pure
    {
        this.state[] = that.state[];
    }

    // Simulated rotate operation used in `popFront()`
    static ulong rotateLeft(ulong x, int k) @nogc @safe nothrow pure
    in
    {
        assert(0 <= k);
        assert(k <= 64);
    }
    do
    {
        return (x << k) | (x >> (64 - k));
    }

    import std.range.primitives : ElementType, isInputRange;
    import std.traits : Unqual;
}

///
unittest
{
    import std.array : array;
    import std.random : isUniformRNG, randomSample, uniform;
    import std.range : iota, take;
    import dxorshift.xoroshiro128plus;

    // xoroshiro128+ generators must be initialized
    // with a specified seed
    auto gen = Xoroshiro128plus(123456);

    // verify it is indeed a uniform RNG as defined
    // in the standard library, whether accessed
    // directly or via a pointer
    static assert(isUniformRNG!(typeof(gen)));
    static assert(isUniformRNG!(typeof(&gen)));

    // since the postblit is disabled, we must
    // pass a pointer to any functionality that
    // would otherwise copy the RNG by value
    assert((&gen).take(2).array == [14854895758870614632uL,
                                    2102156639392820999uL]);

    // this means, of course, that we must guarantee
    // the lifetime of the pointer is valid for the
    // lifetime of any functionality that uses it
    auto sample = iota(100).randomSample(10, &gen).array;

    // however, we can pass the RNG as-is to any
    // functionality that takes it by ref and does
    // not try to copy it by value
    auto val = uniform!"(]"(3.5, 4.0, gen);

    // in circumstances where we really want to
    // copy the RNG state, we can use `dup`
    auto gen2 = gen.dup;
    assert((&gen).take(9).array == (&gen2).take(9).array);
}

unittest
{
    import std.array : array;
    import std.random : isUniformRNG, isSeedable;
    import std.range : take;

    import dxorshift.splitmix64 : SplitMix64;

    static assert(isUniformRNG!Xoroshiro128plus);

    static assert(isSeedable!Xoroshiro128plus);
    static assert(isSeedable!(Xoroshiro128plus, ulong[2]));
    static assert(isSeedable!(Xoroshiro128plus, ulong[]));
    static assert(isSeedable!(Xoroshiro128plus, ulong));
    static assert(isSeedable!(Xoroshiro128plus, SplitMix64*));

    // output comparisons to reference implementation,
    // using constructor, seeding, and duplication
    {
        auto gen = Xoroshiro128plus(123, 456);
        assert((&gen).take(10).array == [4431571926312075699uL,  16834163345174162131uL,
                                         4468099366319113814uL,  167286530559998105uL,
                                         18053350147704165166uL, 9927833068668020801uL,
                                         14561249726909464726uL, 316732314664215799uL,
                                         8800682043873892537uL,  8955312909536390945uL]);

        gen.seed(123, 456);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [4431571926312075699uL,  16834163345174162131uL,
                                         4468099366319113814uL,  167286530559998105uL,
                                         18053350147704165166uL, 9927833068668020801uL,
                                         14561249726909464726uL, 316732314664215799uL,
                                         8800682043873892537uL,  8955312909536390945uL]);

        assert((&gen2).take(10).array == [4431571926312075699uL,  16834163345174162131uL,
                                          4468099366319113814uL,  167286530559998105uL,
                                          18053350147704165166uL, 9927833068668020801uL,
                                          14561249726909464726uL, 316732314664215799uL,
                                          8800682043873892537uL,  8955312909536390945uL]);
    }

    {
        ulong[2] s = [12345uL, 67890uL];

        auto gen = Xoroshiro128plus(s);
        assert((&gen).take(10).array == [2059148541540170003uL, 6156794878792115187uL,
                                         559523256690861310uL,  15314907387785043984uL,
                                         4915457426679953335uL, 5462571845969584332uL,
                                         9658602537074702831uL, 17979359875003347608uL,
                                         5174518315773110499uL, 2532010971873184518uL]);
        gen.seed(s);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [2059148541540170003uL, 6156794878792115187uL,
                                         559523256690861310uL,  15314907387785043984uL,
                                         4915457426679953335uL, 5462571845969584332uL,
                                         9658602537074702831uL, 17979359875003347608uL,
                                         5174518315773110499uL, 2532010971873184518uL]);

        assert((&gen2).take(10).array == [2059148541540170003uL, 6156794878792115187uL,
                                          559523256690861310uL,  15314907387785043984uL,
                                          4915457426679953335uL, 5462571845969584332uL,
                                          9658602537074702831uL, 17979359875003347608uL,
                                          5174518315773110499uL, 2532010971873184518uL]);
    }

    {
        auto s = 123456;

        auto gen = Xoroshiro128plus(s);
        assert((&gen).take(10).array == [14854895758870614632uL, 2102156639392820999uL,
                                         13092495043793465900uL, 8397221095866455920uL,
                                         6262852887298792196uL,  16202237309782713452uL,
                                         14544835201639844962uL, 7120381903468495472uL,
                                         4724551740662753335uL,  3230748688607015409uL]);

        gen.seed(s);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [14854895758870614632uL, 2102156639392820999uL,
                                         13092495043793465900uL, 8397221095866455920uL,
                                         6262852887298792196uL,  16202237309782713452uL,
                                         14544835201639844962uL, 7120381903468495472uL,
                                         4724551740662753335uL,  3230748688607015409uL]);

        assert((&gen2).take(10).array == [14854895758870614632uL, 2102156639392820999uL,
                                          13092495043793465900uL, 8397221095866455920uL,
                                          6262852887298792196uL,  16202237309782713452uL,
                                          14544835201639844962uL, 7120381903468495472uL,
                                          4724551740662753335uL,  3230748688607015409uL]);
    }

    {
        auto s = SplitMix64(123456);

        auto gen = Xoroshiro128plus(&s);
        assert((&gen).take(10).array == [14854895758870614632uL, 2102156639392820999uL,
                                         13092495043793465900uL, 8397221095866455920uL,
                                         6262852887298792196uL,  16202237309782713452uL,
                                         14544835201639844962uL, 7120381903468495472uL,
                                         4724551740662753335uL,  3230748688607015409uL]);

        s.seed(123456);
        gen.seed(&s);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [14854895758870614632uL, 2102156639392820999uL,
                                         13092495043793465900uL, 8397221095866455920uL,
                                         6262852887298792196uL,  16202237309782713452uL,
                                         14544835201639844962uL, 7120381903468495472uL,
                                         4724551740662753335uL,  3230748688607015409uL]);

        assert((&gen2).take(10).array == [14854895758870614632uL, 2102156639392820999uL,
                                          13092495043793465900uL, 8397221095866455920uL,
                                          6262852887298792196uL,  16202237309782713452uL,
                                          14544835201639844962uL, 7120381903468495472uL,
                                          4724551740662753335uL,  3230748688607015409uL]);
    }

    // compare jump to reference implementation,
    // using constructor, seeding and duplication
    {
        auto gen = Xoroshiro128plus(123, 456);
        gen.jump();
        assert((&gen).take(10).array == [3109680772672824672uL,  11190329315615627403uL,
                                         2415690012231644097uL,  2347094600162878539uL,
                                         18099586205610688946uL, 7375268959557732117uL,
                                         12413671816612458655uL, 14565394836119542025uL,
                                         5936088160154203578uL,  12124177863926731024uL]);

        gen.seed(123, 456);
        auto gen2 = gen.dup;
        gen.jump();
        assert((&gen).take(10).array == [3109680772672824672uL,  11190329315615627403uL,
                                         2415690012231644097uL,  2347094600162878539uL,
                                         18099586205610688946uL, 7375268959557732117uL,
                                         12413671816612458655uL, 14565394836119542025uL,
                                         5936088160154203578uL,  12124177863926731024uL]);

        gen2.jump();
        assert((&gen2).take(10).array == [3109680772672824672uL,  11190329315615627403uL,
                                          2415690012231644097uL,  2347094600162878539uL,
                                          18099586205610688946uL, 7375268959557732117uL,
                                          12413671816612458655uL, 14565394836119542025uL,
                                          5936088160154203578uL,  12124177863926731024uL]);
    }
}
