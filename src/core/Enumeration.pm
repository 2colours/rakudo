# Method that we have on enumeration types.
my role Enumeration {
    has $.key;
    has $.value;

    multi method Numeric(::?CLASS:D:) { $!value.Numeric }

    method enums() {
        self.^enum_values
    }

    multi method gist(::?CLASS:D:) {
        $!key
    }

    method kv(::?CLASS:D:) { ($!key, $!value) }

    method pair(::?CLASS:D:) { $!key => $!value }

    method perl() {
        self.defined ??
            (self.^name ~ '::' ~ $!key) !!
            self.^name;
    }

    method pick(*@pos, *%named) {
        self.defined
          ?? self xx +?( @pos[0] // 1 )
          !! self.^enum_value_list.pick(|@pos, |%named);
    }
    method roll(*@pos, *%named) {
        self.defined
          ?? self xx ( @pos[0] // 1 )
          !! self.^enum_value_list.roll(|@pos, |%named);
    }

    method Int(::?CLASS:D:) {
        self.value.Int
    }

    method invoke(|) {
        my $x := nqp::atpos(nqp::p6argvmarray(), 1).at_pos(0);
        nqp::istype($x, ::?CLASS)
            ?? $x
            !! self.HOW.enum_from_value(self, $x)
    }
}

# Methods that we also have if the base type of an enumeration is
# Numeric.
my role NumericEnumeration {
    multi method Str(::?CLASS:D:) {
        self.key
    }
}
my role StringyEnumeration {
    multi method Str(::?CLASS:D:) {
        self.value
    }
}

sub ANON_ENUM(*@args) {
    my Mu $prev = -1;
    my %res;
    for @args {
        if .^isa(Enum) {
            %res{.key} = $prev = .value;
        }
        else {
            %res{$_} = $prev.=succ;
        }
    }
    my $r := nqp::create(EnumMap);
    nqp::bindattr($r, EnumMap, '$!storage',
        nqp::getattr(%res, EnumMap, '$!storage'));
    $r;
}

Metamodel::EnumHOW.set_composalizer(-> $type, $name, %enum_values {
    my Mu $r := Metamodel::ParametricRoleHOW.new_type(:name($name));
    $r.HOW.add_attribute($r, Attribute.new(
        :name('$!' ~ $name), :type(nqp::decont($type)),
        :has_accessor(1), :package($r)));
    for %enum_values.kv -> $key, $value {
        my $meth = method () { self."$name"() === $value }
        $meth.set_name($key);
        $r.HOW.add_method($r, $key, $meth);
    }
    $r.HOW.set_body_block($r,
        -> |c { nqp::list($r, nqp::hash('$?CLASS', c<$?CLASS>)) });
    $r.HOW.compose($r);
    $r
});

# vim: ft=perl6 expandtab sw=4
