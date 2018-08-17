my class X::Invalid::ComputedValue { ... };

my class Hash { # declared in BOOTSTRAP
    # my class Hash is Map
    #     has Mu $!descriptor;

    multi method WHICH(Hash:D:) { self.Mu::WHICH }
    multi method Hash(Hash:) {
        self
    }
    multi method Map(Hash:U:) { Map }
    multi method Map(Hash:D: :$view) {
        nqp::if(
          $view,
          # Agreeing that the Hash won't be changed after the .Map
          nqp::p6bindattrinvres(
            nqp::create(Map), Map, '$!storage',
            nqp::getattr(self,Map,'$!storage')
          ),
          nqp::create(Map).STORE(self, :initialize)
        )
    }
    method clone(Hash:D:) is raw {
        nqp::p6bindattrinvres(
          nqp::p6bindattrinvres(
            nqp::create(self),Map,'$!storage',
            nqp::clone(nqp::getattr(self,Map,'$!storage'))),
          Hash, '$!descriptor', nqp::isnull($!descriptor) ?? (nqp::null) !! nqp::clone($!descriptor))
    }

    method !AT_KEY_CONTAINER(Str:D \key) is raw {
        nqp::p6scalarfromcertaindesc(ContainerDescriptor::BindHashPos.new($!descriptor, self, key))
    }

    multi method AT-KEY(Hash:D: Str:D \key) is raw {
        nqp::ifnull(
          nqp::atkey(nqp::getattr(self,Map,'$!storage'),key),
          self!AT_KEY_CONTAINER(key)
        )
    }
    multi method AT-KEY(Hash:D: \key) is raw {
        nqp::ifnull(
          nqp::atkey(nqp::getattr(self,Map,'$!storage'),key.Str),
          self!AT_KEY_CONTAINER(key.Str)
        )
    }

    proto method STORE_AT_KEY(|) {*}
    multi method STORE_AT_KEY(Str:D \key, Mu \x --> Nil) {
        nqp::bindkey(
          nqp::getattr(self,Map,'$!storage'),
          nqp::unbox_s(key),
          nqp::p6scalarwithvalue($!descriptor, x),
        )
    }
    multi method STORE_AT_KEY(\key, Mu \x --> Nil) {
        nqp::bindkey(
          nqp::getattr(self,Map,'$!storage'),
          nqp::unbox_s(key.Str),
          nqp::p6scalarwithvalue($!descriptor, x),
        )
    }
    method !STORE_MAP(\map --> Nil) {
        nqp::stmts(
          (my $iter := nqp::iterator(nqp::getattr(map,Map,'$!storage'))),
          nqp::while(
            $iter,
            self.STORE_AT_KEY(
              nqp::iterkey_s(nqp::shift($iter)),nqp::iterval($iter)
            )
          )
        )
    }
    method STORE(\to_store) {
        my $temp := nqp::p6bindattrinvres(
          nqp::clone(self),   # make sure we get a possible descriptor as well
          Map,
          '$!storage',
          my $storage := nqp::hash
        );
        my $iter := to_store.iterator;
        my Mu $x;
        my Mu $y;

        nqp::until(
          nqp::eqaddr(($x := $iter.pull-one),IterationEnd),
          nqp::if(
            nqp::istype($x,Pair),
            $temp.STORE_AT_KEY(
              nqp::getattr(nqp::decont($x),Pair,'$!key'),
              nqp::getattr(nqp::decont($x),Pair,'$!value')
            ),
            nqp::if(
              (nqp::istype($x,Map) && nqp::not_i(nqp::iscont($x))),
              $temp!STORE_MAP($x),
              nqp::if(
                nqp::eqaddr(($y := $iter.pull-one),IterationEnd),
                nqp::if(
                  nqp::istype($x,Failure),
                  $x.throw,
                  X::Hash::Store::OddNumber.new(
                    found => nqp::add_i(nqp::mul_i(nqp::elems($storage),2),1),
                    last  => $x
                  ).throw
                ),
                $temp.STORE_AT_KEY($x,$y)
              )
            )
          )
        );

        nqp::p6bindattrinvres(self,Map,'$!storage',$storage)
    }

    multi method ASSIGN-KEY(Hash:D: Str:D \key, Mu \assignval) is raw {
        my \storage := nqp::getattr(self,Map,'$!storage');
        nqp::p6assign(
          nqp::ifnull(
            nqp::atkey(storage, key),
            nqp::bindkey(storage, key,
              nqp::p6bindattrinvres(nqp::create(Scalar), Scalar, '$!descriptor', $!descriptor))),
          assignval)
    }
    multi method ASSIGN-KEY(Hash:D: \key, Mu \assignval) is raw {
        my str $key = key.Str;
        my \storage := nqp::getattr(self, Map, '$!storage');
        nqp::p6assign(
          nqp::ifnull(
            nqp::atkey(storage, $key),
            nqp::bindkey(storage, $key,
              nqp::p6bindattrinvres(nqp::create(Scalar), Scalar, '$!descriptor', $!descriptor))),
          assignval)
    }

    proto method BIND-KEY(|) {*}
    multi method BIND-KEY(Hash:D: \key, Mu \bindval) is raw {
        nqp::bindkey(
          nqp::getattr(self,Map,'$!storage'),
          key.Str,
          bindval
        )
    }
    multi method BIND-KEY(Hash:D: Str:D \key, Mu \bindval) is raw {
        nqp::bindkey(
          nqp::getattr(self,Map,'$!storage'),
          key,
          bindval
        )
    }

    multi method DELETE-KEY(Hash:U: --> Nil) { }
    multi method DELETE-KEY(Hash:D: Str:D \key) {
        my \storage := nqp::getattr(self, Map, '$!storage');
        nqp::if(
          nqp::existskey(storage, nqp::unbox_s(key)),
          nqp::stmts(
            (my \value := nqp::atkey(storage,nqp::unbox_s(key))),
            nqp::deletekey(storage,nqp::unbox_s(key)),
            value
          ),
          nqp::p6scalarfromcertaindesc($!descriptor)
        )
    }
    multi method DELETE-KEY(Hash:D: \key) {
        my \storage := nqp::getattr(self, Map, '$!storage');
        my str $key = nqp::unbox_s(key.Str);
        nqp::if(
          nqp::existskey(storage,$key),
          nqp::stmts(
            (my \value = nqp::atkey(storage,$key)),
            nqp::deletekey(storage,$key),
            value
          ),
          nqp::p6scalarfromcertaindesc($!descriptor)
        )
    }

    multi method perl(Hash:D \SELF:) {
        SELF.perlseen(self.^name, {
            '$' x nqp::iscont(SELF)  # self is always deconted
            ~ '{' ~ self.sort.map({.perl}).join(', ') ~ '}'
        })
    }

    multi method gist(Hash:D:) {
        self.gistseen(self.^name, {
            '{' ~
            self.sort.map({
                state $i = 0;
                ++$i == 101 ?? '...'
                    !! $i == 102 ?? last()
                        !! .gist
            }).join(', ')
            ~ '}'
        })
    }

    multi method DUMP(Hash:D: :$indent-step = 4, :%ctx) {
        nqp::if(
          %ctx,
          self.DUMP-OBJECT-ATTRS(
            nqp::list(
              '$!descriptor',
              $!descriptor,
              '$!storage',
              nqp::getattr(self,Map,'$!storage')
            ),
            :$indent-step,
            :%ctx
          ),
          DUMP(self, :$indent-step)
        )
    }

    # introspection
    method name() {
        nqp::isnull($!descriptor) ?? Nil !! $!descriptor.name
    }
    method keyof() {
        Str(Any)
    }
    method of() {
        nqp::isnull($!descriptor) ?? Mu !! $!descriptor.of
    }
    method default() {
        nqp::isnull($!descriptor) ?? Any !! $!descriptor.default
    }
    method dynamic() {
        nqp::isnull($!descriptor) ?? False !! nqp::hllbool($!descriptor.dynamic)
    }

    method push(+values) {
        fail X::Cannot::Lazy.new(:action<push>, :what(self.^name))
          if values.is-lazy;

        my $previous;
        my int $has_previous = 0;

        nqp::if(
          $has_previous,
          nqp::stmts(
            self!_push_construct($previous,$_),
            ($has_previous = 0)
          ),
          nqp::if(
            nqp::istype($_,Pair),
            self!_push_construct(.key,.value),
            nqp::stmts(
              ($previous := $_),
              ($has_previous = 1)
            )
          )
        ) for values;

        warn "Trailing item in {self.^name}.push" if $has_previous;
        self
    }

    method append(+values) {
        fail X::Cannot::Lazy.new(:action<append>, :what(self.^name))
          if values.is-lazy;

        my $previous;
        my int $has_previous = 0;

        nqp::if(
          $has_previous,
          nqp::stmts(
            self!_append_construct($previous,$_),
            ($has_previous = 0)
          ),
          nqp::if(
            nqp::istype($_,Pair),
            self!_append_construct(.key,.value),
            nqp::stmts(
              ($previous := $_),
              ($has_previous = 1)
            )
          )
        ) for values;

        warn "Trailing item in {self.^name}.append" if $has_previous;
        self
    }

    proto method classify-list(|) {*}
    multi method classify-list( &test, \list, :&as ) {
        fail X::Cannot::Lazy.new(:action<classify>) if list.is-lazy;
        my \iter = (nqp::istype(list, Iterable) ?? list !! list.list).iterator;
        my $value := iter.pull-one;
        unless $value =:= IterationEnd {
            my $tested := test($value);

            # multi-level classify
            if nqp::istype($tested, Iterable) {
                my $els = $tested.elems;
                loop {
                    my @keys = @$tested;
                    @keys == $els or X::Invalid::ComputedValue.new(
                            :name<mapper>,
                            :method<classify-list>,
                            :value('an item with different number of elements '
                                ~ 'in it than previous items'),
                            :reason('all values need to have the same number '
                                ~ 'of elements. Mixed-level classification is '
                                ~ 'not supported.'),
                        ).throw;
                    my $last := @keys.pop;
                    my $hash  = self;
                    $hash = $hash{$_} //= self.new for @keys;
                    $hash{$last}.push(&as ?? as($value) !! $value);
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    $tested := test($value);
                };
            }
            # just a simple classify
            else {
                loop {
                    self{$tested}.push(&as ?? as($value) !! $value);
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    nqp::istype(($tested := test($value)), Iterable)
                        and X::Invalid::ComputedValue.new(
                            :name<mapper>,
                            :method<classify-list>,
                            :value('an item with different number of elements '
                                ~ 'in it than previous items'),
                            :reason('all values need to have the same number '
                                ~ 'of elements. Mixed-level classification is '
                                ~ 'not supported.'),
                        ).throw;
                };
            }
        }
        self;
    }
    multi method classify-list( %test, |c ) {
        self.classify-list( { %test{$^a} }, |c );
    }
    multi method classify-list( @test, |c ) {
        self.classify-list( { @test[$^a] }, |c );
    }
    multi method classify-list(&test, **@list, |c) {
        self.classify-list(&test, @list, |c);
    }

    proto method categorize-list(|) {*}
    multi method categorize-list( &test, \list, :&as ) {
       fail X::Cannot::Lazy.new(:action<categorize>) if list.is-lazy;
        my \iter = (nqp::istype(list, Iterable) ?? list !! list.list).iterator;
        my $value := iter.pull-one;
        unless $value =:= IterationEnd {
            my $tested := test($value);

            # multi-level categorize
            if nqp::istype($tested[0],Iterable) {
                my $els = $tested[0].elems;
                loop {
                    for $tested.cache -> $cat {
                       my @keys = @$cat or next;
                       my $last := @keys.pop;
                       my $hash  = self;
                       $hash = $hash{$_} //= self.new for @keys;
                       $hash{$last}.push(&as ?? as($value) !! $value);
                    }

                    last if ($value := iter.pull-one) =:= IterationEnd;
                    $tested := test($value);

                    nqp::istype($tested[0],Iterable)
                        and $els == $tested[0]
                        or X::Invalid::ComputedValue.new(
                            :name<mapper>,
                            :method<categorize-list>,
                            :value('an item with different number of elements '
                                ~ 'in it than previous items'),
                            :reason('all values need to have the same number '
                                ~ 'of elements. Mixed-level classification is '
                                ~ 'not supported.'),
                        ).throw;
                }
            }
            # simple categorize
            else {
                loop {
                    self{$_}.push(&as ?? as($value) !! $value)
                        for @$tested;
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    nqp::istype(($tested := test($value))[0], Iterable)
                        and X::Invalid::ComputedValue.new(
                            :name<mapper>,
                            :method<categorize-list>,
                            :value('an item with different number of elements '
                                ~ 'in it than previous items'),
                            :reason('all values need to have the same number '
                                ~ 'of elements. Mixed-level classification is '
                                ~ 'not supported.'),
                        ).throw;
                };
            }
       }
       self;
    }
    multi method categorize-list( %test, |c ) {
        self.categorize-list( { %test{$^a} }, |c );
    }
    multi method categorize-list( @test, |c ) {
        self.categorize-list( { @test[$^a] }, |c );
    }
    multi method categorize-list( &test, **@list, |c ) {
        self.categorize-list( &test, @list, |c );
    }

    # push a value onto a hash slot, constructing an array if necessary
    method !_push_construct(Mu $key, Mu \value --> Nil) {
        self.EXISTS-KEY($key)
          ?? self.AT-KEY($key).^isa(Array)
            ?? self.AT-KEY($key).push(value)
            !! self.ASSIGN-KEY($key,[self.AT-KEY($key),value])
          !! self.ASSIGN-KEY($key,value)
    }

    # append values into a hash slot, constructing an array if necessary
    method !_append_construct(Mu $key, Mu \value --> Nil) {
        self.EXISTS-KEY($key)
          ?? self.AT-KEY($key).^isa(Array)
            ?? self.AT-KEY($key).append(|value)
            !! self.ASSIGN-KEY($key,[|self.AT-KEY($key),|value])
          !! self.ASSIGN-KEY($key,value)
    }

    my role TypedHash[::TValue] does Associative[TValue] {
        # These ASSIGN-KEY candidates are only needed because of:
        #   my Int %h; try %h<a> = "foo"; dd %h
        # leaving an uninitialized Int for key <a> in the hash.  If
        # we could live with that, then these candidates can be
        # removed.  However, there are spectest covering this
        # eventuality, so to appease roast, we need these.
        multi method ASSIGN-KEY(::?CLASS:D: Str:D \key, Mu \assignval) is raw {
            my \storage := nqp::getattr(self, Map, '$!storage');
            nqp::if(
              nqp::existskey(storage, nqp::unbox_s(key)),
              (nqp::atkey(storage, nqp::unbox_s(key)) = assignval),
              nqp::bindkey(
                storage,
                nqp::unbox_s(key),
                nqp::p6scalarfromdesc(
                  nqp::getattr(self,Hash,'$!descriptor')) = assignval
              )
            )
        }
        multi method ASSIGN-KEY(::?CLASS:D: \key, Mu \assignval) is raw {
            my \storage := nqp::getattr(self, Map, '$!storage');
            my str $key = nqp::unbox_s(key.Str);
            nqp::if(
              nqp::existskey(storage,$key),
              (nqp::atkey(storage,$key) = assignval),
              nqp::bindkey(
                storage,
                nqp::unbox_s(key.Str),
                nqp::p6scalarfromdesc(
                  nqp::getattr(self,Hash,'$!descriptor')) = assignval
              )
            )
        }
        multi method perl(::?CLASS:D \SELF:) {
            SELF.perlseen('Hash', {
                '$' x nqp::iscont(SELF)  # self is always deconted
                ~ (self.elems
                   ?? "(my {TValue.perl} % = {
                        self.sort.map({.perl}).join(', ')
                       })"
                   !! "(my {TValue.perl} %)"
                  )
            })
        }
    }
    my role TypedHash[::TValue, ::TKey] does Associative[TValue] {
        method keyof () { TKey }
        method AT-KEY(::?CLASS:D: TKey \key) is raw {
            my \storage := nqp::getattr(self, Map, '$!storage');
            my str $which = nqp::unbox_s(key.WHICH);
            nqp::if(
              nqp::existskey(storage,$which),
              nqp::getattr(nqp::atkey(storage,$which),Pair,'$!value'),
              nqp::p6scalarfromdesc(ContainerDescriptor::BindObjHashKey.new(
                nqp::getattr(self,Hash,'$!descriptor'),self,key,$which,Pair)
              )
            )
        }

        method STORE_AT_KEY(TKey \key, TValue \x --> Nil) {
            nqp::bindkey(
              nqp::getattr(self,Map,'$!storage'),
              nqp::unbox_s(key.WHICH),
              Pair.new(
                key,
                nqp::p6scalarfromdesc(nqp::getattr(self,Hash,'$!descriptor'))
                = x
              )
            )
        }

        method ASSIGN-KEY(::?CLASS:D: TKey \key, TValue \assignval) is raw {
            my \storage := nqp::getattr(self, Map, '$!storage');
            my str $which = nqp::unbox_s(key.WHICH);
            nqp::if(
              nqp::existskey(storage,$which),
              (nqp::getattr(nqp::atkey(storage,$which),Pair,'$!value')
                = assignval),
              nqp::getattr(
                (nqp::bindkey(storage,$which,
                  Pair.new(key,nqp::p6scalarfromdesc(
                    nqp::getattr(self,Hash,'$!descriptor')) = assignval)
                )),
                Pair,
                '$!value'
              )
            )
        }

        method BIND-KEY(TKey \key, TValue \bindval) is raw {
            nqp::getattr(
              nqp::bindkey(
                nqp::getattr(self,Map,'$!storage'),
                key.WHICH,
                Pair.new(key,bindval)
              ),
              Pair,
              '$!value'
            )
        }

        method EXISTS-KEY(TKey \key) {
            nqp::hllbool(
              nqp::existskey(nqp::getattr(self,Map,'$!storage'),key.WHICH)
            )
        }

        method DELETE-KEY(TKey \key) {
            my \storage := nqp::getattr(self, Map, '$!storage');
            my str $which = key.WHICH;
            nqp::if(
              nqp::existskey(storage,$which),
              nqp::stmts(
                (my \value =
                  nqp::getattr(nqp::atkey(storage,$which),Pair,'$!value')),
                nqp::deletekey(storage,$which),
                value
              ),
              TValue
            )
        }

        method FLATTENABLE_HASH() {
            nqp::stmts(
              (my $flattened := nqp::hash),
              nqp::if(
                (my $iter := nqp::iterator(nqp::getattr(self,Map,'$!storage'))),
                nqp::while(
                  $iter,
                  nqp::bindkey(
                    $flattened,
                    nqp::if(
                      nqp::istype(
                        (my $key := nqp::getattr(
                          nqp::iterval(nqp::shift($iter)),
                          Pair,
                          '$!key'
                        )),
                        Str,
                      ),
                      $key,
                      $key.Str
                    ),
                    nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                  )
                )
              ),
              $flattened
            )
        }

        method IterationBuffer() {
            my \storage := nqp::getattr(self, Map, '$!storage');
            my \buffer  := nqp::create(IterationBuffer);
            nqp::if(
              nqp::elems(storage),
              nqp::stmts(
                (my \iterator := nqp::iterator(storage)),
                nqp::setelems(buffer,nqp::elems(storage)),
                (my int $i = -1),
                nqp::while(
                  iterator,
                  nqp::bindpos(buffer,($i = nqp::add_i($i,1)),
                    nqp::iterval(nqp::shift(iterator)))
                )
              )
            );
            buffer
        }

        multi method head(::?CLASS:D:) {
            my \storage := nqp::getattr(self, Map, '$!storage');
            nqp::if(
              nqp::elems(storage),
              nqp::iterval(
                nqp::shift(nqp::iterator(storage))
              ),
              Nil
            )
        }

        method keys() {
            Seq.new(class :: does Rakudo::Iterator::Mappy {
                method pull-one() {
                    nqp::if(
                      $!iter,
                      nqp::getattr(nqp::iterval(nqp::shift($!iter)),
                        Pair,'$!key'),
                      IterationEnd
                    )
                 }
            }.new(self))
        }
        method values() {
            Seq.new(class :: does Rakudo::Iterator::Mappy {
                method pull-one() {
                    nqp::if(
                      $!iter,
                      nqp::getattr(nqp::iterval(nqp::shift($!iter)),
                        Pair,'$!value'),
                      IterationEnd
                    )
                 }
            }.new(self))
        }
        method kv() {
            Seq.new(Rakudo::Iterator.Mappy-kv-from-pairs(self))
        }
        method iterator() { Rakudo::Iterator.Mappy-values(self) }
        method antipairs() {
            Seq.new(class :: does Rakudo::Iterator::Mappy {
                method pull-one() {
                    nqp::if(
                      $!iter,
                      nqp::iterval(nqp::shift($!iter)).antipair,
                      IterationEnd
                    )
                 }
            }.new(self))
        }
        multi method roll(::?CLASS:D:) {
            my \storage := nqp::getattr(self, Map, '$!storage');
            nqp::if(
              nqp::elems(storage),
              nqp::stmts(
                (my int $i =
                  nqp::add_i(nqp::floor_n(nqp::rand_n(nqp::elems(storage))),1)),
                (my \iter := nqp::iterator(storage)),
                nqp::while(
                  nqp::shift(iter) && ($i = nqp::sub_i($i,1)),
                  nqp::null
                ),
                nqp::iterval(iter)
              ),
              Nil
            )
        }
        multi method roll(::?CLASS:D: Callable:D $calculate) {
            self.roll( $calculate(self.elems) )
        }
        multi method roll(::?CLASS:D: Whatever $) { self.roll(Inf) }
        multi method roll(::?CLASS:D: $count) {
            Seq.new(nqp::if(
              $count > 0 && nqp::elems(nqp::getattr(self,Map,'$!storage')),
              class :: does Iterator {
                  has $!storage;
                  has $!keys;
                  has $!count;

                  method !SET-SELF(\hash,\count) {
                      nqp::stmts(
                        ($!storage := nqp::getattr(hash,Map,'$!storage')),
                        ($!count = $count),
                        (my $iter := nqp::iterator($!storage)),
                        ($!keys := nqp::list_s),
                        nqp::while(
                          $iter,
                          nqp::push_s($!keys,nqp::iterkey_s(nqp::shift($iter)))
                        ),
                        self
                      )
                  }
                  method new(\h,\c) { nqp::create(self)!SET-SELF(h,c) }
                  method pull-one() {
                      nqp::if(
                        $!count,
                        nqp::stmts(
                          --$!count,  # must be HLL to handle Inf
                          nqp::atkey(
                            $!storage,
                            nqp::atpos_s(
                              $!keys,
                              nqp::floor_n(nqp::rand_n(nqp::elems($!keys)))
                            )
                          )
                        ),
                        IterationEnd
                      )
                  }
                  method is-lazy() { $!count == Inf }
              }.new(self,$count),
              Rakudo::Iterator.Empty
            ))
        }
        multi method perl(::?CLASS:D \SELF:) {
            SELF.perlseen('Hash', {
                my $TKey-perl   := TKey.perl;
                my $TValue-perl := TValue.perl;
                $TKey-perl eq 'Any' && $TValue-perl eq 'Mu'
                  ?? ( '$(' x nqp::iscont(SELF)
                        ~ ':{' ~ SELF.sort.map({.perl}).join(', ') ~ '}'
                        ~ ')' x nqp::iscont(SELF)
                     )
                  !! '$' x nqp::iscont(SELF)
                     ~ (self.elems
                          ?? "(my $TValue-perl %\{$TKey-perl\} = {
                                self.sort.map({.perl}).join(', ')
                             })"
                          !! "(my $TValue-perl %\{$TKey-perl\})"
                     )
            })
        }

        # gotta force capture keys to strings or binder fails
        method Capture() {
            nqp::elems(nqp::getattr(self,Map,'$!storage'))
              ?? do {
                     my $cap := nqp::create(Capture);
                     my $h := nqp::hash();
                     for self.kv -> \k, \v {
                         nqp::bindkey($h,
                           nqp::unbox_s(nqp::istype(k,Str) ?? k !! k.Str),
                           v)
                     }
                     nqp::bindattr($cap,Capture,'%!hash',$h);
                     $cap
                 }
              !! nqp::create(Capture)
        }
        method Map() { self.pairs.Map }
    }

    method ^parameterize(Mu:U \hash, Mu \t, |c) {
        if nqp::isconcrete(t) {
            "Can not parameterize {hash.^name} with {t.perl}"
        }
        elsif c.elems == 0 {
            my $what := hash.^mixin(TypedHash[t]);
            # needs to be done in COMPOSE phaser when that works
            $what.^set_name("{hash.^name}[{t.^name}]");
            $what
        }
        elsif c.elems == 1 {
            my $what := hash.^mixin(TypedHash[t, c[0].WHAT]);
            # needs to be done in COMPOSE phaser when that works
            $what.^set_name("{hash.^name}[{t.^name},{c[0].^name}]");
            $what
        }
        else {
            "Can only type-constrain Hash with [ValueType] or [ValueType,KeyType]"
        }
    }
}

proto sub circumfix:<{ }>(|) {*}
multi sub circumfix:<{ }>(*@elems) { my % = @elems }

# XXX parse dies with 'don't change grammar in the setting, please!'
# with ordinary sub declaration
#sub circumfix:<:{ }>(*@elems) { Hash.^parameterize(Mu,Any).new(@elems) }
BEGIN my &circumfix:<:{ }> = sub (*@e) { Hash.^parameterize(Mu,Any).new(@e) }

proto sub hash(|) {*}
multi sub hash(*%h) { %h }
multi sub hash(*@a, *%h) { my % = flat @a, %h }

# vim: ft=perl6 expandtab sw=4
