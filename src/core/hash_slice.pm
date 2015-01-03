# all sub postcircumfix {} candidates here please

proto sub postcircumfix:<{ }>(|) { * }

# %h<key>
multi sub postcircumfix:<{ }>( \SELF, \key ) is rw {
    SELF.at_key(key);
}
multi sub postcircumfix:<{ }>(\SELF, \key, Mu \ASSIGN) is rw {
    SELF.assign_key(key, ASSIGN);
}
multi sub postcircumfix:<{ }>(\SELF, \key, Mu :$BIND! is parcel) is rw {
    SELF.bind_key(key, $BIND);
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$SINK!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$SINK, |%other );
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$delete!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$delete, |%other );
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$exists!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$exists, |%other );
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$kv!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$kv, |%other );
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$p!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$p, |%other );
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$k!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$k, |%other );
}
multi sub postcircumfix:<{ }>( \SELF, \key, :$v!, *%other ) is rw {
    SLICE_ONE( SELF, key, False, :$v, |%other );
}

# %h<a b c>
multi sub postcircumfix:<{ }>( \SELF, Positional \key ) is rw {
    nqp::iscont(key)
      ?? SELF.at_key(key)
      !! key.map({ SELF{$_} }).eager.Parcel;
}
multi sub postcircumfix:<{ }>(\SELF, Positional \key, Mu \ASSIGN) is rw {
    (nqp::iscont(key)
      ?? SELF.at_key(key)
      !! key.map({ SELF{$_} }).eager.Parcel) = ASSIGN
}
multi sub postcircumfix:<{ }>(\SELF, Positional \key, :$BIND!) is rw {
    X::Bind::Slice.new(type => SELF.WHAT).throw;
}
multi sub postcircumfix:<{ }>(\SELF,Positional \key, :$SINK!,*%other) is rw {
    SLICE_MORE( SELF, \key, False, :$SINK, |%other );
}
multi sub postcircumfix:<{ }>(\SELF,Positional \key, :$delete!,*%other) is rw {
    SLICE_MORE( SELF, \key, False, :$delete, |%other );
}
multi sub postcircumfix:<{ }>(\SELF,Positional \key, :$exists!,*%other) is rw {
    SLICE_MORE( SELF, \key, False, :$exists, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Positional \key, :$kv!, *%other) is rw {
    SLICE_MORE( SELF, \key, False, :$kv, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Positional \key, :$p!, *%other) is rw {
    SLICE_MORE( SELF, \key, False, :$p, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Positional \key, :$k!, *%other) is rw {
    SLICE_MORE( SELF, \key, False, :$k, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Positional \key, :$v!, *%other) is rw {
    SLICE_MORE( SELF, \key, False, :$v, |%other );
}

# %h{*}
multi sub postcircumfix:<{ }>( \SELF, Whatever ) is rw {
    SELF{SELF.keys};
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, Mu \ASSIGN) is rw {
    SELF{SELF.keys} = ASSIGN;
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$BIND!) is rw {
    X::Bind::Slice.new(type => SELF.WHAT).throw;
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$SINK!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$SINK, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$delete!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$delete, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$exists!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$exists, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$kv!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$kv, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$p!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$p, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$k!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$k, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, Whatever, :$p!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$p, |%other );
}

# %h{}
multi sub postcircumfix:<{ }>( \SELF ) is rw {
    SELF;
}
multi sub postcircumfix:<{ }>(\SELF, :$BIND!) is rw {
    X::Bind::ZenSlice.new(type => SELF.WHAT).throw;
}
multi sub postcircumfix:<{ }>(\SELF, :$SINK!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$SINK, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, :$delete!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$delete, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, :$exists!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$exists, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, :$kv!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$kv, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, :$p!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$p, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, :$k!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$k, |%other );
}
multi sub postcircumfix:<{ }>(\SELF, :$p!, *%other) is rw {
    SLICE_MORE( SELF, SELF.keys, False, :$p, |%other );
}

# %h{;}
multi sub postcircumfix:<{ }> (\SELF is rw, LoL \keys, *%adv) is rw {
    if keys > 1 {
        postcircumfix:<{ }>(SELF, keys[0], :kv).map(-> \key, \value {
            if [||] %adv<kv p k> {
                map %adv<kv> ?? -> \key2, \value2 { LoL.new(key, |key2), value2 } !!
                    %adv<p>  ?? {; LoL.new(key, |.key) => .value } !!
                    # .item so that recursive calls don't map the LoL's elems
                    %adv<k>  ?? { LoL.new(key, |$_).item } !!
                    *, postcircumfix:<{ }>(value, LoL.new(|keys[1..*]), |%adv);
            } else {
                postcircumfix:<{ }>(value, LoL.new(|keys[1..*]), |%adv);
            }
        }).eager.Parcel;
    } else {
        postcircumfix:<{ }>(SELF, keys[0].elems > 1 ?? keys[0].list !! keys[0] , |%adv);
    }
}
multi sub postcircumfix:<{ }> (\SELF is rw, LoL \keys, Mu \assignee, *%adv) is rw {
    if keys > 1 {
        postcircumfix:<{ }>(SELF, keys, |%adv) = assignee;
    } else {
        postcircumfix:<{ }>(SELF, keys[0], assignee, |%adv);
    }
}

# vim: ft=perl6 expandtab sw=4
