/**
 * Simple speed shootout benchmark between the generators
 * implemented in this package and the default phobos
 * random number generator.
 *
 * Usage:
 * ------
 * dxorshift_benchmark [-n N] [--seed S]
 *
 *           -n  specify number of calls to the RNG
 *               in the benchmark; if not specified,
 *               10 ^^ 9 will be used by default
 *
 *   --seed, -s  specify the seed to provide to the
 *               benchmarked RNGS; if not specified,
 *               an unpredictable seed will be used.
 * ------
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
module benchmark.app;

void main(string[] args)
{
    import std.conv : to;
    import std.datetime : benchmark, Duration;
    import std.getopt : getopt;
    import std.random : Random, unpredictableSeed;
    import std.stdio : writeln, writefln;

    import dxorshift.splitmix64;
    import dxorshift.xoroshiro128plus;
    import dxorshift.xorshift1024star;

    uint repeats;

    uint seed;

    getopt(args,
           "|n", &repeats,
           "seed|s", &seed);

    if (!repeats)
    {
        repeats = 1_000_000_000u;
        writefln("Number of variates not specified: defaulting to %s", repeats);
    }

    if (!seed)
    {
        seed = unpredictableSeed;
    }

    writefln("Seeding generators with %s", seed);

    auto genX128 = Xoroshiro128plus(seed);

    auto genX1024 = Xorshift1024star(seed);

    auto genSM64 = SplitMix64(seed);

    auto genDefault = Random(seed);

    // summing over all generated variates adds
    // a little overhead, but prevents spurious
    // optimizations of generator `popFront()`
    // calls: e.g. since `SplitMix64.popFront()`
    // is just an addition, any arbitrary number
    // of calls can be optimized away at compile
    // time unless `.front` values are actually
    // used for something
    ulong variateSum;

    void variateX128()
    {
        variateSum += genX128.front;
        genX128.popFront();
    }

    void variateX1024()
    {
        variateSum += genX1024.front;
        genX1024.popFront();
    }

    void variateSM64()
    {
        variateSum += genSM64.front;
        genSM64.popFront();
    }

    void variateDefault()
    {
        variateSum += genDefault.front;
        genDefault.popFront();
    }


    auto bench = benchmark!(variateX128, variateX1024, variateSM64, variateDefault)(repeats);
    auto benchX128 = to!Duration(bench[0]);
    auto benchX1024 = to!Duration(bench[1]);
    auto benchSM64 = to!Duration(bench[2]);
    auto benchDefault = to!Duration(bench[3]);

    writefln("xoroshiro128+ benchmark for %s variates: %s", repeats, benchX128);
    writefln("last variate: %s", genX128.front);
    writeln();

    writefln("xorshift1024* benchmark for %s variates: %s", repeats, benchX1024);
    writefln("last variate: %s", genX1024.front);
    writeln();

    writefln("splitmix64 benchmark for %s variates: %s", repeats, benchSM64);
    writefln("last variate: %s", genSM64.front);
    writeln();

    writefln("Default phobos RNG benchmark for %s variates: %s", repeats, benchDefault);
    writefln("last variate: %s", genDefault.front);
}
