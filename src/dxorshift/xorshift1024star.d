/**
 * Implementation of the xorshift1024* uniform random number generator.
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
module dxorshift.xorshift1024star;

/**
 * Xorshift* generators extend the basic xorshift generation
 * mechanism by scrambling its output through multiplication
 * by a constant factor, without touching the underlying state.
 * The result is an extremely fast family of generators with
 * very high-quality statistical properties.
 *
 * The xorshift1024* generator offers a long (2 ^^ 1024 - 1)
 * period, making it suitable for many massively parallel
 * applications, while its speed and quality makes it useful
 * as a good general purpose random number generator.
 *
 * If 1024 bits of state are too much, then it is suggested
 * to use the Xoroshiro128+ generator instead.
 *
 * Credits:  This code is ported from the public-domain
 *           reference implementation by Sebastiano Vigna,
 *           available online at
 *    $(LINK http://xorshift.di.unimi.it/xorshift1024star.c)
 *
 *           See also the research paper introducing the
 *           xorshift* family of generators:
 *    $(LINK http://vigna.di.unimi.it/ftp/papers/xorshift.pdf)
 */
public struct Xorshift1024star
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
    this(ulong[16] s) @nogc @safe nothrow pure
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
        return this.state[this.p] * 1181783497276652981uL;
    }

    /// ditto
    void popFront() @nogc @safe nothrow pure
    in
    {
        assert(this.state != typeof(this.state).init);
    }
    body
    {
        immutable ulong s0 = this.state[this.p];
        ulong s1 = this.state[this.p = (this.p + 1) & 15];
        s1 ^= s1 << 31; // a
        this.state[this.p] = s1 ^ s0 ^ (s1 >> 11) ^ (s0 >> 30); // b, c
    }

    /**
     * Jump function, equivalent to 2 ^^ 512 calls to
     * `popFront()`; can be used to generate 2 ^^ 512
     * non-overlapping subsequences for parallel
     * computation.
     */
    void jump() @nogc @safe nothrow pure
    {
        enum ulong[16] jump_ =
            [0x84242f96eca9c41d, 0xa3c65b8776f96855, 0x5b34a39f070b5837, 0x4489affce4f31a1e,
             0x2ffeeb0a48316f40, 0xdc2d9891fe68c022, 0x3659132bb12fea70, 0xaac17d8efa43cab8,
             0xc4cb815590989b13, 0x5ee975283d71c93b, 0x691548c86c1bd540, 0x7910c41d10a1e6a5,
             0x0b5fc64563b3e2a8, 0x047f7684e9fc949d, 0xb99181f2d8f685ca, 0x284600e3f30e38c3];
        enum jumpSize = jump_.sizeof / (*(jump_.ptr)).sizeof;

        ulong[16] t;

        foreach (immutable size_t i; 0 .. jumpSize)
        {
            foreach (immutable int b; 0 .. 64)
            {
                if (jump_[i] & 1uL << b)
                {
                    foreach (immutable int j; 0 .. 16)
                    {
                        t[j] ^= this.state[(j + this.p) & 15];
                    }
                }
                this.popFront();
            }
        }

        foreach (immutable int j; 0 .. 16)
        {
            this.state[(j + this.p) & 15] = t[j];
        }

        this.popFront();
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
        import dxorshift.splitmix64 : SplitMix64;
        this.seed(SplitMix64(s));
    }

    /// ditto
    void seed(ulong[16] s) @nogc @safe nothrow pure
    in
    {
        assert(s != typeof(s).init);
    }
    body
    {
        this.state[] = s[];
        this.p = 0;
        this.popFront();
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
        this.p = 0;
        this.popFront();
    }

  private:
    // 1024 bits of state
    ulong[16] state;

    // state index used to determine `front` variate
    int p;

    // Helper constructor used to implement `dup`
    this(ref typeof(this) that) @nogc @safe nothrow pure
    {
        this.state[] = that.state[];
        this.p = that.p;
    }

    import std.range.primitives : ElementType, isInputRange;
    import std.traits : Unqual;
}

///
unittest
{
    import std.array : array;
    import std.random : isUniformRNG, randomCover, uniform;
    import std.range : iota, take;
    import dxorshift.xorshift1024star;

    // xorshift1024* generators must be initialized
    // with a specified seed
    auto gen = Xorshift1024star(123456);

    // verify it is indeed a uniform RNG as defined
    // in the standard library, whether accessed
    // directly or via a pointer
    static assert(isUniformRNG!(typeof(gen)));
    static assert(isUniformRNG!(typeof(&gen)));

    // since the postblit is disabled, we must
    // pass a pointer to any functionality that
    // would otherwise copy the RNG by value
    assert((&gen).take(2).array == [1060672336872339994uL,
                                    1269657541839679748uL]);

    // this means, of course, that we must guarantee
    // the lifetime of the pointer is valid for the
    // lifetime of any functionality that uses it
    auto sample = iota(100).randomCover(&gen).array;

    // however, we can pass the RNG as-is to any
    // functionality that takes it by ref and does
    // not try to copy it by value
    auto val = uniform!"[]"(0.0, 1.0, gen);

    // in circumstances where we really want to
    // copy the RNG state, we can use `dup`
    auto gen2 = gen.dup;
    assert((&gen).take(6).array == (&gen2).take(6).array);
}

