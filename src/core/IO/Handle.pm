my class IO::Path { ... }
my class IO::Special { ... }
my class Proc { ... }

# Will be removed together with pipe() and open(:p).
my class Proc::Status {
    has $.exitcode = -1;  # distinguish uninitialized from 0 status
    has $.pid;
    has $.signal;

    method exit {
        DEPRECATED('Proc::Status.exitcode', |<2015.03 2015.09>);
        $!exitcode;
    }

    proto method status(|) { * }
    multi method status($new_status) {
        $!exitcode = $new_status +> 8;
        $!signal   = $new_status +& 0xFF;
    }
    multi method status(Proc::Status:D:)  { ($!exitcode +< 8) +| $!signal }
    multi method Numeric(Proc::Status:D:) { $!exitcode }
    multi method Bool(Proc::Status:D:)    { $!exitcode == 0 }
}

my class IO::Handle does IO {
    has $.path;
    has $!PIO;
    has int $.ins;
    has $.chomp is rw = Bool::True;
    has $.nl    = "\n";
    has int $!pipe;

    method pipe(IO::Handle:D: |c) {
        DEPRECATED('shell() or run() with :in, :out or :err', |<2015.06 2015.09>);
        self.open(:p, :nodepr, |c);
    }

    method open(IO::Handle:D:
      :$p, :$r, :$w, :$x, :$a, :$update,
      :$rw, :$rx, :$ra,
      :$mode is copy,
      :$create is copy,
      :$append is copy,
      :$truncate is copy,
      :$exclusive is copy,
      :$bin,
      :$chomp = True,
      :$enc   = 'utf8',
      :$nl    = "\n",
      :$nodepr,
    ) {

        $mode //= do {
            when so $p { 'pipe' }

            when so ($r && $w) || $rw { $create              = True; 'rw' }
            when so ($r && $x) || $rx { $create = $exclusive = True; 'rw' }
            when so ($r && $a) || $ra { $create = $append    = True; 'rw' }

            when so $r { 'ro' }
            when so $w { $create = $truncate  = True; 'wo' }
            when so $x { $create = $exclusive = True; 'wo' }
            when so $a { $create = $append    = True; 'wo' }

            when so $update { 'rw' }

            default { 'ro' }
        }

        if $!path eq '-' {
            $!path = IO::Special.new:
                what => do given $mode {
                    when 'ro' { '<STDIN>'  }
                    when 'wo' { '<STDOUT>' }
                    default {
                        die "Cannot open standard stream in mode '$_'";
                    }
                }
        }

        if nqp::istype($!path, IO::Special) {
            my $what := $!path.what;
            if $what eq '<STDIN>' {
                $!PIO := nqp::getstdin();
            }
            elsif $what eq '<STDOUT>' {
                $!PIO := nqp::getstdout();
            }
            elsif $what eq '<STDERR>' {
                $!PIO := nqp::getstderr();
            }
            else {
                die "Don't know how to open '$_' especially";
            }
            $!chomp = $chomp;
            nqp::setencoding($!PIO, NORMALIZE_ENCODING($enc)) unless $bin;
            return self;
        }

        fail (X::IO::Directory.new(:$!path, :trying<open>))
          if $!path.e && $!path.d;

        if $mode eq 'pipe' {
            DEPRECATED('shell(...)/run(...) with :in, :out or :err', |<2015.06 2015.09>, :what(':p for pipe')) unless $nodepr;
            $!pipe = 1;

            $!PIO := nqp::syncpipe();
            nqp::shell(
              nqp::unbox_s($!path.Str),
              nqp::unbox_s($*CWD.Str),
              CLONE-HASH-DECONTAINERIZED(%*ENV),
              nqp::null(), $!PIO, nqp::null(),
              nqp::const::PIPE_INHERIT_IN + nqp::const::PIPE_CAPTURE_OUT + nqp::const::PIPE_INHERIT_ERR
            );
        }
        else {
            my $llmode = do given $mode {
                when 'ro' { 'r' }
                when 'wo' { '-' }
                when 'rw' { '+' }
                default { die "Unknown mode '$_'" }
            }

            $llmode = join '', $llmode,
                $create    ?? 'c' !! '',
                $append    ?? 'a' !! '',
                $truncate  ?? 't' !! '',
                $exclusive ?? 'x' !! '';

#?if !moar
            # don't use new modes on anything but MoarVM
            # TODO: check what else can be made to work on Parrot
            #       cf io/utilities.c, Parrot_io_parse_open_flags()
            #          platform/generic/io.c, convert_flags_to_unix()
            #          platform/win32/io.c, convert_flags_to_win32 ()
            $llmode = do given $llmode {
                when 'r'   { 'r' }
                when '-ct' { 'w' }
                when '-ca' { 'wa' }
                default {
                    die "Backend { $*VM.name
                        } does not support opening files in mode '$llmode'";
                }
            }
#?endif

            # TODO: catch error, and fail()
            $!PIO := nqp::open(
              nqp::unbox_s($!path.abspath),
              nqp::unbox_s($llmode),
            );
        }

        $!chomp = $chomp;
        nqp::setinputlinesep($!PIO, nqp::unbox_s($!nl = $nl));
        nqp::setencoding($!PIO, NORMALIZE_ENCODING($enc)) unless $bin;
        self;
    }

    method input-line-separator {
        DEPRECATED("nl",|<2015.03 2015.09>);
        self.nl;
    }

    method nl is rw {
        Proxy.new(
          FETCH => {
              $!nl
          },
          STORE => -> $, $nl is copy {
            nqp::setinputlinesep($!PIO, nqp::unbox_s($!nl = $nl));
          }
        );
    }

    method close(IO::Handle:D:) {
        # TODO:b catch errors
        if $!pipe {
            my $ps = Proc::Status.new;
            $ps.status( nqp::closefh_i($!PIO) ) if nqp::defined($!PIO);
            $!PIO := Mu;
            $ps;
        }
        else {
            nqp::closefh($!PIO) if nqp::defined($!PIO);
            $!PIO := Mu;
            True;
        }
    }

    method eof(IO::Handle:D:) {
        nqp::p6bool(nqp::eoffh($!PIO));
    }

    method get(IO::Handle:D:) {
        return Str if self.eof;

        my Str $x = nqp::p6box_s(nqp::readlinefh($!PIO));
        # XXX don't fail() as long as it's fatal
        # fail('end of file') if self.eof && $x eq '';
        $x.=chomp if $.chomp;
        return Str if self.eof && $x eq '';

        $!ins = $!ins + 1;
        $x;
    }

    method getc(IO::Handle:D:) {
        my $c = nqp::p6box_s(nqp::getcfh($!PIO));
        fail if $c eq '';
        $c;
    }

    proto method words (|) { * }
    # can probably go after GLR
    multi method words(IO::Handle:D: :$eager!, :$close) {
        return self.words(:$close) if !$eager;

        my str $str;
        my int $chars;
        my int $pos;
        my int $left;
        my int $nextpos;
        my Mu $rpa := nqp::list();

        until nqp::eoffh($!PIO) {

#?if moar
            $str   = $str ~ nqp::readcharsfh($!PIO, 65536); # optimize for ASCII
#?endif
#?if !moar
            my Buf $buf := Buf.new;
            nqp::readfh($!PIO, $buf, 65536);
            $str   = $str ~ nqp::unbox_s($buf.decode);
#?endif
            $chars = nqp::chars($str);
            $pos   = nqp::findnotcclass(
              nqp::const::CCLASS_WHITESPACE, $str, 0, $chars);

            while ($left = $chars - $pos) > 0 {
                $nextpos = nqp::findcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, $pos, $left);
                last unless $left = $chars - $nextpos; # broken word

                nqp::push($rpa,
                  nqp::box_s(nqp::substr($str, $pos, $nextpos - $pos), Str) );

                $pos = nqp::findnotcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, $nextpos, $left);
            }

            $str = $pos < $chars ?? nqp::substr($str,$pos) !! '';
        }
        self.close if $close;
        nqp::p6parcel($rpa, Nil);
    }
    multi method words(IO::Handle:D: :$count!, :$close) {
        return self.words(:$close) if !$count;

        my str $str;
        my int $chars;
        my int $pos;
        my int $left;
        my int $nextpos;
        my int $found;

        until nqp::eoffh($!PIO) {

#?if moar
            $str   = $str ~ nqp::readcharsfh($!PIO, 65536); # optimize for ASCII
#?endif
#?if !moar
            my Buf $buf := Buf.new;
            nqp::readfh($!PIO, $buf, 65536);
            $str   = $str ~ nqp::unbox_s($buf.decode);
#?endif
            $chars = nqp::chars($str);
            $pos   = nqp::findnotcclass(
              nqp::const::CCLASS_WHITESPACE, $str, 0, $chars);

            while ($left = $chars - $pos) > 0 {
                $nextpos = nqp::findcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, $pos, $left);
                last unless $left = $chars - $nextpos; # broken word

                $found = $found + 1;

                $pos = nqp::findnotcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, $nextpos, $left);
            }

            $str = $pos < $chars ?? nqp::substr($str,$pos) !! '';
        }
        self.close if $close;
        nqp::box_i($found, Int);
    }
    multi method words(IO::Handle:D: :$close) {
        my str $str;
        my int $chars;
        my int $pos;
        my int $left;
        my int $nextpos;

        gather {
            until nqp::eoffh($!PIO) {

#?if moar
                # optimize for ASCII
                $str   = $str ~ nqp::readcharsfh($!PIO, 65536);
#?endif
#?if !moar
                my Buf $buf := Buf.new;
                nqp::readfh($!PIO, $buf, 65536);
                $str = $str ~ nqp::unbox_s($buf.decode);
#?endif
                $chars = nqp::chars($str);
                $pos   = nqp::findnotcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, 0, $chars);

                while ($left = $chars - $pos) > 0 {
                    $nextpos = nqp::findcclass(
                      nqp::const::CCLASS_WHITESPACE, $str, $pos, $left);
                    last unless $left = $chars - $nextpos; # broken word

                    take
                      nqp::box_s(nqp::substr($str, $pos, $nextpos - $pos), Str);

                    $pos = nqp::findnotcclass(
                      nqp::const::CCLASS_WHITESPACE, $str, $nextpos, $left);
                }

                $str = $pos < $chars ?? nqp::substr($str,$pos) !! '';
            }
            self.close if $close;
        }
    }
    multi method words(IO::Handle:D: $limit, :$eager, :$close) {
        return self.words(:$eager,:$close)
          if nqp::istype($limit,Whatever) or $limit == Inf;

        my str $str;
        my int $chars;
        my int $pos;
        my int $left;
        my int $nextpos;
        my int $count = $limit;
        my Mu $rpa := nqp::list();

        until nqp::eoffh($!PIO) {

#?if moar
            $str   = $str ~ nqp::readcharsfh($!PIO, 65536); # optimize for ASCII
#?endif
#?if !moar
            my Buf $buf := Buf.new;
            nqp::readfh($!PIO, $buf, 65536);
            $str   = $str ~ nqp::unbox_s($buf.decode);
#?endif
            $chars = nqp::chars($str);
            $pos   = nqp::findnotcclass(
              nqp::const::CCLASS_WHITESPACE, $str, 0, $chars);

            while $count and ($left = $chars - $pos) > 0 {
                $nextpos = nqp::findcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, $pos, $left);
                last unless $left = $chars - $nextpos; # broken word

                nqp::push($rpa,
                  nqp::box_s(nqp::substr($str, $pos, $nextpos - $pos), Str) );
                $count = $count - 1;

                $pos = nqp::findnotcclass(
                  nqp::const::CCLASS_WHITESPACE, $str, $nextpos, $left);
            }

            $str = $pos < $chars ?? nqp::substr($str,$pos) !! '';
        }
        self.close if $close;
        nqp::p6parcel($rpa, Nil);
    }

    proto method lines (|) { * }
    # can probably go after GLR
    multi method lines(IO::Handle:D: :$eager!, :$close) {
        return self.lines if !$eager;

        my Mu $rpa := nqp::list();
        if $.chomp {
            until nqp::eoffh($!PIO) {
                nqp::push($rpa, nqp::p6box_s(nqp::readlinefh($!PIO)).chomp );
            }
        }
        else {
            until nqp::eoffh($!PIO) {
                nqp::push($rpa, nqp::p6box_s(nqp::readlinefh($!PIO)) );
            }
        }
        $!ins = nqp::elems($rpa);
        self.close if $close;
        nqp::p6parcel($rpa, Nil);
    }
    multi method lines(IO::Handle:D: :$count!, :$close) {
        return self.lines(:$close) if !$count;

        until nqp::eoffh($!PIO) {
            nqp::readlinefh($!PIO);
            $!ins = $!ins + 1;
        }
        nqp::box_i($!ins, Int);
    }
    multi method lines(IO::Handle:D: :$close) {

        if $.chomp {
            gather {
                until nqp::eoffh($!PIO) {
                    $!ins = $!ins + 1;
                    take nqp::p6box_s(nqp::readlinefh($!PIO)).chomp;
                }
                self.close if $close;
            }
        }
        else {
            gather {
                until nqp::eoffh($!PIO) {
                    $!ins = $!ins + 1;
                    take nqp::p6box_s(nqp::readlinefh($!PIO));
                }
                self.close if $close;
            }
        }
    }
    multi method lines(IO::Handle:D: $limit, :$eager, :$close) {
        return self.lines(:$eager, :$close)
          if nqp::istype($limit,Whatever) or $limit == Inf;

        my Mu $rpa := nqp::list();
        my int $count = $limit + 1;
        if $.chomp {
            while $count = $count - 1 {
                last if nqp::eoffh($!PIO);
                nqp::push($rpa, nqp::p6box_s(nqp::readlinefh($!PIO)).chomp );
            }
        }
        else {
            while $count = $count - 1 {
                nqp::push($rpa, nqp::p6box_s(nqp::readlinefh($!PIO)) );
            }
        }
        $!ins = nqp::elems($rpa);
        self.close if $close;
        nqp::p6parcel($rpa, Nil);
    }

    method read(IO::Handle:D: Int(Cool:D) $bytes) {
        my $buf := buf8.new();
        nqp::readfh($!PIO, $buf, nqp::unbox_i($bytes));
        $buf;
    }

    # second arguemnt should probably be an enum
    # valid values for $whence:
    #   0 -- seek from beginning of file
    #   1 -- seek relative to current position
    #   2 -- seek from the end of the file
    method seek(IO::Handle:D: Int:D $offset, Int:D $whence) {
        nqp::seekfh($!PIO, $offset, $whence);
        True;
    }

    method tell(IO::Handle:D:) returns Int {
        nqp::p6box_i(nqp::tellfh($!PIO));
    }

    method write(IO::Handle:D: Blob:D $buf) {
        nqp::writefh($!PIO, nqp::decont($buf));
        True;
    }

    method opened(IO::Handle:D:) {
        nqp::p6bool(nqp::istrue($!PIO));
    }

    method t(IO::Handle:D:) {
        self.opened && nqp::p6bool($!PIO.isatty)
    }


    proto method print(|) { * }
    multi method print(IO::Handle:D: Str:D \x) {
        nqp::printfh($!PIO, nqp::unbox_s(x));
        Bool::True
    }
    multi method print(IO::Handle:D: *@list) {
        nqp::printfh($!PIO, nqp::unbox_s(@list.shift.Str)) while @list.gimme(1);
        Bool::True
    }

    multi method say(IO::Handle:D: |) {
        my Mu $args := nqp::p6argvmarray();
        nqp::shift($args);
        self.print: nqp::shift($args).gist while $args;
        self.print-nl;
    }

    method print-nl(IO::Handle:D:) {
        nqp::printfh($!PIO, nqp::unbox_s($!nl));
        Bool::True;
    }

    method slurp(IO::Handle:D: |c) {
        DEPRECATED('$handle.slurp-rest', |<2014.10 2015.09>);
        self.slurp-rest(|c);
    }

    method slurp-rest(IO::Handle:D: :$bin, :$enc) {
        if $bin {
            my $Buf := buf8.new();
            loop {
                my $buf := buf8.new();
                nqp::readfh($!PIO,$buf,65536);
                last if $buf.bytes == 0;
                $Buf := $Buf ~ $buf;
            }
            $Buf;
        }
        else {
            self.encoding($enc) if $enc.defined;
            nqp::p6box_s(nqp::readallfh($!PIO));
        }
    }

    proto method spurt(|) { * }
    multi method spurt(IO::Handle:D: Cool $contents, :$nodepr) {
        DEPRECATED("IO::Path.spurt", |<2014.10 2015.09>) unless $nodepr;
        self.print($contents);
    }

    multi method spurt(IO::Handle:D: Blob $contents, :$nodepr) {
        DEPRECATED("IO::Path.spurt", |<2014.10 2015.09>) unless $nodepr;
        self.write($contents);
    }

    # not spec'd
    method copy(IO::Handle:D: $dest) {
        DEPRECATED("IO::Path.copy", |<2014.10 2015.09>);
        $!path.copy($dest);
    }

    method chmod(IO::Handle:D: Int $mode) { $!path.chmod($mode) }
    method IO(IO::Handle:D: |c)           { $!path.IO(|c) }
    method path(IO::Handle:D:)            { $!path.IO }
    multi method Str(IO::Handle:D:)       { $!path }

    multi method gist(IO::Handle:D:) {
        self.opened
            ?? "IO::Handle<$!path>(opened, at line {$.ins} / octet {$.tell})"
            !! "IO::Handle<$!path>(closed)"
    }

    multi method perl(IO::Handle:D:) {
        "IO::Handle.new(path => {$!path.perl}, ins => {$!ins.perl}, chomp => {$!chomp.perl})"
    }


    method flush(IO::Handle:D:) {
        fail("File handle not open, so cannot flush")
            unless nqp::defined($!PIO);
        nqp::flushfh($!PIO);
        True;
    }

    method encoding(IO::Handle:D: $enc?) {
        $enc.defined
            ?? nqp::setencoding($!PIO, NORMALIZE_ENCODING($enc))
            !! $!PIO.encoding
    }

    submethod DESTROY(IO::Handle:D:) {
        self.close;
    }

    # setting cannot do "handles", so it's done by hand here
    method e(IO::Handle:D:) { $!path.e }
    method d(IO::Handle:D:) { $!path.d }
    method f(IO::Handle:D:) { $!path.f }
    method s(IO::Handle:D:) { $!path.s }
    method l(IO::Handle:D:) { $!path.l }
    method r(IO::Handle:D:) { $!path.r }
    method w(IO::Handle:D:) { $!path.w }
    method x(IO::Handle:D:) { $!path.x }
    method modified(IO::Handle:D:) { $!path.modified }
    method accessed(IO::Handle:D:) { $!path.accessed }
    method changed(IO::Handle:D:)  { $!path.changed  }

#?if moar
    method watch(IO::Handle:D:) {
        IO::Notification.watch_path($!path);
    }
#?endif
}

# vim: ft=perl6 expandtab sw=4
