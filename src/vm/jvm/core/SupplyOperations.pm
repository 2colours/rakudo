# Operations we can do on Supplies. Note, many of them need to compose
# the Supply role into classes they create along the way, so they must
# be declared outside of Supply.

my class SupplyOperations is repr('Uninstantiable') {
    # Private versions of the methods to relay events to subscribers, used in
    # implementing various operations.
    my role PrivatePublishing {
        method !more(\msg) {
            for self.tappers {
                .more().(msg)
            }
            Nil;
        }

        method !done() {
            for self.tappers {
                if .done { .done().() }
            }
            Nil;
        }

        method !quit($ex) {
            for self.tappers {
                if .quit { .quit().($ex) }
            }
            Nil;
        }
    }
    
    method for(*@values, :$scheduler = $*SCHEDULER) {
        my class ForSupply does Supply {
            has @!values;
            has $!scheduler;

            submethod BUILD(:@!values, :$!scheduler) {}

            method tap(|c) {
                my $sub = self.Supply::tap(|c);
                $!scheduler.cue(
                    {
                        for @!values -> \val {
                            $sub.more().(val);
                        }
                        if $sub.done -> $l { $l() }
                    },
                    :catch(-> $ex { if $sub.quit -> $t { $t($ex) } })
                );
                $sub
            }
        }
        ForSupply.new(:@values, :$scheduler)
    }

    method interval($interval, $delay = 0, :$scheduler = $*SCHEDULER) {
        my class IntervalSupply does Supply {
            has $!scheduler;
            has $!interval;
            has $!delay;

            submethod BUILD(:$!scheduler, :$!interval, :$!delay) {}

            method tap(|c) {
                my $sub = self.Supply::tap(|c);
                $!scheduler.cue(
                    {
                        state $i = 0;
                        $sub.more().($i++);
                    },
                    :every($!interval), :in($!delay)
                );
                $sub
            }
        }
        IntervalSupply.new(:$interval, :$delay, :$scheduler)
    }

    method do($a, &side_effect) {
        on -> $res {
            $a => sub (\val) { side_effect(val); $res.more(val) }
        }
    }
    
    method grep(Supply $a, &filter) {
        my class GrepSupply does Supply does PrivatePublishing {
            has $!source;
            has &!filter;
            
            submethod BUILD(:$!source, :&!filter) { }
            
            method tap(|c) {
                my $sub = self.Supply::tap(|c);
                my $tap = $!source.tap( -> \val {
                      if (&!filter(val)) { self!more(val) }
                  },
                  done => { self!done(); },
                  quit => -> $ex { self!quit($ex) }
                );
                $sub
            }
        }
        GrepSupply.new(:source($a), :&filter)
    }
    
    method map(Supply $a, &mapper) {
        my class MapSupply does Supply does PrivatePublishing {
            has $!source;
            has &!mapper;
            
            submethod BUILD(:$!source, :&!mapper) { }
            
            method tap(|c) {
                my $sub = self.Supply::tap(|c);
                my $tap = $!source.tap( -> \val {
                      self!more(&!mapper(val))
                  },
                  done => { self!done(); },
                  quit => -> $ex { self!quit($ex) });
                $sub
            }
        }
        MapSupply.new(:source($a), :&mapper)
    }
    
    method merge(Supply $a, Supply $b) {
        my $dones = 0;
        on -> $res {
            $a => {
                more => sub ($val) { $res.more($val) },
                done => {
                    $res.done() if ++$dones == 2;
                }
            },
            $b => {
                more => sub ($val) { $res.more($val) },
                done => {
                    $res.done() if ++$dones == 2;
                }
            }
        }
    }
    
    method zip(Supply $a, Supply $b, &with = &infix:<,>) {
        my @as;
        my @bs;
        on -> $res {
            $a => sub ($val) {
                @as.push($val);
                if @as && @bs {
                    $res.more(with(@as.shift, @bs.shift));
                }
            },
            $b => sub ($val) {
                @bs.push($val);
                if @as && @bs {
                    $res.more(with(@as.shift, @bs.shift));
                }
            }
        }
    }
}
