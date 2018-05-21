# XXX: should be Rational[Int, uint]
my class Rat is Cool does Rational[Int, Int] {
    method Rat   (Rat:D: Real $?) { self }
    method FatRat(Rat:D: Real $?) { FatRat.new($!numerator, $!denominator); }
    multi method perl(Rat:D:) {
        if $!denominator == 1 {
            $!numerator ~ '.0'
        }
        else {
            my $d = $!denominator;
            unless $d == 0 {
                $d = $d div 5 while $d %% 5;
                $d = $d div 2 while $d %% 2;
            }
            if $d == 1 and (my $b := self.base(10,*)).Numeric === self {
                $b;
            }
            else {
                '<' ~ $!numerator ~ '/' ~ $!denominator ~ '>'
            }
        }
    }
}

my constant UINT64_UPPER = nqp::pow_I(2, 64, Num, Int);

my class FatRat is Cool does Rational[Int, Int] {
    method FatRat(FatRat:D: Real $?) { self }
    method Rat   (FatRat:D: Real $?) {
        $!denominator < UINT64_UPPER
          ?? Rat.new($!numerator, $!denominator)
          !! Failure.new("Cannot convert from FatRat to Rat because denominator is too big")
    }
    multi method perl(FatRat:D:) {
        "FatRat.new($!numerator, $!denominator)";
    }
}

sub DIVIDE_NUMBERS(Int:D \nu, Int:D \de, \t1, \t2) {
    nqp::stmts(
      (my $gcd := de ?? nqp::gcd_I(nqp::decont(nu), nqp::decont(de), Int) !! 1),
      (my $numerator   := nqp::div_I(nqp::decont(nu), $gcd, Int)),
      (my $denominator := nqp::div_I(nqp::decont(de), $gcd, Int)),
      nqp::if(
        nqp::islt_I($denominator, 0),
        nqp::stmts(
          ($numerator   := nqp::neg_I($numerator, Int)),
          ($denominator := nqp::neg_I($denominator, Int)))),
      nqp::if(
        nqp::istype(t1, FatRat) || nqp::istype(t2, FatRat),
        nqp::p6bindattrinvres(
          nqp::p6bindattrinvres(nqp::create(FatRat),
            FatRat,'$!numerator',$numerator),
          FatRat,'$!denominator',$denominator),
        nqp::if(
          nqp::islt_I($denominator, UINT64_UPPER),
          nqp::p6bindattrinvres(
            nqp::p6bindattrinvres(nqp::create(Rat),
              Rat,'$!numerator',$numerator),
            Rat,'$!denominator',$denominator),
          nqp::p6box_n(nqp::div_In($numerator, $denominator)))))
}

multi sub prefix:<->(Rat:D \a) {
    Rat.new(-a.numerator, a.denominator);
}
multi sub prefix:<->(FatRat:D \a) {
    FatRat.new(-a.numerator, a.denominator);
}

multi sub infix:<+>(Rational:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a.numerator*b.denominator + b.numerator*a.denominator,
        a.denominator*b.denominator,
        a,
        b
}
multi sub infix:<+>(Rational:D \a, Int:D \b) {
    DIVIDE_NUMBERS
        a.numerator + b*a.denominator,
        a.denominator,
        a,
        b
}
multi sub infix:<+>(Int:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a*b.denominator + b.numerator,
        b.denominator,
        a,
        b
}

multi sub infix:<->(Rational:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a.numerator*b.denominator - b.numerator*a.denominator,
        a.denominator*b.denominator,
        a,
        b
}

multi sub infix:<->(Rational:D \a, Int:D \b) {
    DIVIDE_NUMBERS
        a.numerator - b * a.denominator,
        a.denominator,
        a,
        b
}

multi sub infix:<->(Int:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a * b.denominator - b.numerator,
        b.denominator,
        a,
        b
}

multi sub infix:<*>(Rational:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a.numerator * b.numerator,
        a.denominator * b.denominator,
        a,
        b
}

multi sub infix:<*>(Rational:D \a, Int:D \b) {
    DIVIDE_NUMBERS
        a.numerator * b,
        a.denominator,
        a,
        b
}

multi sub infix:<*>(Int:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a * b.numerator,
        b.denominator,
        a,
        b
}

