my class List { ... }

my class ListIter { # declared in BOOTSTRAP
    # class ListIter is Iterator {
    #   has Mu $!reified;      # return value for already-reified iterator
    #   has Mu $!nextiter;     # next iterator in sequence, if any
    #   has Mu $!rest;         # VM's array of elements remaining to be reified
    #   has Mu $!list;         # List object associated with this iterator

    method reify($n, :$sink) {
        unless nqp::isconcrete($!reified) {
            my $eager := nqp::p6bool(nqp::istype($n, Whatever));
            my $flattens := nqp::p6bool(nqp::isconcrete($!list)) && $!list.flattens;
            my int $max = 100_000;
            my int $count;
            my $rpa := nqp::list();
            if $eager {
                $count = $max;
                nqp::setelems($rpa, 5);  # this number is highly speculative
            }
            else {
                $count = nqp::unbox_i(nqp::istype($n, Int) ?? $n !! $n.Int);
                $max = $count if $count > $max;
                nqp::setelems($rpa, $count);
            }
            nqp::setelems($rpa, 0);
            my int $index;
            my $want_types := $flattens
                ?? nqp::list(Iterable, Parcel)
                !! nqp::list(Iterable);
            nqp::p6shiftpush($rpa, $!rest, nqp::elems($!rest))
                if nqp::istype($!list, LoL);
            while $!rest && (nqp::elems($rpa) < $count) {
                $index = nqp::p6arrfindtypes($!rest, $want_types, 0, $max);
                nqp::p6shiftpush($rpa, $!rest, $index);
                if $!rest && (nqp::elems($rpa) < $count) {
                    my Mu $x := nqp::shift($!rest);
                    if nqp::isconcrete($x) {
                        SEQ(nqp::unshift($!rest, $x); last) if $eager && $x.infinite;
                        $x := $x.iterator.reify(
                                  $eager
                                    ?? Whatever
                                    !! nqp::p6box_i($count - nqp::elems($rpa)),
                                  :$sink)
                            if nqp::istype($x, Iterable);
                        nqp::splice($!rest,nqp::getattr($x,Parcel,'$!storage'),0,0)
                          if nqp::isconcrete($x);

                    }
                    elsif nqp::not_i(nqp::istype($x, Nil)) {
                        nqp::push($rpa, $x);
                    }
                }
            }
            my $reified := nqp::p6parcel($rpa, Any);
            nqp::bindattr(self, ListIter, '$!nextiter', nqp::p6listiter($!rest, $!list))
                if $!rest;
            $reified := $!list.REIFY($reified, $!nextiter) if nqp::isconcrete($!list);
            nqp::push( nqp::getattr($reified, Parcel, '$!storage'), $!nextiter)
                if $!rest;
            nqp::bindattr(self, ListIter, '$!reified', $reified);
            # free up $!list and $!rest
            nqp::bindattr(self, ListIter, '$!list', Mu);
            nqp::bindattr(self, ListIter, '$!rest', Mu);
        }
        $!reified;
    }

    multi method infinite(ListIter:D:) {
        $!rest
          ?? nqp::istype(nqp::atpos($!rest, 0), Iterable)
             && nqp::atpos($!rest,0).infinite
             || Nil
          !! False
    }

    method iterator() { self }
    method nextiter() { $!nextiter }

    multi method DUMP(ListIter:D: :$indent-step = 4, :%ctx?) {
        return DUMP(self, :$indent-step) unless %ctx;

        my $flags    := ("\x221e" if self.infinite);
        my Mu $attrs := nqp::list();
        nqp::push($attrs, '$!list'    );
        nqp::push($attrs,  $!list     );
        nqp::push($attrs, '$!reified' );
        nqp::push($attrs,  $!reified  );
        nqp::push($attrs, '$!nextiter');
        nqp::push($attrs,  $!nextiter );
        nqp::push($attrs, '$!rest'    );
        nqp::push($attrs,  $!rest     );
        self.DUMP-OBJECT-ATTRS($attrs, :$indent-step, :%ctx, :$flags);
    }
}

# vim: ft=perl6 expandtab sw=4
