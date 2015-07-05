multi sub INITIALIZE_DYNAMIC('$*PID') {
    PROCESS::<$PID> := nqp::p6box_i(nqp::getpid());
}

multi sub INITIALIZE_DYNAMIC('$*EXECUTABLE') {
    PROCESS::<$EXECUTABLE> := IO::File.new(:abspath(
#?if jvm
      $*VM.properties<perl6.execname>
      // $*VM.properties<perl6.prefix> ~ '/bin/perl6-j'
#?endif
#?if moar
      nqp::execname()
      // ($*VM.config<prefix> ~ '/bin/'
        ~ ($*VM.config<osname> eq 'MSWin32' ?? 'perl6-m.bat' !! 'perl6-m'))
#?endif
    ));
}

multi sub INITIALIZE_DYNAMIC('$*EXECUTABLE-NAME') {
    PROCESS::<$EXECUTABLE-NAME> := $*EXECUTABLE.basename;
}

multi sub INITIALIZE_DYNAMIC('$*PROGRAM-NAME') {
    PROCESS::<$PROGRAM-NAME> := nqp::getcomp('perl6').user-progname;
}

multi sub INITIALIZE_DYNAMIC('$*PROGRAM') {
    PROCESS::<$PROGRAM> := $*PROGRAM-NAME.IO;  # could be -e
}

multi sub INITIALIZE_DYNAMIC('$*TMPDIR') {
    PROCESS::<$TMPDIR> := $*DISTRO.tmpdir;
}

multi sub INITIALIZE_DYNAMIC('$*HOME') {
    PROCESS::<$HOME> = $*DISTRO.homedir;
}

{
    class IdName {
        has Int $!id;
        has Str $!name;

        submethod BUILD (:$!id, :$!name) { }

        method Numeric { $!id }
        method Str     { $!name }
        method gist    { "$!name ($!id)" }
    }

    class IdFetch {
        has Str $!name;

        submethod BUILD (:$!name) { PROCESS::{$!name} := self }

        sub fetch {
            once if !$*DISTRO.is-win && try { qx/id/ } -> $id {
                if $id ~~ m/^
                  [ uid "=" $<uid>=(\d+) ]
                  [ "(" $<user>=(<-[ ) ]>+) ")" ]
                  \s+
                  [ gid "=" $<gid>=(\d+) ]
                  [ "(" $<group>=(<-[ ) ]>+) ")" ]
                / {
                    PROCESS::<$USER> :=
                      IdName.new( :id(+$<uid>), :name(~$<user>) );
                    PROCESS::<$GROUP> :=
                      IdName.new( :id(+$<gid>), :name(~$<group>) );
                }

                # alas, no support yet
                else {
                    PROCESS::<$USER>  := Nil;
                    PROCESS::<$GROUP> := Nil;
                }
            }
        }

        multi method Numeric(IdFetch:D:) {
            fetch() ?? +PROCESS::{$!name} !! Nil;
        }
        multi method Str(IdFetch:D:) {
            fetch() ?? ~PROCESS::{$!name} !! Nil;
        }
        multi method gist(IdFetch:D:) {
            fetch() ?? "{PROCESS::{$!name}} ({+PROCESS::{$!name}})" !! Nil;
        }
    }

    IdFetch.new( :name<$USER> );
    IdFetch.new( :name<$GROUP> );
}

# Deprecations
multi sub INITIALIZE_DYNAMIC('$*EXECUTABLE_NAME') {
    $*EXECUTABLE-NAME; # prime it
    PROCESS::<$EXECUTABLE_NAME> := PROCESS::<$EXECUTABLE-NAME>;
}
multi sub INITIALIZE_DYNAMIC('$*PROGRAM_NAME') {
    $*PROGRAM-NAME;  # prime it
    PROCESS::<$PROGRAM_NAME> := PROCESS::<$PROGRAM-NAME>;
}

# vim: ft=perl6 expandtab sw=4
