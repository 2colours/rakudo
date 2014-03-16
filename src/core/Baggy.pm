my role Baggy does QuantHash {
    has %!elems; # key.WHICH => (key,value)

    method BUILD (:%!elems) {}
    method default(--> Int) { 0 }
    method keys { %!elems.values.map( {.key} ) }
    method values { %!elems.values.map( {.value} ) }
    method kv { %!elems.values.map( {.key, .value} ) }
    method elems(--> Int) { %!elems.elems }
    method total(--> Int) { [+] self.values }
    method exists ($k --> Bool) {  # is DEPRECATED doesn't work in settings
        DEPRECATED("the :exists adverb");
        self.exists_key($k);
    }
    method exists_key($k --> Bool) {
        %!elems.exists_key($k.WHICH);
    }
    method Bool { %!elems.Bool }

    method hash(--> Hash) { %!elems.values.hash }
    method invert(--> List) { %!elems.values.map: { ( .value => .key ) } }

    method new(*@args --> Baggy) {
        my %e;
        # need explicit signature because of #119609
        -> $_ { (%e{$_.WHICH} //= ($_ => 0)).value++ } for @args;
        self.bless(:elems(%e));
    }
    method new-fp(*@pairs --> Baggy) {
        my %e;
        for @pairs {
            when Pair {
                (%e{$_.key.WHICH} //= ($_.key => 0)).value += $_.value.Int;
            }
            default {
                (%e{$_.WHICH} //= ($_ => 0)).value++;
            }
        }
        my @toolow;
        for %e -> $p {
            my $pair := $p.value;
            @toolow.push( $pair.key ) if $pair.value <  0;
            %e.delete_key($p.key)     if $pair.value <= 0;
        }
        fail "Found negative values for {@toolow} in {self.^name}" if @toolow;
        self.bless(:elems(%e));
    }

    method ACCEPTS($other) {
        self.defined
          ?? $other (<+) self && self (<+) $other
          !! $other.^does(self);
    }

    multi method Str(Baggy:D $ : --> Str) {
        ~ %!elems.values.map( {
              .value == 1 ?? .key.gist !! "{.key.gist}({.value})"
          } );
    }
    multi method gist(Baggy:D $ : --> Str) {
        my $name := self.^name;
        ( $name eq 'Bag' ?? 'bag' !! "$name.new" )
        ~ '('
        ~ %!elems.values.map( {
              .value == 1 ?? .key.gist !! "{.key.gist}({.value})"
          } ).join(', ')
        ~ ')';
    }
    multi method perl(Baggy:D $ : --> Str) {
        '('
        ~ %!elems.values.map( {"{.key.perl}=>{.value}"} ).join(',')
        ~ ").{self.^name}"
    }

    method list() { self.keys }
    method pairs() { %!elems.values }

    method grab ($count = 1) {
        my @grab = ROLLPICKGRAB(self, $count, %!elems.values);
        %!elems{ @grab.map({.WHICH}).grep: { %!elems{$_} && %!elems{$_}.value == 0 } }:delete;
        @grab;
    }
    method grabpairs($count = 1) {
        (%!elems{ %!elems.keys.pick($count) }:delete).list;
    }
    method pick ($count = 1) {
        ROLLPICKGRAB(self, $count, %!elems.values.map: { (.key => .value) });
    }
    method pickpairs ($count = 1) {
        (%!elems{ %!elems.keys.pick($count) }).list;
    }
    method roll ($count = 1) {
        ROLLPICKGRAB(self, $count, %!elems.values, :keep);
    }

    sub ROLLPICKGRAB ($self, $count, @pairs is rw, :$keep) is hidden_from_backtrace {
        my $total = $self.total;
        my $todo  = $count ~~ Num
          ?? $total min $count
          !! ($count ~~ Whatever ?? ( $keep ?? $Inf !! $total ) !! $count);

        map {
            my $rand = $total.rand.Int;
            my $seen = 0;
            my $selected;
            for @pairs -> $pair {
                next if ( $seen += $pair.value ) <= $rand;

                $selected = $pair.key;
                last if $keep;

                $pair.value--;
                $total--;
                last;
            }
            $selected;
        }, 1 .. $todo;
    }

    proto method classify-list(|) { * }
    multi method classify-list( &test, *@list ) {
        fail 'Cannot .classify an infinite list' if @list.infinite;
        if @list {

            # multi-level classify
            if test(@list[0]) ~~ List {
                for @list -> $l {
                    my @keys  = test($l);
                    my $last := @keys.pop;
                    my $bag   = self;
                    $bag = $bag{$_} //= self.new for @keys;
                    $bag{$last}++;
                }
            }

            # just a simple classify
            else {
                self{test $_}++ for @list;
            }
        }
        self;
    }
    multi method classify-list( %test, *@list ) {
        samewith( { %test{$^a} }, @list );
    }
    multi method classify-list( @test, *@list ) {
        samewith( { @test[$^a] }, @list );
    }

    proto method categorize-list(|) { * }
    multi method categorize-list( &test, *@list ) {
        fail 'Cannot .categorize an infinite list' if @list.infinite;
        if @list {

            # multi-level categorize
            if test(@list[0])[0] ~~ List {
                for @list -> $l {
                    for test($l) -> $k {
                        my @keys  = @($k);
                        my $last := @keys.pop;
                        my $bag   = self;
                        $bag = $bag{$_} //= self.new for @keys;
                        $bag{$last}++;
                    }
                }
            }

            # just a simple categorize
            else {
                for @list -> $l {
                    self{$_}++ for test($l);
                }
            }
        }
        self;
    }
    multi method categorize-list( %test, *@list ) {
        samewith( { %test{$^a} }, @list );
    }
    multi method categorize-list( @test, *@list ) {
        samewith( { @test[$^a] }, @list );
    }
}

# vim: ft=perl6 expandtab sw=4
