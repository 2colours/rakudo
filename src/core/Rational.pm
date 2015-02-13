my role Rational[::NuT, ::DeT] does Real {
    has NuT $.numerator;
    has DeT $.denominator;

    multi method WHICH(Rational:D:) {
        nqp::box_s(
            nqp::concat(
                nqp::concat(nqp::unbox_s(self.^name), '|'),
                nqp::concat(
                    nqp::tostr_I($!numerator),
                    nqp::concat('/', nqp::tostr_I($!denominator))
                )
            ),
            ObjAt
        );
    }

    method new(NuT \nu = 0, DeT \de = 1) {
        my $new     := nqp::create(self);
        my $gcd     := nu gcd de;
        my $numerator   = nu div $gcd;
        my $denominator = de div $gcd;
        if $denominator < 0 {
            $numerator   = -$numerator;
            $denominator = -$denominator;
        }
        nqp::bindattr($new, self.WHAT, '$!numerator',     nqp::decont($numerator));
        nqp::bindattr($new, self.WHAT, '$!denominator',   nqp::decont($denominator));
        $new;
    }

    method nude() { $!numerator, $!denominator }
    method Num() {
        $!denominator == 0
          ?? ($!numerator < 0 ?? -Inf !! Inf)
          !! nqp::p6box_n(nqp::div_In(
                nqp::decont($!numerator),
                nqp::decont($!denominator)
             ));
    }

    method floor(Rational:D:) {
        # correct formula
        $!denominator == 1
            ?? $!numerator
            !! $!numerator div $!denominator
    }

    method ceiling(Rational:D:) {
        # correct formula
        $!denominator == 1
            ?? $!numerator
            !! ($!numerator div $!denominator + 1)
    }

    method Int() { self.truncate }

    method Bridge() { self.Num }

    multi method Str(::?CLASS:D:) {
        my $s = $!numerator < 0 ?? '-' !! '';
        my $r = self.abs;
        my $i = $r.floor;
        $r -= $i;
        $s ~= $i;
        if $r {
            $s ~= '.';
            my $want = $!denominator < 100_000
                       ?? 6
                       !! $!denominator.Str.chars + 1;
            my $f = '';
            while $r and $f.chars < $want {
                $r *= 10;
                $i = $r.floor;
                $f ~= $i;
                $r -= $i;
            }
            $f++ if  2 * $r >= 1;
            $s ~= $f;
        }
        $s;
    }

    method base($base, $digits = ($!denominator < $base**6 ?? 6 !! $!denominator.log($base).ceiling + 1)) {
        my $s = $!numerator < 0 ?? '-' !! '';
        my $r = self.abs;
        my $i = $r.floor;
        $r -= $i;
        $s ~= $i.base($base);
        if $r {
            my @f;
            while $r and @f < $digits {
                $r *= $base;
                $i = $r.floor;
                push @f, $i;
                $r -= $i;
            }
            if 2 * $r >= 1 {
                for @f-1 ... 0 -> $x {
                    last if ++@f[$x] < $base;
                    @f[$x] = 0;
                    $s ~= ($i+1).base($base) if $x == 0; # never happens?
                }
            }
            $s ~= '.';
            state @digits = '0'..'9', 'A'..'Z';
            $s ~= @digits[@f].join;
        }
        $s;
    }

    method base-repeating($base) {
        my $s = $!numerator < 0 ?? '-' !! '';
        my $r = self.abs;
        my $i = $r.floor;
        my $reps = '';
        $r -= $i;
        $s ~= $i.base($base);
        if $r {
            my @f;
            my %seen;
            my $rp = $r.perl;
            while $r and $r ~~ Rat {
                %seen{$rp} = +@f;
                $r *= $base;
                $i = $r.floor;
                $r -= $i;
                $rp = $r.perl;
                push @f, $i;
                last if %seen{$rp}.defined;
                last if +@f >= 100000;  # sanity
            }
            state @digits = '0'..'9', 'A'..'Z';
            my $frac = @digits[@f].join;
            if $r {
                my $seen = %seen{$r.perl};
                if $seen.defined {
                    $reps = substr($frac,$seen);
                    $frac = substr($frac,0,$seen);
                }
                else {
                    $reps ~= '???';
                }
            }
            $s ~= '.' ~ $frac;
        }
        $s, $reps;
    }

    method succ {
        self.new($!numerator + $!denominator, $!denominator);
    }

    method pred {
        self.new($!numerator - $!denominator, $!denominator);
    }

    method norm() { self }

    method narrow(::?CLASS:D:) {
        $!denominator == 1
            ?? $!numerator
            !! self;
    }
}

# vim: ft=perl6 expandtab sw=4