multi sub infix:</>(Rational:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        a.numerator * b.denominator,
        a.denominator * b.numerator,
        a,
        b
}

multi sub infix:</>(Rational:D \a, Int:D \b) {
    DIVIDE_NUMBERS
        a.numerator,
        a.denominator * b,
        a,
        b
}

multi sub infix:</>(Int:D \a, Rational:D \b) {
    DIVIDE_NUMBERS
        b.denominator * a,
        b.numerator,
        a,
        b
}

multi sub infix:</>(Int:D \a, Int:D \b) {
    DIVIDE_NUMBERS a, b, a, b
}

multi sub infix:<%>(Rational:D \a, Int:D \b) {
    a - floor(a / b) * b
}

multi sub infix:<%>(Int:D \a, Rational:D \b) {
    a - floor(a / b) * b
}

multi sub infix:<%>(Rational:D \a, Rational:D \b) {
    a - floor(a / b) * b
}

multi sub infix:<**>(Rational:D \a, Int:D \b) {
    b >= 0
        ?? DIVIDE_NUMBERS
            (a.numerator ** b // fail (a.numerator.abs > a.denominator ?? X::Numeric::Overflow !! X::Numeric::Underflow).new),
            a.denominator ** b,  # we presume it likely already blew up on the numerator
            a,
            b
        !! DIVIDE_NUMBERS
            (a.denominator ** -b // fail (a.numerator.abs < a.denominator ?? X::Numeric::Overflow !! X::Numeric::Underflow).new),
            a.numerator ** -b,
            a,
            b
}

multi sub infix:<==>(Rational:D \a, Rational:D \b) {
    nqp::isfalse(a.denominator) || nqp::isfalse(b.denominator)
        ?? a.numerator == b.numerator && nqp::p6bool(a.numerator) # NaN != NaN
        !! a.numerator * b.denominator == b.numerator * a.denominator
}
multi sub infix:<==>(Rational:D \a, Int:D \b) {
    a.numerator == b && a.denominator == 1
}
multi sub infix:<==>(Int:D \a, Rational:D \b) {
    a == b.numerator && b.denominator == 1;
}
multi sub infix:<===>(Rational:D \a, Rational:D \b --> Bool:D) {
    a.WHAT =:= b.WHAT && (a == b || a.isNaN && b.isNaN)
}

multi sub infix:«<»(Rational:D \a, Rational:D \b) {
    a.numerator * b.denominator < b.numerator * a.denominator
}
multi sub infix:«<»(Rational:D \a, Int:D \b) {
    a.numerator  < b * a.denominator
}
multi sub infix:«<»(Int:D \a, Rational:D \b) {
    a * b.denominator < b.numerator
}

multi sub infix:«<=»(Rational:D \a, Rational:D \b) {
    a.numerator * b.denominator <= b.numerator * a.denominator
}
multi sub infix:«<=»(Rational:D \a, Int:D \b) {
    a.numerator  <= b * a.denominator
}
multi sub infix:«<=»(Int:D \a, Rational:D \b) {
    a * b.denominator <= b.numerator
}

multi sub infix:«>»(Rational:D \a, Rational:D \b) {
    a.numerator * b.denominator > b.numerator * a.denominator
}
multi sub infix:«>»(Rational:D \a, Int:D \b) {
    a.numerator  > b * a.denominator
}
multi sub infix:«>»(Int:D \a, Rational:D \b) {
    a * b.denominator > b.numerator
}

multi sub infix:«>=»(Rational:D \a, Rational:D \b) {
    a.numerator * b.denominator >= b.numerator * a.denominator
}
multi sub infix:«>=»(Rational:D \a, Int:D \b) {
    a.numerator  >= b * a.denominator
}
multi sub infix:«>=»(Int:D \a, Rational:D \b) {
    a * b.denominator >= b.numerator
}

multi sub infix:«<=>»(Rational:D \a, Rational:D \b) {
    a.numerator * b.denominator <=> b.numerator * a.denominator
}
multi sub infix:«<=>»(Rational:D \a, Int:D \b) {
    a.numerator  <=> b * a.denominator
}
multi sub infix:«<=>»(Int:D \a, Rational:D \b) {
    a * b.denominator <=> b.numerator
}

# vim: ft=perl6 expandtab sw=4
