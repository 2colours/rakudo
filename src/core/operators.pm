## miscellaneous operators can go here.
##   generic numeric operators are in Numeric.pm
##   generic string operators are in Stringy.pm
##   Int/Rat/Num operators are in {Int|Rat|Num}.pm

sub infix:<=>(Mu \$a, Mu \$b) is rw {
    pir::perl6_container_store__0PP($a, $b)
}

proto infix:<does>(|$) { * }
multi infix:<does>(Mu:D \$obj, Mu:U \$role) is rw {
    # XXX Mutability check.
    $obj.HOW.mixin($obj, $role).BUILD_LEAST_DERIVED({});
}
multi infix:<does>(Mu:U \$obj, Mu:U \$role) is rw {
    die "Cannot use 'does' operator with a type object"
}
multi infix:<does>(Mu:D \$obj, @roles) is rw {
    # XXX Mutability check.
    $obj.HOW.mixin($obj, |@roles).BUILD_LEAST_DERIVED({});
}
multi infix:<does>(Mu:U \$obj, @roles) is rw {
    die "Cannot use 'does' operator with a type object"
}

proto infix:<but>(|$) { * }
multi infix:<but>(Mu:D \$obj, Mu:U \$role) {
    $obj.HOW.mixin($obj.clone(), $role).BUILD_LEAST_DERIVED({});
}
multi infix:<but>(Mu:U \$obj, Mu:U \$role) {
    $obj.HOW.mixin($obj, $role);
}
multi infix:<but>(Mu \$obj, Mu:D $val) is rw {
    my $role := Metamodel::ParametricRoleHOW.new_type();
    my $meth := method () { $val };
    $meth.set_name($val.^name);
    $role.HOW.add_method($role, $meth.name, $meth);
    $role.HOW.set_body_block($role,
        -> |$c { nqp::list($role, nqp::hash('$?CLASS', $c<$?CLASS>)) });
    $role.HOW.compose($role);
    $obj.HOW.mixin($obj.clone(), $role);
}
multi infix:<but>(Mu:D \$obj, @roles) {
    $obj.HOW.mixin($obj.clone(), |@roles).BUILD_LEAST_DERIVED({});
}
multi infix:<but>(Mu:U \$obj, @roles) {
    $obj.HOW.mixin($obj, |@roles)
}

sub SEQUENCE($left, $right, :$exclude_end) {
    my @right := $right.flat;
    my $endpoint = @right.shift;
    my $infinite = $endpoint ~~ Whatever;
    $endpoint = Bool::False if $infinite;
    my $tail := ().list;

    my sub generate($code) {
    }

    my sub succpred($cmp) {
        ($cmp < 0) ?? { $^x.succ } !! ( $cmp > 0 ?? { $^x.pred } !! { $^x } )
    }

    (GATHER({
        my @left := $left.flat;
        my $value;
        my $code;
        my $stop;
        while @left {
            $value = @left.shift;
            if $value ~~ Code { $code = $value; last }
            if $value ~~ $endpoint { $stop = 1; last }
            $tail.push($value);
            take $value;
        }
        unless $stop {
            $tail.munch($tail.elems - 3) if $tail.elems > 3;
            my $a = $tail[0];
            my $b = $tail[1];
            my $c = $tail[2];
            if $code.defined { }
            elsif $tail.elems == 3 {
                my $ab = $b - $a;
                if $ab == $c - $b {
                    if $ab != 0 || $a ~~ Numeric && $b ~~ Numeric && $c ~~ Numeric {
                        $code = { $^x + $ab } 
                    }
                    else {
                        $code = succpred($b cmp $c)
                    }
                }
                elsif $a != 0 && $b != 0 && $c != 0 {
                    $ab = $b / $a;
                    if $ab == $c / $b {
                        $ab = $ab.Int if $ab ~~ Rat && $ab.denominator == 1;
                        $code = { $^x * $ab }
                    }
                }
            }
            elsif $tail.elems == 2 {
                my $ab = $b - $a;
                if $ab != 0 || $a ~~ Numeric && $b ~~ Numeric { 
                    $code = { $^x + $ab } 
                }
                else {
                    $code = succpred($a cmp $b)
                }
            }
            elsif $tail.elems == 1 {
                $code = $a cmp $endpoint > 0 ?? { $^x.pred } !! { $^x.succ }
            }
            elsif $tail.elems == 0 {
                $code = {()}
            }

            if $code.defined {
                my $count = $code.count;
                while 1 {
                    $tail.munch($tail.elems - $count);
                    $value := $code(|$tail);
                    last if $value ~~ $endpoint;
                    $tail.push($value);
                    take $value;
                }
            }
            else {
                $value = (sub { fail "unable to deduce sequence" })();
            }
        }
        take $value unless $exclude_end;
    }, :$infinite), @right).list;
}