unittest
{
    import std.array : array;
    import std.random : isUniformRNG, isSeedable;
    import std.range : take;
    import dxorshift.splitmix64 : SplitMix64;

    static assert(isUniformRNG!Xorshift1024star);
    static assert(isSeedable!Xorshift1024star);
    static assert(isSeedable!(Xorshift1024star, ulong[16]));
    static assert(isSeedable!(Xorshift1024star, SplitMix64));

    // output comparisons to reference implementation,
    // using constructor, seeding, and duplication
    {
        ulong[16] s = [1uL, 2, 3, 4, 5, 6, 7, 8, 9,
                       10, 11, 12, 13, 14, 15, 16];
        auto gen = Xorshift1024star(s);
        assert((&gen).take(10).array == [13859315694294268191uL, 660744553483990740uL,
                                         478363890149751658uL,   15363185464596488753uL,
                                         7048025930017007303uL,  14380354638086930432uL,
                                         12113818199582042386uL, 1643575379993549061uL,
                                         9691004143952970263uL,  660744553483990740uL]);

        gen.seed(s);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [13859315694294268191uL, 660744553483990740uL,
                                         478363890149751658uL,   15363185464596488753uL,
                                         7048025930017007303uL,  14380354638086930432uL,
                                         12113818199582042386uL, 1643575379993549061uL,
                                         9691004143952970263uL,  660744553483990740uL]);

        assert((&gen2).take(10).array == [13859315694294268191uL, 660744553483990740uL,
                                          478363890149751658uL,   15363185464596488753uL,
                                          7048025930017007303uL,  14380354638086930432uL,
                                          12113818199582042386uL, 1643575379993549061uL,
                                          9691004143952970263uL,  660744553483990740uL]);
    }

    {
        auto s = 123456;
        auto gen = Xorshift1024star(s);
        assert((&gen).take(10).array == [1060672336872339994uL,  1269657541839679748uL,
                                         16774050821694422223uL, 12851806877936958554uL,
                                         5358864585960698830uL,  15545527846258458164uL,
                                         13619620665948728563uL, 8885411006495285088uL,
                                         6807271905609969851uL,  5743177587051234395uL]);

        gen.seed(s);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [1060672336872339994uL,  1269657541839679748uL,
                                         16774050821694422223uL, 12851806877936958554uL,
                                         5358864585960698830uL,  15545527846258458164uL,
                                         13619620665948728563uL, 8885411006495285088uL,
                                         6807271905609969851uL,  5743177587051234395uL]);

        assert((&gen2).take(10).array == [1060672336872339994uL,  1269657541839679748uL,
                                          16774050821694422223uL, 12851806877936958554uL,
                                          5358864585960698830uL,  15545527846258458164uL,
                                          13619620665948728563uL, 8885411006495285088uL,
                                          6807271905609969851uL,  5743177587051234395uL]);
    }

    {
        auto s = SplitMix64(123456);
        auto gen = Xorshift1024star(&s);
        assert((&gen).take(10).array == [1060672336872339994uL,  1269657541839679748uL,
                                         16774050821694422223uL, 12851806877936958554uL,
                                         5358864585960698830uL,  15545527846258458164uL,
                                         13619620665948728563uL, 8885411006495285088uL,
                                         6807271905609969851uL,  5743177587051234395uL]);

        s.seed(123456);
        gen.seed(&s);
        auto gen2 = gen.dup;
        assert((&gen).take(10).array == [1060672336872339994uL,  1269657541839679748uL,
                                         16774050821694422223uL, 12851806877936958554uL,
                                         5358864585960698830uL,  15545527846258458164uL,
                                         13619620665948728563uL, 8885411006495285088uL,
                                         6807271905609969851uL,  5743177587051234395uL]);

        assert((&gen2).take(10).array == [1060672336872339994uL,  1269657541839679748uL,
                                          16774050821694422223uL, 12851806877936958554uL,
                                          5358864585960698830uL,  15545527846258458164uL,
                                          13619620665948728563uL, 8885411006495285088uL,
                                          6807271905609969851uL,  5743177587051234395uL]);
    }

    // compare jump to reference implementation,
    // using constructor, seeding, and duplication
    {
        ulong[16] s = [1uL, 2, 3, 4, 5, 6, 7, 8, 9,
                       10, 11, 12, 13, 14, 15, 16];
        auto gen = Xorshift1024star(s);
        gen.jump();
        assert((&gen).take(10).array == [8155847354254234864uL,  6748997114909436352uL,
                                         6977164193652481126uL,  894342858529849071uL,
                                         7913408723420027619uL,  4104992605899338783uL,
                                         15682203554882817936uL, 2242557222781099960uL,
                                         248325190090758889uL,   3505479351942936508uL]);

        gen.seed(s);
        auto gen2 = gen.dup;
        gen.jump();
        assert((&gen).take(10).array == [8155847354254234864uL,  6748997114909436352uL,
                                         6977164193652481126uL,  894342858529849071uL,
                                         7913408723420027619uL,  4104992605899338783uL,
                                         15682203554882817936uL, 2242557222781099960uL,
                                         248325190090758889uL,   3505479351942936508uL]);

        gen2.jump();
        assert((&gen2).take(10).array == [8155847354254234864uL,  6748997114909436352uL,
                                          6977164193652481126uL,  894342858529849071uL,
                                          7913408723420027619uL,  4104992605899338783uL,
                                          15682203554882817936uL, 2242557222781099960uL,
                                          248325190090758889uL,   3505479351942936508uL]);
    }
}
