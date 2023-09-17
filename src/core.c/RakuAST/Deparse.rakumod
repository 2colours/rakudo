# This is the default class handling deparsing (aka, converting a given
# RakuAST::Node object into Raku source code).
#
# It is supposed to be subclassed to provide customization and further
# optimizations (although optimizations should probably live here).
#
# All methods are class methods, so do not require any type of instantiation.
#
# The "deparse" multi method expects an instance if a subclass of a
# RakuAST::Node as the first positional parameter.  All other publick methods
# are used to provide some standard functionality used by the "deparse" methods.

class RakuAST::Deparse {

#-------------------------------------------------------------------------------
# General lookup hashes

    my constant %processor-attribute =
      'exec',       ':x',
      'quotewords', ':ww',
      'val',        ':v',
      'words',      ':w',
      'heredoc',    ':to',
    ;

    my constant %single-processor-prefix =
      'exec',       'qx/',
      'quotewords', 'qqww/',
      'val',        'qq:v/',
      'words',      'qqw/',
    ;

    my constant %twigil2type = <
      !  var-attribute
      .  var-attribute
      ?  var-compiler
      *  var-compiler
      =  var-rakudoc
    >;

#-------------------------------------------------------------------------------
# These methods are effectively constants that can be overridden by a
# subclass.

    method before-comma(--> ' ') { }
    method after-comma( --> ' ') { }

    method parens-open( --> '(') { }
    method parens-close(--> ')') { }

    method square-open( --> '[') { }
    method square-close(--> ']') { }

    method reduce-open(    --> '[')   { }
    method reduce-triangle(--> '[\\') { }
    method reduce-close(   --> '] ')  { }

    method bracket-open( --> '{') { }
    method bracket-close(--> '}') { }

    method pointy-open( --> '<') { }
    method pointy-close(--> '>') { }

    method double-pointy-open( --> '<<') { }
    method double-pointy-close(--> '>>') { }

    method block-open( --> "\{\n") { }
    method block-close(--> "\}\n") { }

    method regex-open(                  --> '/ ')  { }
    method regex-close(                 --> '/')   { }
    method regex-alternation(           --> '| ')  { }
    method regex-sequential-alternation(--> '|| ') { }
    method regex-conjunction(           --> '& ')  { }
    method regex-sequential-conjunction(--> '&& ') { }

    method regex-any(                --> '.')   { }
    method regex-beginning-of-string(--> '^ ')  { }
    method regex-end-of-string(      --> '$ ')  { }
    method regex-beginning-of-line(  --> '^^ ') { }
    method regex-end-of-line(        --> '$$ ') { }
    method regex-left-word-boundary( --> '<< ') { }
    method regex-right-word-boundary(--> '>> ') { }

    method regex-assertion-pass(--> '<?> ')     { }
    method regex-assertion-fail(--> '<!> ')     { }
    method regex-assertion-recurse(--> '<~~> ') { }

    method regex-backtrack-frugal( --> '?') { }
    method regex-backtrack-ratchet(--> ':') { }
    method regex-backtrack-greedy( --> '!') { }

    method regex-match-from(--> '<( ') { }
    method regex-match-to(  --> ')> ') { }

    method before-infix(--> ' ')  { }
    method after-infix( --> ' ')  { }

    method list-infix-comma(     --> ', ') { }
    method list-infix-semi-colon(--> '; ') { }

    method dotty-infix-call(       --> ' .')   { }
    method dotty-infix-call-assign(--> ' .= ') { }

    method function-infix-open( --> '[') { }
    method function-infix-close(--> ']') { }

    method slurpy-flattened(      --> '*') { }
    method slurpy-single-argument(--> '+') { }
    method slurpy-unflattened(   --> '**') { }
    method slurpy-capture(       --> '|')  { }

    method term-hyperwhatever(--> '**')   { }
    method term-rand(         --> 'rand') { }
    method term-empty-set(    --> '∅')    { }
    method term-self(         --> 'self') { }
    method term-whatever(     --> '*')     { }

    method var-compiler-file(--> '$?FILE') { }
    method var-compiler-line(--> '$?LINE') { }

    method assign(--> ' = ')  { }
    method bind(  --> ' := ') { }

    method before-list-infix(--> '') { }
    method after-list-infix(--> ' ') { }

    method loop-separator(--> '; ') { }

    method pointy-sig(     --> '-> ')   { }
    method pointy-return(  --> ' --> ') { }
    method fatarrow(       --> ' => ')  { }
    method end-statement(  --> ";\n")   { }
    method last-statement( --> "\n")    { }

    method indent-with(--> '    ') { }

    method ternary1(--> ' ?? ') { }
    method ternary2(--> ' !! ') { }

#-------------------------------------------------------------------------------
# Setting up the deparse method

    proto method deparse(|) {
        if nqp::istype($*INDENT,Failure) {
            my $*INDENT    = "";  # indentation level
            my $*DELIMITER = "";  # delimiter to add, reset if added
            {*}
        }
        else {
            {*}
        }
    }

    # Base class catcher
    multi method deparse(RakuAST::Node:D $ast) {
        NYI("Deparsing $ast.^name() objects").throw
    }

    # Odd value catcher, avoiding long dispatch options in error message
    multi method deparse(Mu:D $ast) {
        die "You cannot deparse a $ast.^name() instance: $ast.raku()";
    }
    multi method deparse(Mu:U $ast) {
        die "You cannot deparse a $ast.^name() type object";
    }

#-------------------------------------------------------------------------------
# Provide translation for given syntax feature of Raku

    # The default implementation of the "xsyn" method is basically a no-op,
    # because it will ignore the prefix (which can be any of <block core
    # infix modifier multi package phaser prefix routine scope stmt-prefix
    # trait type use>).  The idea is that you can mixin a role with this
    # method (such as RakuAST::Deparse::L10N::NL) that will provide
    # translations of the Raku Programming Language syntax elements to a
    # language different from English.
    #
    # Please see lib/RakuAST/Deparse/L10N/CORE.rakumod for the default
    # mapping and an example of implementation of the "xsyn" method for
    # translations.
    method xsyn(str $prefix, str $key) { $key }

#-------------------------------------------------------------------------------
# Provide highlighting for given syntax feature of Raku

    # The default implementation of the "hsyn" method is basically a no-op,
    # because it will ignore the prefix (which can be any of <block core
    # infix modifier multi package phaser prefix routine scope stmt-prefix
    # trait type use>).  The idea is that you can mixin a role with this
    # method (such as RakuAST::Deparse::Highlight::HTML) to provide some
    # kind of syntax highlighting.
    #
    # Please see lib/RakuAST/Deparse/Highlight/HTML.rakumod for an example
    # of implementation of the "hsyn" method for highlighting.
    proto method hsyn(|) {*}
    multi method hsyn(Str:D $prefix, Str:D $key) { $key }

#-------------------------------------------------------------------------------
# Helper methods

    # helper method for deparsing contextualizers
    proto method context-target(|) {*}
    multi method context-target(RakuAST::StatementSequence $target --> Str:D) {
        self.parenthesize($target)
    }
    multi method context-target($target --> Str:D) {
        self.deparse($target)
    }

    method indent($indent = $.indent-with--> Str:D) {
        $_ = $_ ~ $indent with $*INDENT;
    }

    method dedent($indent = $.indent-with--> Str:D) {
        $_ = $_.chomp($indent) with $*INDENT;
    }

    method handle-signature($ast, str $header) {
        my str @parts = $header;

        sub add-traits() {
            if $ast.traits -> @traits {
                @parts.push(self.deparse($_)) for @traits;
            }
        }

        my $signature := $ast.signature;
        my $WHY       := $ast.WHY;
        if $signature.parameters-initialized
          && $signature.parameters.first(*.WHY) {
            @parts.push("(\n");
            @parts = self.add-any-docs(@parts.join(' '), $WHY)
              ~ self.deparse($signature)
              ~ ')';
            add-traits;
        }

        else {
            @parts.push(self.parenthesize($signature))
              if $signature.parameters-initialized;
            add-traits;

            if $WHY {
                $*DELIMITER = "";
                @parts.push('{');
                return self.add-any-docs(@parts.join(' '), $WHY)
                  ~ self.deparse($ast.body, :multi).substr(2)  # lose {\n
            }
        }

        @parts.push(self.deparse($ast.body));
        @parts.join(' ')

    }

    method method(RakuAST::Methodish:D $ast, str $kind --> Str:D) {
        my str @parts = self.syn-routine($kind);

        if $ast.multiness -> $multiness {
            @parts.unshift(self.syn-multi($multiness));
        }

        my str $scope = $ast.scope;
        @parts.unshift(self.xsyn('scope', $scope))
          if $scope ne 'has' && $scope ne $ast.default-scope;

        if $ast.name -> $ast-name {
            my str $name = self.deparse($ast-name);
            @parts.push(nqp::istype($ast,RakuAST::Method)
              ?? $ast.private
                ?? "!$name"
                !! $ast.meta
                  ?? "^$name"
                  !! $name
              !! $name
            );
        }

        self.handle-signature($ast, @parts.join(' '))
    }

    method conditional($self: $ast, str $type --> Str:D) {
        self.syn-block($type)
         ~ " $self.deparse($ast.condition) $self.deparse($ast.then)$.last-statement"
    }

    method negated-conditional($self: $ast, str $type --> Str:D) {
        self.syn-block($type)
          ~ " $self.deparse($ast.condition) $self.deparse($ast.body)$.last-statement"
    }

    method simple-loop($self: $ast, str $type --> Str:D) {
        self.syn-block($type)
          ~ " $self.deparse($ast.condition) $self.deparse($ast.body)"
    }

    method simple-repeat($ast, str $type --> Str:D) {
       self.syn-block('repeat')
         ~ ' '
         ~ self.deparse($ast.body).chomp
         ~ ' '
         ~ self.syn-modifier($type)
         ~ ' '
         ~ self.deparse($ast.condition)
    }

    method assemble-quoted-string($ast --> Str:D) {
        $ast.segments.map({
            nqp::istype($_,RakuAST::StrLiteral)
              ?? .value.raku.substr(1,*-1)
              !! self.deparse($_)
            }).join
    }

    method multiple-processors(str $string, @processors --> Str:D) {
        "qq@processors.map({
            %processor-attribute{$_} // NYI("String processors '$_'")
        }).join()/$string/"
    }

    method branches(RakuAST::Regex::Branching:D $ast, str $joiner --> Str:D) {
        if $ast.branches -> @branches {
            @branches.map({ self.deparse($_) }).join($joiner)
        }
        else {
            ''
        }
    }

    method quantifier(
      RakuAST::Regex::Quantifier:D $ast, str $quantifier
    --> Str:D) {
        $quantifier ~ self.deparse($ast.backtrack)
    }

    method parenthesize($ast --> Str:D) {
        $.parens-open
          ~ ($ast.defined ?? self.deparse($ast).chomp !! '')
          ~ $.parens-close
    }

    method bracketize($ast --> Str:D) {
        $.bracket-open
          ~ ($ast.defined ?? self.deparse($ast) !! '')
          ~ $.bracket-close
    }

    method squarize($ast --> Str:D) {
        $.square-open
          ~ ($ast.defined ?? self.deparse($ast) !! '')
          ~ $.square-close
    }

    method method-call($ast, str $dot, $macroish?, :$xsyn --> Str:D) {
        my $name := (nqp::istype($_,Str) ?? $_ !! self.deparse($_))
          with $ast.name;

        self.syn-routine($dot)
          ~ ($xsyn ?? self.xsyn('core', $name) !! $name)
          ~ ($macroish ?? '' !! self.parenthesize($ast.args))
    }

    method quote-if-needed(str $literal) {
        my int $find = nqp::findnotcclass(
          nqp::const::CCLASS_WORD,$literal,0,nqp::chars($literal)
        );
        $find == nqp::chars($literal)
          ?? $literal       # just word chars
          !! $literal.raku  # need quoting
    }

    method deparse-unquoted($ast) {
        if nqp::istype($ast,Str) {
            $ast
        }
        elsif nqp::istype($ast,RakuAST::StrLiteral) {
            $ast.value
        }
        else {
            my $literal := self.deparse($ast);
            $literal.starts-with(Q/"/) && $literal.ends-with(Q/"/)
              || $literal.starts-with(Q/'/) && $literal.ends-with(Q/'/)
              ?? $literal.substr(1,*-1)
              !! $literal
        }
    }

    method labels(RakuAST::Statement:D $ast) {
        $ast.labels.map({ self.deparse($_) }).join
    }

    method use-no(str $what, $ast) {
        my str @parts =
          self.xsyn('use', $what), ' ', self.deparse($ast.module-name);

        if $ast.argument -> $argument {
            @parts.push(' ');
            @parts.push(self.deparse($argument));
        }

        self.labels($ast) ~ @parts.join
    }

    method prefix-any-leading-doc(str $body, $WHY) {
        if $WHY && $WHY.leading -> @leading {
            self.hsyn('doc-leading', @leading.map({
                self.deparse-unquoted($_).lines(:!chomp).Slip
            }).map({
                "#| $_$*INDENT"
            }).join)
              ~ $body
        }
        else {
            $body
        }
    }

    method postfix-any-trailing-doc(str $body, $WHY) {
        if $WHY && $WHY.trailing -> @trailing {
            my str @lines = @trailing.map: {
                self.deparse-unquoted($_).lines.Slip
            }
            ($body ~ $*DELIMITER).chomp
              ~ (@lines > 1 ?? "\n" !! ' ')
              ~ self.hsyn(
                  'doc-trailing',
                  @lines.map({ "#= $_" }).join("$*INDENT\n")
                )
              ~ "\n"
        }
        else {
            $body ~ $*DELIMITER
        }
    }

    method add-any-docs(str $body, $WHY) {
        self.postfix-any-trailing-doc(
          self.prefix-any-leading-doc($body, $WHY), $WHY
        )
    }

    method statement-modifier(str $type, $ast) {
        self.syn-modifier($type) ~ ' ' ~ self.deparse($ast.expression)
    }

    method syn-block(str $type) {
        self.hsyn("block-$type", self.xsyn('block', $type))
    }

    method syn-infix(str $operator) {
        self.hsyn("infix", self.xsyn('infix', $operator))
    }

    method syn-infix-ws(Str:D $operator) {
        $operator.leading-whitespace
          ~ self.hsyn("infix", self.xsyn('infix', $operator.trim))
          ~ $operator.trailing-whitespace
    }

    method syn-modifier(str $type) {
        self.hsyn("modifier-$type", self.xsyn('modifier', $type))
    }

    method syn-multi(str $type) {
        self.hsyn("multi-$type", self.xsyn('multi', $type))
    }

    method syn-package(str $declarator) {
        self.hsyn("package-$declarator", self.xsyn('package', $declarator))
    }

    method syn-phaser(str $phaser) {
        self.hsyn("phaser-$phaser", self.xsyn('phaser', $phaser))
    }

    method syn-routine(str $type) {
        self.hsyn("routine-$type", self.xsyn('routine', $type))
    }

    method syn-scope(str $scope) {
        self.hsyn("scope-$scope", self.xsyn('scope', $scope))
    }

    method syn-trait(str $trait) {
        self.hsyn("trait-$trait", self.xsyn('trait', $trait))
    }

    method syn-type($type) {
        self.hsyn('type', self.deparse($type))
    }

    method syn-typer($typer) {
        self.hsyn('typer',self.xsyn('typer', $typer))
    }

#- A ---------------------------------------------------------------------------

    multi method deparse(RakuAST::ApplyInfix:D $ast --> Str:D) {
        self.deparse($ast.left)
          ~ $.before-infix
          ~ self.deparse($ast.infix)
          ~ $.after-infix
          ~ self.deparse($ast.right)
    }

    multi method deparse(RakuAST::ApplyDottyInfix:D $ast --> Str:D) {
        self.deparse($ast.left)
          ~ self.deparse($ast.infix)
          # lose the ".", as it is provided by the infix
          ~ self.deparse($ast.right).substr(1)
    }

    multi method deparse(RakuAST::ApplyListInfix:D $ast --> Str:D) {
        my $infix       := $ast.infix;
        my str $operator = nqp::istype($infix,RakuAST::MetaInfix)
          || nqp::istype($infix,RakuAST::Feed)
          ?? (' ' ~ self.deparse($infix))
          !! self.deparse($infix);

        my str @parts = $ast.operands.map({ self.deparse($_) });
        @parts
          ?? $operator eq ','
            ?? @parts == 1
              ?? @parts.head ~ $.list-infix-comma.chomp
              !! @parts.join($.list-infix-comma)
            !! @parts.join(
                 $.before-list-infix ~ $operator ~ $.after-list-infix
               )
          !! ''
    }

    multi method deparse(RakuAST::ApplyPostfix:D $ast --> Str:D) {
        my str $deparsed-postfix = self.deparse($ast.postfix);
        if $ast.on-topic {
            $deparsed-postfix
        }
        else {
            my     $operand         := $ast.operand;
            my str $deparsed-operand = self.deparse($operand);

            nqp::istype($operand,RakuAST::ApplyListInfix)
              ?? '(' ~ $deparsed-operand ~ ')' ~ $deparsed-postfix
              !! $deparsed-operand ~ $deparsed-postfix
        }
    }

    multi method deparse(RakuAST::ApplyPrefix:D $ast --> Str:D) {
        self.hsyn('prefix', self.xsyn('prefix', self.deparse($ast.prefix)))
          ~ self.deparse($ast.operand)
    }

    multi method deparse(RakuAST::ArgList:D $ast --> Str:D) {
        $ast.args.map({ self.deparse($_) }).join($.list-infix-comma)
    }

#- B ---------------------------------------------------------------------------

    multi method deparse(RakuAST::Block:D $ast --> Str:D) {
        if $ast.WHY -> $WHY {
            $*DELIMITER = "";
            self.add-any-docs('{', $WHY)
              ~ self.deparse($ast.body, :multi).substr(2)  # lose {\n
        }
        else {
            self.deparse($ast.body, |%_)
        }
    }

    multi method deparse(RakuAST::Blockoid:D $ast, :$multi, :$unit --> Str:D) {
        my $statement-list := $ast.statement-list;

        if $unit {
            self.deparse($statement-list)
        }
        elsif $multi || $statement-list.statements {
            self.indent;
            $.block-open
              ~ self.deparse($statement-list)
              ~ self.dedent
              ~ $.bracket-close
        }
        else {
            "$.bracket-open $.bracket-close"
        }
    }

#- Call ------------------------------------------------------------------------

    multi method deparse(RakuAST::Call::MaybeMethod:D $ast --> Str:D) {
        self.method-call($ast, '.?')
    }

    multi method deparse(RakuAST::Call::MetaMethod:D $ast --> Str:D) {
        self.method-call($ast, '.^')
    }

    multi method deparse(RakuAST::Call::Method:D $ast --> Str:D) {
        self.method-call($ast, '.', $ast.macroish, :xsyn)
    }

    multi method deparse(RakuAST::Call::PrivateMethod:D $ast --> Str:D) {
        self.method-call($ast, '!')
    }

    multi method deparse(RakuAST::Call::QuotedMethod:D $ast --> Str:D) {
        self.method-call($ast, '.')
    }

    multi method deparse(RakuAST::Call::VarMethod:D $ast --> Str:D) {
        self.method-call($ast, '.&')
    }

    multi method deparse(RakuAST::Call::Name:D $ast --> Str:D) {
        my $name := self.xsyn('core', self.deparse($ast.name));
        $name.ends-with('::')
          ?? $name
          !! $name ~ self.parenthesize($ast.args)
    }

    multi method deparse(RakuAST::Call::Term:D $ast --> Str:D) {
        self.parenthesize($ast.args)
    }

#- Circumfix -------------------------------------------------------------------

    multi method deparse(RakuAST::Circumfix::ArrayComposer:D $ast --> Str:D) {
        self.squarize($ast.semilist)
    }

    multi method deparse(RakuAST::Circumfix::HashComposer:D $ast --> Str:D) {
        self.bracketize($ast.expression)
    }

    multi method deparse(RakuAST::Circumfix::Parentheses:D $ast --> Str:D) {
        self.parenthesize($ast.semilist)
    }

#- ColonPair -------------------------------------------------------------------

    multi method deparse(RakuAST::ColonPair:D $ast --> Str:D) {
        ':'
          ~ $ast.named-arg-name
          ~ $.parens-open
          ~ self.deparse($ast.named-arg-value)
          ~ $.parens-close
    }

    multi method deparse(RakuAST::ColonPair::False:D $ast --> Str:D) {
        ':!' ~ $ast.key
    }

    multi method deparse(RakuAST::ColonPair::Number:D $ast --> Str:D) {
        ':' ~ self.deparse($ast.value) ~ $ast.key
    }

    multi method deparse(RakuAST::ColonPair::True:D $ast --> Str:D) {
        ':' ~ $ast.key
    }

    multi method deparse(RakuAST::ColonPair::Value:D $ast --> Str:D) {
        my $value := $ast.value;

        ':' ~ $ast.key ~ (
          nqp::istype($value,RakuAST::QuotedString)
            ?? self.deparse($value)
            !! $.parens-open ~ self.deparse($value) ~ $.parens-close
        )
    }

    multi method deparse(RakuAST::ColonPair::Variable:D $ast --> Str:D) {
        ':' ~ self.deparse($ast.value)
    }

#- Co --------------------------------------------------------------------------

    multi method deparse(RakuAST::CompUnit:D $ast --> Str:D) {
        my str $deparsed = self.deparse($ast.statement-list);
        with $ast.finish-content {
            $deparsed ~="\n=finish\n$_";
        }
        else {
            $deparsed
        }
    }

    multi method deparse(RakuAST::Contextualizer:D $ast --> Str:D) {
        $ast.sigil ~ self.context-target($ast.target)
    }

#- D ---------------------------------------------------------------------------

    multi method deparse(RakuAST::Declaration:D $ast --> Str:D) {
        self.xsyn('scope', $ast.scope)
    }

    multi method deparse(
      RakuAST::Declaration::ResolvedConstant:D $ast
    --> Str:D) {
        $ast.compile-time-value.raku
    }

#- Doc -------------------------------------------------------------------------

    multi method deparse(RakuAST::Doc::Block:D $ast --> Str:D) {
        my str $margin = $ast.margin;
        my str $type = $ast.type;
        my str $name = self.hsyn('rakudoc-type', $type ~ $ast.level);

        # indent string with given margin, unless all whitespace
        sub indent(Str:D $string) {
            $margin
              ?? $string.lines(:!chomp).map({
                     .is-whitespace ?? "\n" !! $margin ~ $_
                 }).join
              !! $string
        }

        # handle =alias directive
        if $type eq 'alias' {
            my ($lemma, $paragraph) = $ast.paragraphs;
            $paragraph = self.deparse($paragraph)
              unless nqp::istype($paragraph,Str);

            return "$margin=$name $lemma $paragraph.subst(
              "\n", "\n$margin= ", :global
            )\n";
        }

        # handle =defn blocks
        my $abbreviated := $ast.abbreviated;
        my str $prefix   = "$margin=$name";
        if $type eq 'defn' {
            my str @paras = $ast.paragraphs;
            my str $lemma = @paras.shift;
            my str $spec = "$lemma\n" ~ @paras.map(&indent).join;

            return $abbreviated
              ?? "$prefix $spec"
              !! $ast.for
                ?? "$margin=for $name\n$margin$spec"
                !! "$margin=begin $name\n$margin$spec$margin=end $name\n\n";
        }

        # preprocess any config
        my str $config = $ast.config.sort({
            .key eq 'numbered' ?? '' !! .key  # numbered always first
        }).map({
            my str $key = .key;
            if $key eq 'numbered' && $abbreviated {
                '#'
            }
            else {
                my $deparsed := self.deparse(.value);
                $deparsed eq 'True'
                  ?? ":$key"
                  !! $deparsed eq 'False'
                    ?? ":!$key"
                    !! ":$key$deparsed"
            }
        }).join(' ');
        $config = $config
          ?? ' ' ~ self.hsyn('rakudoc-config', $config) ~ "\n"
          !! "\n";

        # handle =row / =column directives
        if $type eq 'row' | 'column' {
            return $prefix ~ $config;
        }

        # handle =config directive
        elsif $type eq 'config' {
            return "$prefix $ast.paragraphs.head()$config"
        }

        # set up paragraphs
        my $paragraphs := indent $ast.paragraphs.map({
            nqp::istype($_,Str) ?? $_ !! self.deparse($_)
        }).join;

        # handle implicite code blocks
        if $type eq 'implicit-code' {
            $paragraphs := self.deparse($_)
              with try $paragraphs.AST;  # try do highlighting on code
            self.hsyn('rakudoc-verbatim', $paragraphs)
        }

        # handle explicit code blocks
        elsif $type eq 'code' {
            $paragraphs := self.deparse($_)
              with try $paragraphs.AST;  # try do highlighting on code
            $paragraphs := self.hsyn('rakudoc-verbatim', $paragraphs);

            $abbreviated
              ?? "$prefix\n$paragraphs"
              !! $ast.for
                ?? "$margin=for $name$config$paragraphs"
                !! "$margin=begin $name$config$paragraphs$margin=end $name\n\n"
        }

        # handle tables (to be expanded soon)
        elsif $type eq 'table' {
            $paragraphs := self.hsyn('rakudoc-table', $paragraphs);

            $abbreviated
              ?? "$prefix$config$paragraphs\n"
              !! $ast.for
                ?? "$margin=for $name$config$paragraphs\n"
                !! "$margin=begin $name$config$paragraphs$margin=end $name\n\n"
        }

        # other blocks
        else {
            $paragraphs := self.hsyn(
              $type eq 'comment' | 'data' | 'input' | 'output'
                ?? 'rakudoc-verbatim'
                !! 'rakudoc-content',
              $paragraphs.chomp
            ) ~ "\n";

            $abbreviated
              ?? "$prefix$config.chomp() $paragraphs.trim-leading()\n"
              !! $ast.for
                ?? "$margin=for $name$config$paragraphs"
                !! "$margin=begin $name$config$paragraphs$margin=end $name\n\n"
        }
    }

    multi method deparse(RakuAST::Doc::Declarator:D $ast --> Str:D) {
        (my $wherefore := nqp::clone($ast.WHEREFORE)).set-WHY($ast);
        self.deparse($wherefore).chomp
    }

    multi method deparse(RakuAST::Doc::Markup:D $ast --> Str:D) {
        self.hsyn("markup-$ast.letter()", $ast.Str)
    }

    multi method deparse(RakuAST::Doc::Paragraph:D $ast --> Str:D) {
        $ast.atoms.map({ self.deparse-unquoted($_) }).join
    }

    multi method deparse(RakuAST::Doc::Row:D $ast --> Str:D) {
        $ast.Str
    }

#- Dot -------------------------------------------------------------------------

    multi method deparse(RakuAST::DottyInfix::Call:D $ --> Str:D) {
        $.dotty-infix-call
    }

    multi method deparse(RakuAST::DottyInfix::CallAssign:D $ --> Str:D) {
        $.dotty-infix-call-assign
    }

#- F ---------------------------------------------------------------------------

    multi method deparse(RakuAST::FatArrow:D $ast --> Str:D) {
        $ast.key ~ $.fatarrow ~ self.deparse($ast.value)
    }

    multi method deparse(RakuAST::FunctionInfix:D $ast --> Str:D) {
        $.function-infix-open
          ~ self.deparse($ast.function)
          ~ $.function-infix-close
    }

#- H ---------------------------------------------------------------------------

    multi method deparse(RakuAST::Heredoc:D $ast --> Str:D) {
        my $string := self.assemble-quoted-string($ast);
        my @processors = $ast.processors;
        @processors.push('heredoc');

        my $stop   := $ast.stop;
        my $indent := $stop eq "\n"
          ?? ''
          !! " " x ($stop.chars - $stop.trim-leading.chars);

        self.multiple-processors($stop.trim, @processors)
          ~ "\n"
          ~ $string.chomp('\n').split(Q/\n/).map({
              $_ ?? "$indent$_\n" !! "\n"
            }).join
          ~ $stop
    }

#- I ---------------------------------------------------------------------------

    # Also for ::FlipFlop
    multi method deparse(RakuAST::Infix:D $ast --> Str:D) {
        self.syn-infix($ast.operator)
    }

    multi method deparse(RakuAST::Initializer::Assign:D $ast --> Str:D) {
        self.syn-infix-ws($.assign) ~ self.deparse($ast.expression)
    }

    multi method deparse(RakuAST::Initializer::Bind:D $ast --> Str:D) {
        self.syn-infix-ws($.bind) ~ self.deparse($ast.expression)
    }

    multi method deparse(RakuAST::Initializer::CallAssign:D $ast --> Str:D) {
        self.syn-infix-ws($.dotty-infix-call-assign)
          ~ self.deparse($ast.postfixish).substr(1)
    }

#- L ---------------------------------------------------------------------------

    multi method deparse(RakuAST::Label:D $ast --> Str:D) {
        self.hsyn('label', $ast.name ~ ': ')
    }

    # handles all RakuAST::xxxLiteral classes
    multi method deparse(RakuAST::Literal:D $ast --> Str:D) {
        self.hsyn('literal', $ast.value.raku)
    }

#- M ---------------------------------------------------------------------------

    multi method deparse(RakuAST::MetaInfix::Assign:D $ast --> Str:D) {
        self.syn-infix(self.deparse($ast.infix) ~ '=')
    }

    multi method deparse(RakuAST::MetaInfix::Cross:D $ast --> Str:D) {
        self.syn-infix(self.xsyn('meta','X') ~ self.deparse($ast.infix))
    }

    multi method deparse(RakuAST::MetaInfix::Hyper:D $ast --> Str:D) {
        self.hsyn('infix',
          ($ast.dwim-left ?? '<<' !! '>>')
            ~ self.xsyn('infix', self.deparse($ast.infix))
            ~ ($ast.dwim-right ?? '>>' !! '<<')
        )
    }

    multi method deparse(RakuAST::MetaInfix::Negate:D $ast --> Str:D) {
        self.syn-infix(self.deparse($ast.infix) ~ '!')
    }

    multi method deparse(RakuAST::MetaInfix::Reverse:D $ast --> Str:D) {
        self.syn-infix(self.xsyn('meta','R') ~ self.deparse($ast.infix))
    }

    multi method deparse(RakuAST::MetaInfix::Zip:D $ast --> Str:D) {
        self.syn-infix(self.xsyn('meta','Z') ~ self.deparse($ast.infix))
    }

    multi method deparse(RakuAST::Method:D $ast --> Str:D) {
        self.method($ast, 'method')
    }

#- N ---------------------------------------------------------------------------

    multi method deparse(RakuAST::Name:D $ast --> Str:D) {
        $ast.canonicalize
    }

    multi method deparse(RakuAST::Nqp:D $ast --> Str:D) {
        self.hsyn('nqp', "nqp::" ~ $ast.op) ~ self.parenthesize($ast.args)
    }

    multi method deparse(RakuAST::Nqp::Const:D $ast --> Str:D) {
        self.hsyn('nqp', "nqp::const::" ~ $ast.name)
    }

#- O ---------------------------------------------------------------------------

    multi method deparse(RakuAST::OnlyStar:D $ --> '{*}') { }

#- P ---------------------------------------------------------------------------

    multi method deparse(RakuAST::Package:D $ast --> Str:D) {
        my str $scope = $ast.scope;
        my str @parts;

        if $scope {
            @parts.push(self.syn-scope($scope))
              if $scope ne $ast.default-scope;
        }

        my str $declarator = $ast.declarator;
        @parts.push(self.syn-package($declarator));

        my str $name = self.deparse($ast.name);
        if $ast.parameterization -> $signature {
            @parts.push((my $deparsed := self.deparse($signature))
              ?? $name ~ '[' ~ $deparsed ~ ']'
              !! $name
            );
        }
        else {
            @parts.push($name);
        }

        if $ast.traits -> @traits {
            for @traits -> $trait {
                @parts.push(self.deparse($trait));
            }
        }

        my $body := $declarator eq 'role'
          ?? RakuAST::Block.new(
               body => RakuAST::Blockoid.new(
                 # lose fabricated return value
                 RakuAST::StatementList.new(
                   |$ast.body.body.statement-list.statements.head(*-1)
                 )
               )
             )
          !! $ast.body;

        if $ast.WHY -> $WHY {
            if $scope eq 'unit' {
                self.add-any-docs(@parts.join(' ') ~ ';', $WHY)
                  ~ self.deparse($body, :unit).chomp
            }
            else {
                @parts.push('{');
                self.add-any-docs(@parts.join(' '), $WHY).chomp
                  ~ self.deparse($body, :multi).substr(1).chomp
            }
        }
        elsif $scope eq 'unit' {
            @parts.join(' ')
              ~ $.end-statement
              ~ self.deparse($body, :unit).chomp
        }
        else {
            @parts.push(self.deparse($body));
            @parts.join(' ')
        }
    }

    multi method deparse(RakuAST::Pragma:D $ast --> Str:D) {
        my str @parts =
          self.hsyn('use', self.xsyn('use', $ast.off ?? "no" !! "use")),
          self.hsyn('pragma', $ast.name);
        @parts.push(self.deparse($_)) with $ast.argument;
        @parts.join(' ') ~ $*DELIMITER
    }

#- Parameter -------------------------------------------------------------------

    multi method deparse(RakuAST::Parameter:D $ast --> Str:D) {
        return self.add-any-docs(self.hsyn('literal',.raku), $ast.WHY)
          with $ast.value;

        my $target   := $ast.target;
        my @captures := $ast.type-captures;
        my str @parts;
        if !@captures && $ast.type -> $type {
            my str $deparsed = self.deparse($type);
            unless $deparsed eq 'Any' | 'SETTING::<Any>' {
                @parts.push($deparsed);
                @parts.push(' ') if $target;
            }
        }

        if $ast.type-captures -> @captures {
            @parts.push(self.deparse($_)) for @captures;
        }
        elsif $target {
            my str $var = self.deparse($target, :slurpy($ast.slurpy));

            # named parameter
            if $ast.names -> @names {
                my str $varname = $var.substr(1);  # lose the sigil
                my int $parens;
                my int $seen;

                for @names -> $name {
                    if $name eq $varname {
                        $seen = 1;
                    }
                    else {
                        @parts.push(':');
                        @parts.push($name);
                        @parts.push('(');
                        ++$parens;
                    }
                }

                @parts.push(':') if $seen;
                @parts.push($var);
                @parts.push(nqp::x(')',$parens)) if $parens;
                @parts.push('?') if $ast.is-declared-optional;
                @parts.push('!') if $ast.is-declared-required;
            }

            # positional parameter
            else {
                given $ast.slurpy -> $prefix {
                    @parts.push(self.deparse($prefix));
                }
                @parts.push($var);
                if $ast.invocant {
                    @parts.push(':');
                }
                elsif $ast.is-declared-optional {
                    @parts.push('?');
                }
                elsif $ast.is-declared-required {
                    @parts.push('!');
                }
            }

            if $ast.traits -> @traits {
                for @traits {
                    @parts.push(' ');
                    @parts.push(self.deparse($_));
                }
            }
        }
        elsif nqp::eqaddr($ast.slurpy,RakuAST::Parameter::Slurpy::Capture) {
            @parts.push(self.deparse($ast.slurpy));
        }

        @parts = self.hsyn('param', @parts.join);
        if $ast.default -> $default {
            @parts.push(self.syn-infix-ws($.assign) ~ self.deparse($default));
        }

        self.add-any-docs(@parts.join, $ast.WHY)
    }

    multi method deparse(RakuAST::Parameter::Slurpy:U $ --> '') { }

    multi method deparse(RakuAST::Parameter::Slurpy::Flattened:U $ --> Str:D) {
        $.slurpy-flattened
    }

    multi method deparse(
      RakuAST::Parameter::Slurpy::SingleArgument:U $
    --> Str:D) {
        $.slurpy-single-argument
    }

    multi method deparse(
      RakuAST::Parameter::Slurpy::Unflattened:U $
    --> Str:D) {
        $.slurpy-unflattened
    }

    multi method deparse(RakuAST::Parameter::Slurpy::Capture:U $ --> Str:D) {
        $.slurpy-capture
    }

    multi method deparse(RakuAST::ParameterTarget::Var:D $ast --> Str:D) {
        $ast.name
    }

    multi method deparse(
      RakuAST::ParameterTarget::Term:D $ast, :$slurpy
    --> Str:D) {
        ($slurpy === RakuAST::Parameter::Slurpy ?? '\\' !! '')
          ~ $ast.name.canonicalize
    }

    multi method deparse(RakuAST::ParameterDefaultThunk:D $ --> '') { }

#- Po --------------------------------------------------------------------------

    multi method deparse(RakuAST::PointyBlock:D $ast --> Str:D) {
        my str @parts = '->';

        my $signature := $ast.signature;
        my $WHY       := $ast.WHY;
        if $signature.parameters-initialized
          && $signature.parameters.first(*.WHY) {
            @parts.push("\n");
            @parts = self.add-any-docs(@parts.join(' '), $WHY)
              ~ self.deparse($signature);
        }

        else {
            @parts.push(self.deparse($signature))
              if $signature.parameters-initialized;

            if $WHY {
                $*DELIMITER = "";
                @parts.push('{');
                return self.add-any-docs(@parts.join(' '), $WHY)
                  ~ self.deparse($ast.body, :multi).substr(2)  # lose {\n
            }
        }

        @parts.push(self.deparse($ast.body));
        @parts.join(' ')
    }

    multi method deparse(RakuAST::Postcircumfix::ArrayIndex:D $ast --> Str:D) {
        self.squarize($ast.index)
    }

    multi method deparse(RakuAST::Postcircumfix::HashIndex:D $ast --> Str:D) {
        self.bracketize($ast.index)
    }

    multi method deparse(
      RakuAST::Postcircumfix::LiteralHashIndex:D $ast
    --> Str:D) {
        self.deparse($ast.index)
    }

    multi method deparse(RakuAST::Postfix:D $ast --> Str:D) {
        $ast.operator
    }

    multi method deparse(RakuAST::Postfix::Power:D $ast --> Str:D) {
        $ast.power.Str(:superscript)
    }

    multi method deparse(RakuAST::Postfix::Vulgar:D $ast --> Str:D) {
        my $rat := $ast.vulgar;
        "$rat.numerator.Str(:superscript)/$rat.denominator.Str(:subscript)"
    }

    multi method deparse(RakuAST::Prefix:D $ast --> Str:D) {
        self.xsyn('prefix', $ast.operator)
    }

#- Q ---------------------------------------------------------------------------

    multi method deparse(RakuAST::QuotedRegex:D $ast --> Str:D) {
        my str $adverbs = $ast.adverbs.map({ self.deparse($_) }).join;
        ($ast.match-immediately ?? 'm' !! $adverbs ?? 'rx' !! '')
          ~ $adverbs
          ~ $.regex-open
          ~ self.deparse($ast.body)
          ~ $.regex-close
    }

    multi method deparse(RakuAST::QuotedString:D $ast --> Str:D) {
        my str $string = self.assemble-quoted-string($ast);

        if $ast.processors -> @processors {
            if @processors == 1 && @processors.head -> $processor {
                if %single-processor-prefix{$processor} -> str $p {
                    ($p eq 'exec' && $ast.has-variables ?? 'qqx' !! $p)
                      ~ $string
                      ~ '/'
                }
                else {
                    NYI("Quoted string processor '$processor'").throw
                }
            }
            elsif @processors == 2 && !$ast.has-variables {
                my str $joined = @processors.join(' ');
                if $joined eq 'words val' {
                    $.pointy-open ~ $string ~ $.pointy-close
                }
                elsif $joined eq 'quotewords val' {
                    $.double-pointy-open ~ $string ~ $.double-pointy-close
                }
                else {
                    self.multiple-processors($string, @processors)
                }
            }
            else {
                self.multiple-processors($string, @processors)
            }
        }
        else {
            self.hsyn('literal', '"' ~ $string ~ '"')
        }
    }

    multi method deparse(RakuAST::QuoteWordsAtom:D $ast --> Str:D) {
        self.deparse($ast.atom)
    }

#- Regex -----------------------------------------------------------------------

    multi method deparse(
      RakuAST::Regex::Anchor::BeginningOfString $
    --> Str:D) {
        $.regex-beginning-of-string
    }

    multi method deparse(RakuAST::Regex::Anchor::EndOfString $ --> Str:D) {
        $.regex-end-of-string
    }

    multi method deparse(
      RakuAST::Regex::Anchor::BeginningOfLine $
    --> Str:D) {
        $.regex-beginning-of-line
    }

    multi method deparse(RakuAST::Regex::Anchor::EndOfLine $ --> Str:D) {
        $.regex-end-of-line
    }

    multi method deparse(RakuAST::Regex::Anchor::LeftWordBoundary $ --> Str:D) {
        $.regex-left-word-boundary
    }

    multi method deparse(
      RakuAST::Regex::Anchor::RightWordBoundary $
    --> Str:D) {
        $.regex-right-word-boundary
    }

    multi method deparse(RakuAST::Regex::Literal:D $ast --> Str:D) {
        self.quote-if-needed($ast.text)
    }

    multi method deparse(RakuAST::Regex::Alternation:D $ast --> Str:D) {
        self.branches($ast, $.regex-alternation)
    }

#- Regex::Assertion ------------------------------------------------------------

    multi method deparse(RakuAST::Regex::Assertion::Alias:D $ast --> Str:D) {
        '<'
          ~ $ast.name
          ~ '='
          ~ self.deparse($ast.assertion).substr(1)
    }

    multi method deparse(
      RakuAST::Regex::Assertion::Callable:D $ast
    --> Str:D) {
        my $args := $ast.args;
        '<'
          ~ self.deparse($ast.callee)
          ~ ($args && $args.args ?? self.parenthesize($args) !! "")
          ~ '>'
    }

    multi method deparse(
      RakuAST::Regex::Assertion::CharClass:D $ast
    --> Str:D) {
        '<' ~ $ast.elements.map({ self.deparse($_) }).join(' ') ~ '>'
    }

    multi method deparse(RakuAST::Regex::Assertion::Fail $ --> Str:D) {
        $.regex-assertion-fail
    }

    multi method deparse(
      RakuAST::Regex::Assertion::InterpolatedBlock:D $ast
    --> Str:D) {
        NYI "DEPARSE of sequential interpolated block NYI" if $ast.sequential;
        '<' ~ self.deparse($ast.block).chomp ~ '>'
    }

    multi method deparse(
      RakuAST::Regex::Assertion::InterpolatedVar:D $ast
    --> Str:D) {
        NYI "DEPARSE of sequential interpolated block NYI" if $ast.sequential;
        '<' ~ self.deparse($ast.var) ~ '>'
    }

    multi method deparse(
      RakuAST::Regex::Assertion::Lookahead:D $ast
    --> Str:D) {
        ($ast.negated ?? '<!' !! '<?')
          ~ self.deparse($ast.assertion).substr(1)
    }

    multi method deparse(RakuAST::Regex::Assertion::Named:D $ast --> Str:D) {
        ($ast.capturing ?? '<' !! '<.') ~ self.deparse($ast.name) ~ '>'
    }

    multi method deparse(
      RakuAST::Regex::Assertion::Named::Args:D $ast
    --> Str:D) {
        ($ast.capturing ?? '<' !! '<.')
          ~ self.deparse($ast.name)
          ~ self.parenthesize($ast.args)
          ~ '>'
    }

    multi method deparse(
      RakuAST::Regex::Assertion::Named::RegexArg:D $ast
    --> Str:D) {
        '<'
          ~ self.deparse($ast.name)
          ~ ' '
          ~ self.deparse($ast.regex-arg)
          ~ '>'
    }

    multi method deparse(RakuAST::Regex::Assertion::Pass $ --> Str:D) {
        $.regex-assertion-pass
    }

    multi method deparse(RakuAST::Regex::Assertion::Recurse $ --> Str:D) {
        $.regex-assertion-recurse
    }

    multi method deparse(
      RakuAST::Regex::Assertion::PredicateBlock:D $ast
    --> Str:D) {
        '<'
          ~ ($ast.negated ?? '!' !! '?')
          ~ self.deparse($ast.block).chomp
          ~ '>'
    }

#- Regex::B --------------------------------------------------------------------

    multi method deparse(
      RakuAST::Regex::BackReference::Positional:D $ast
    --> Str:D) {
        '$' ~ $ast.index
    }

    multi method deparse(
      RakuAST::Regex::BackReference::Named:D $ast
    --> Str:D) {
        '$<' ~ $ast.name ~ '>'
    }

    # This candidate needed to represent *no* backtracking specification
    multi method deparse(RakuAST::Regex::Backtrack:U $ --> '') { }

    multi method deparse(RakuAST::Regex::Backtrack::Frugal:U $ --> Str:D) {
        $.regex-backtrack-frugal
    }

    multi method deparse(RakuAST::Regex::Backtrack::Greedy:U $ --> Str:D) {
        $.regex-backtrack-greedy
    }

    multi method deparse(RakuAST::Regex::Backtrack::Ratchet:U $ --> Str:D) {
        $.regex-backtrack-ratchet
    }

    multi method deparse(
      RakuAST::Regex::BacktrackModifiedAtom:D $ast
    --> Str:D) {
        self.deparse($ast.atom) ~ self.deparse($ast.backtrack)
    }

    multi method deparse(RakuAST::Regex::Block:D $ast --> Str:D) {
        self.deparse($ast.block).chomp
    }

#- Regex::C --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::CapturingGroup:D $ast --> Str:D) {
        self.parenthesize($ast.regex)
    }

#- Regex::Charclass ------------------------------------------------------------

    multi method deparse(RakuAST::Regex::CharClass::Any $ast --> Str:D) {
        $.regex-any
    }

    multi method deparse(
      RakuAST::Regex::CharClass::BackSpace:D $ast
    --> Str:D) {
        $ast.negated ?? '\\B' !! '\\b'
    }

    multi method deparse(
      RakuAST::Regex::CharClass::CarriageReturn:D $ast
    --> Str:D) {
        $ast.negated ?? '\\R' !! '\\r'
    }

    multi method deparse(RakuAST::Regex::CharClass::Digit:D $ast --> Str:D) {
        $ast.negated ?? '\\D' !! '\\d'
    }

    multi method deparse(RakuAST::Regex::CharClass::Escape:D $ast --> Str:D) {
        $ast.negated ?? '\\E' !! '\\e'
    }

    multi method deparse(RakuAST::Regex::CharClass::FormFeed:D $ast --> Str:D) {
        $ast.negated ?? '\\F' !! '\\f'
    }

    multi method deparse(
      RakuAST::Regex::CharClass::HorizontalSpace:D $ast
    --> Str:D) {
        $ast.negated ?? '\\H' !! '\\h'
    }

    multi method deparse(RakuAST::Regex::CharClass::Newline:D $ast --> Str:D) {
        $ast.negated ?? '\\N' !! '\\n'
    }

    multi method deparse(RakuAST::Regex::CharClass::Nul:D $ast --> '\0') { }

    multi method deparse(RakuAST::Regex::CharClass::Space:D $ast --> Str:D) {
        $ast.negated ?? '\\S' !! '\\s'
    }

    multi method deparse(
      RakuAST::Regex::CharClass::Specified:D $ast
    --> Str:D) {
        ($ast.negated ?? '\\C' !! '\\c')
          ~ '['
          ~ $ast.characters.ords.map(*.uniname).join(', ')
          ~ ']'
    }

    multi method deparse(RakuAST::Regex::CharClass::Tab:D $ast --> Str:D) {
        $ast.negated ?? '\\T' !! '\\t'
    }

    multi method deparse(
      RakuAST::Regex::CharClass::VerticalSpace:D $ast
    --> Str:D) {
        $ast.negated ?? '\\V' !! '\\v'
    }

    multi method deparse(RakuAST::Regex::CharClass::Word:D $ast --> Str:D) {
        $ast.negated ?? '\\W' !! '\\w'
    }

    multi method deparse(
      RakuAST::Regex::CharClassElement::Enumeration:D $ast
    --> Str:D) {
        ($ast.negated ?? '-' !! '+')
          ~ '[' ~ $ast.elements.map({ self.deparse($_) }).join(' ') ~ ']'
    }

    multi method deparse(
      RakuAST::Regex::CharClassElement::Property:D $ast
    --> Str:D) {
        my str @parts;

        @parts.push($ast.negated ?? '-' !! '+');
        @parts.push(':');
        @parts.push('!') if $ast.inverted;
        @parts.push($ast.property);

        with $ast.predicate {
            if nqp::istype($_,RakuAST::StrLiteral) {
                @parts.push('<');
                @parts.push(self.deparse-unquoted($_));
                @parts.push('>');
            }
            else {
                @parts.push(self.deparse($_))
            }
        }

        @parts.join
    }

    multi method deparse(
      RakuAST::Regex::CharClassElement::Rule:D $ast
    --> Str:D) {
        ($ast.negated ?? '-' !! '+') ~ $ast.name
    }

    multi method deparse(
      RakuAST::Regex::CharClassEnumerationElement::Character:D $ast
    --> Str:D) {
        $ast.character
    }

    multi method deparse(
      RakuAST::Regex::CharClassEnumerationElement::Range:D $ast
    --> Str:D) {
        $ast.from.chr ~ '..' ~ $ast.to.chr
    }

#- Regex::Co -------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::Conjunction:D $ast --> Str:D) {
        self.branches($ast, $.regex-conjunction)
    }

#- Regex::G --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::Group:D $ast --> Str:D) {
        self.squarize($ast.regex)
    }

#- Regex::I --------------------------------------------------------------------

    multi method deparse(
      RakuAST::Regex::InternalModifier::IgnoreCase:D $ast --> Str:D) {
        $ast.negated ?? ':!i ' !! ':i '
    }

    multi method deparse(
      RakuAST::Regex::InternalModifier::IgnoreMark:D $ast
    --> Str:D) {
        $ast.negated ?? ':!m ' !! ':m '
    }

    multi method deparse(
      RakuAST::Regex::InternalModifier::Ratchet:D $ast
    --> Str:D) {
        $ast.negated ?? ':!r ' !! ':r '
    }

    multi method deparse(
      RakuAST::Regex::InternalModifier::Sigspace:D $ast
    --> Str:D) {
        $ast.negated ?? ':!s ' !! ':s '
    }

    multi method deparse(RakuAST::Regex::Interpolation:D $ast --> Str:D) {
        ($ast.sequential ?? '|| ' !! '') ~ self.deparse($ast.var)
    }

#- Regex::M --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::MatchFrom:D $ --> Str:D) {
        $.regex-match-from
    }

    multi method deparse(RakuAST::Regex::MatchTo:D $ --> Str:D) {
        $.regex-match-to
    }

#- Regex::N --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::NamedCapture:D $ast --> Str:D) {
        '$<' ~ $ast.name ~ '>=' ~ self.deparse($ast.regex)
    }

#- Regex::Q --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::QuantifiedAtom:D $ast --> Str:D) {
        my str @parts = self.deparse($ast.atom), self.deparse($ast.quantifier);

        if $ast.separator -> $separator {
            @parts.push($ast.trailing-separator ?? '%% ' !! '% ');
            @parts.push(self.deparse($separator));
        }

        @parts.join
    }

    multi method deparse(
      RakuAST::Regex::Quantifier::BlockRange:D $ast
    --> Str:D) {
        my $backtrack := $ast.backtrack;

        '**'
          ~ (self.deparse($backtrack) unless nqp::eqaddr(
              $ast.backtrack,
              RakuAST::Regex::Backtrack
            ))
          ~ ' '
          ~ self.deparse($ast.block)
    }

    multi method deparse(
      RakuAST::Regex::Quantifier::OneOrMore:D $ast
    --> Str:D) {
        self.quantifier($ast, '+')
    }

    multi method deparse(RakuAST::Regex::Quantifier::Range:D $ast --> Str:D) {
        my str @parts = '**';

        my $backtrack := $ast.backtrack;
        @parts.push(self.deparse($backtrack))
          unless nqp::eqaddr($backtrack,RakuAST::Regex::Backtrack);
        @parts.push(' ');

        with $ast.min -> $min {
            @parts.push($min.Str);
            with $ast.max -> $max {
                if $min != $max {
                    @parts.push('^') if $ast.excludes-min;
                    @parts.push('..');
                    @parts.push('^') if $ast.excludes-max;
                    @parts.push($max.Str);
                }
            }
            else {
                @parts.push('^') if $ast.excludes-min;
                @parts.push('..*');
            }
        }
        else {
            @parts.push('^') if $ast.excludes-max;
            @parts.push($ast.max.Str);
        }

        @parts.join
    }

    multi method deparse(
      RakuAST::Regex::Quantifier::ZeroOrMore:D $ast
    --> Str:D) {
        self.quantifier($ast, '*')
    }

    multi method deparse(
      RakuAST::Regex::Quantifier::ZeroOrOne:D $ast
    --> Str:D) {
        self.quantifier($ast, '?')
    }

    multi method deparse(RakuAST::Regex::Quote:D $ast --> Str:D) {
        my str $quoted = self.deparse($ast.quoted);
        $quoted.chars > 2
          ?? $quoted.starts-with('"')
            ?? $quoted.substr(1,$quoted.chars - 2)
            !! ('<{ ' ~ $quoted ~ ' }>')
          !! ''
    }

#- Regex::S --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::Sequence:D $ast --> Str:D) {
        $ast.terms.map({
            nqp::istype($_,RakuAST::Regex::CharClass::BackSpace)
              ?? ('"' ~ self.deparse($_) ~ '"')
              !! self.deparse($_)
        }).join
    }

    multi method deparse(
      RakuAST::Regex::SequentialAlternation:D $ast
    --> Str:D) {
        self.branches($ast, $.regex-sequential-alternation)
    }

    multi method deparse(
      RakuAST::Regex::SequentialConjunction:D $ast
    --> Str:D) {
        self.branches($ast, $.regex-sequential-conjunction)
    }

    multi method deparse(RakuAST::Regex::Statement:D $ast --> Str:D) {
        ':' ~ self.deparse($ast.statement) ~ '; '
    }

#- Regex::W --------------------------------------------------------------------

    multi method deparse(RakuAST::Regex::WithWhitespace:D $ast --> Str:D) {
        self.deparse($ast.regex) ~ " "
    }

#- RegexD ----------------------------------------------------------------------

    # also for ::TokenDeclaration and ::RuleDeclaration
    multi method deparse(RakuAST::RegexDeclaration:D $ast --> Str:D) {
        my str @parts = self.xsyn('routine', $ast.declarator);

        if $ast.multiness -> $multiness {
            @parts.unshift(self.syn-multi($multiness));
        }

        my str $scope = $ast.scope;
        @parts.unshift(self.xsyn('scope', $scope))
          if $scope ne 'has' && $scope ne $ast.default-scope;

        @parts.push(self.deparse($_)) with $ast.name;

        # at least one parameter with declarator doc
        my $signature := $ast.signature;
        if $signature.parameters.first(*.WHY) {
            @parts.push("(\n");
            @parts.push(self.deparse($signature));
            @parts.push(')');
        }

        # no parameters with declarator doc
        else {
            @parts.push(self.parenthesize($signature))
              if $signature.parameters-initialized;
        }

        if $ast.traits.map({self.deparse($_)}).join(' ') -> $traits {
            @parts.push($traits);
        }

        if $ast.WHY -> $WHY {
            @parts.push('{');
            @parts = self.add-any-docs(@parts.join(' '), $WHY);
        }
        else {
            @parts.push('{ ');
            @parts = @parts.join(' ');
        }

        @parts.push($*INDENT);
        @parts.push(self.deparse($ast.body));
        @parts.push('}');
        @parts.join
    }

#- S ---------------------------------------------------------------------------

    multi method deparse(RakuAST::SemiList:D $ast --> Str:D) {
        my @statements := $ast.statements;
        @statements == 1
          ?? self.deparse(@statements.head.expression)
          !! @statements.map({ self.deparse($_) }).join($.list-infix-semi-colon)
    }

    multi method deparse(RakuAST::Signature:D $ast --> Str:D) {
        my str @parts;

        if $ast.parameters -> @parameters {

            # need special handling for declarator doc
            if @parameters.first(*.WHY) {
                my $last      := @parameters.tail;
                my $*DELIMITER = $.list-infix-comma.trim ~ "\n";

                my str @atoms;
                self.indent('  ');
                for @parameters -> $param {
                    $*DELIMITER = "\n" if $param === $last;
                    @atoms.push($*INDENT);
                    @atoms.push(self.deparse($param));
                }
                self.dedent('  ');

                @parts.push(@atoms.join);
            }

            # no special action
            else {
                my $*DELIMITER = $.list-infix-comma;
                @parts.push(@parameters.map({
                    self.deparse($_)
                }).join.chomp($.list-infix-comma))
            }
        }

        with $ast.returns {
            @parts.push('-->');
            @parts.push(self.deparse($_));
        }

        @parts.join(' ')
    }

#- Statement -------------------------------------------------------------------

    multi method deparse(RakuAST::Statement::Catch:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-phaser('CATCH') ~ ' ' ~ self.deparse($ast.body)
    }

    multi method deparse(RakuAST::Statement::Control:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-phaser('CONTROL') ~ ' ' ~ self.deparse($ast.body)
    }

    multi method deparse(RakuAST::Statement::Default:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-block('default') ~ ' ' ~ self.deparse($ast.body)
    }

    multi method deparse(RakuAST::Statement::Elsif:D $ast --> Str:D) {
        self.conditional($ast, 'elsif')  # cannot have labels
    }

    multi method deparse(RakuAST::Statement::Empty:D $ast --> Str:D) {
        self.labels($ast) ~ $*DELIMITER
    }

    multi method deparse(RakuAST::Statement::Expression:D $ast --> Str:D) {
        my $expression := $ast.expression;
        my str @parts   = self.deparse($expression);

        if $ast.condition-modifier -> $condition {
            @parts.push(self.deparse($condition));
        }

        if $ast.loop-modifier -> $loop {
            @parts.push(self.deparse($loop));
        }

        self.labels($ast)
          ~ @parts.join(' ')
          ~ (nqp::istype($expression,RakuAST::Doc::DeclaratorTarget)
              ?? ""
              !! $*DELIMITER
            )
    }

    multi method deparse(RakuAST::Statement::For:D $ast --> Str:D) {
        my str @parts =
          self.syn-block('for'),
          self.deparse($ast.source),
          self.deparse($ast.body)
        ;

        if $ast.mode -> str $mode {
            @parts.unshift($mode) if $mode ne 'serial';
        }

        self.labels($ast) ~ @parts.join(' ')
    }

    multi method deparse(RakuAST::Statement::Given:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-block('given')
          ~ ' '
          ~ self.deparse($ast.source)
          ~ ' '
          ~ self.deparse($ast.body)
    }

    # handling both ::If and ::With
    multi method deparse(RakuAST::Statement::IfWith:D $ast --> Str:D) {
        my str @parts = self.conditional($ast, $ast.IMPL-QAST-TYPE);

        if $ast.elsifs -> @elsifs {
            @parts.push(self.deparse($_)) for @elsifs;
        }

        if $ast.else -> $else {
            @parts.push(self.syn-block('else'));
            @parts.push(' ');
            @parts.push(self.deparse($else));
            @parts.push($.last-statement);
        }

        self.labels($ast) ~ @parts.join
    }

    multi method deparse(RakuAST::Statement::Import:D $ast --> Str:D) {
        my str @parts =
          self.xsyn('use','import'), self.deparse($ast.module-name);
        @parts.push(self.deparse($_)) with $ast.argument;
        self.labels($ast) ~ @parts.join(' ') ~ $*DELIMITER
    }

    multi method deparse(RakuAST::Statement::Loop:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-block('loop')
          ~ ' ('
          ~ self.deparse($ast.setup)
          ~ $.loop-separator
          ~ self.deparse($ast.condition)
          ~ $.loop-separator
          ~ self.deparse($ast.increment)
          ~ ') '
          ~ self.deparse($ast.body)
    }

    multi method deparse(
      RakuAST::Statement::Loop::RepeatUntil:D $ast
    --> Str:D) {
        self.labels($ast) ~ self.simple-repeat($ast, 'until')
    }

    multi method deparse(
      RakuAST::Statement::Loop::RepeatWhile:D $ast --> Str:D) {
        self.labels($ast) ~ self.simple-repeat($ast, 'while')
    }

    multi method deparse(RakuAST::Statement::Loop::Until:D $ast --> Str:D) {
        self.labels($ast) ~ self.simple-loop($ast, 'until')
    }

    multi method deparse(RakuAST::Statement::Loop::While:D $ast --> Str:D) {
        self.labels($ast) ~ self.simple-loop($ast, 'while')
    }

    multi method deparse(RakuAST::Statement::Need:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.xsyn('use', 'need')
          ~ ' '
          ~ $ast.module-names.map({self.deparse($_)}).join($.list-infix-comma)
          ~ $*DELIMITER
    }

    multi method deparse(RakuAST::Statement::Orwith:D $ast --> Str:D) {
        self.conditional($ast, 'orwith')  # cannot have labels
    }

    multi method deparse(RakuAST::Statement::Require:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.xsyn('use', 'require') ~ ' ' ~ self.deparse($ast.module-name)
    }

    multi method deparse(RakuAST::Statement::Unless:D $ast --> Str:D) {
        self.labels($ast) ~ self.negated-conditional($ast, 'unless');
    }

    multi method deparse(RakuAST::Statement::Use:D $ast --> Str:D) {
        self.use-no("use", $ast) ~ $*DELIMITER
    }

    multi method deparse(RakuAST::Statement::When:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-block('when')
          ~ ' '
          ~ self.deparse($ast.condition)
          ~ ' '
          ~ self.deparse($ast.body)
    }

    multi method deparse(RakuAST::Statement::Whenever:D $ast --> Str:D) {
        self.labels($ast)
          ~ self.syn-block('whenever')
          ~ ' '
          ~ self.deparse($ast.trigger)
          ~ ' '
          ~ self.deparse($ast.body)
    }

    multi method deparse(RakuAST::Statement::Without:D $ast --> Str:D) {
        self.labels($ast) ~ self.negated-conditional($ast, 'without');
    }

    multi method deparse(RakuAST::StatementList:D $ast --> Str:D) {

        if $ast.statements -> @statements {
            my str @parts;
            my str $spaces = $*INDENT;
            my $last-statement := @statements.first({
                !nqp::istype($_,RakuAST::Doc::Block)
            }, :end) // @statements.tail;

            my $code;
            my $*DELIMITER;
            for @statements -> $statement {
                $*DELIMITER = $statement === $last-statement
                  ?? $.last-statement
                  !! $.end-statement;
                my $deparsed := self.deparse($statement);
                $deparsed := $deparsed.chop(2) if $deparsed.ends-with("};\n");

                @parts.push($spaces);
                @parts.push($deparsed);
                @parts.push("\n") if $deparsed.ends-with('}');
            }

            @parts.join
        }

        else {
            ''
        }
    }

#- Statement::Modifier ---------------------------------------------------------

    multi method deparse(RakuAST::StatementModifier::Given:D $ast --> Str:D) {
        self.statement-modifier('given', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::If:D $ast --> Str:D) {
        self.statement-modifier('if', $ast)
    }

    multi method deparse( RakuAST::StatementModifier::For:D $ast --> Str:D) {
        self.statement-modifier('for', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::For::Thunk:D $ --> '') { }

    multi method deparse(RakuAST::StatementModifier::Unless:D $ast --> Str:D) {
        self.statement-modifier('unless', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::Until:D $ast --> Str:D) {
        self.statement-modifier('until', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::When:D $ast --> Str:D) {
        self.statement-modifier('when', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::While:D $ast --> Str:D) {
        self.statement-modifier('while', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::With:D $ast --> Str:D) {
        self.statement-modifier('with', $ast)
    }

    multi method deparse(RakuAST::StatementModifier::Without:D $ast --> Str:D) {
        self.statement-modifier('without', $ast)
    }

#- StatementPrefix -------------------------------------------------------------

    # handles all statement prefixes
    multi method deparse(RakuAST::StatementPrefix:D $ast --> Str:D) {
        self.hsyn('stmt-prefix', self.xsyn('stmt-prefix', $ast.type))
          ~ ' ' ~ self.deparse($ast.blorst).chomp
    }

    # handles most phasers
    multi method deparse(RakuAST::StatementPrefix::Phaser:D $ast --> Str:D) {
        my $*DELIMITER = '';
        self.syn-phaser($ast.type) ~ ' ' ~ self.deparse($ast.blorst).chomp
    }

    multi method deparse(
      RakuAST::StatementPrefix::Phaser::Post:D $ast
    --> Str:D) {
        # POST phasers get extra code inserted at RakuAST level, which
        # wraps the original blorst into a statement in which the blorst
        # becomes the condition modifier
        my $expression := $ast.blorst.body.statement-list.statements.head
          .condition-modifier.expression;
        self.syn-phaser('POST') ~ ' ' ~ self.deparse(
          nqp::istype($expression,RakuAST::ApplyPostfix)
            ?? $expression.operand
            !! $expression
        ).chomp
    }

    multi method deparse(
      RakuAST::StatementPrefix::Phaser::Pre:D $ast
    --> Str:D) {
        # PRE phasers get extra code inserted at RakuAST level, which
        # wraps the original blorst into a statement in which the blorst
        # becomes the condition modifier
        my $expression := $ast.blorst.condition-modifier.expression;
        self.syn-phaser('PRE') ~ ' ' ~ self.deparse(
          nqp::istype($expression,RakuAST::ApplyPostfix)
            ?? $expression.operand
            !! $expression
        ).chomp
    }

#- Stu -------------------------------------------------------------------------

    multi method deparse(RakuAST::Stub:D $ast --> Str:D) {
        my str $hsyn = self.hsyn('stub', $ast.name);
        if $ast.args -> $real-args {
            $hsyn ~ ' ' ~ self.deparse($real-args)
        }
        else {
            $hsyn
        }
    }

#- Su --------------------------------------------------------------------------

    multi method deparse(RakuAST::Sub:D $ast --> Str:D) {
        my str @parts = self.syn-routine('sub');

        if $ast.multiness -> $multiness {
            @parts.unshift(self.syn-multi($multiness))
        }

        my str $scope = $ast.scope;
        @parts.unshift(self.xsyn('scope', $scope))
          if $scope ne $ast.default-scope && ($ast.name || $scope ne 'anon');

        if $ast.name -> $name {
            @parts.push(self.deparse($name));
        }

        self.handle-signature($ast, @parts.join(' '))
    }

    multi method deparse(RakuAST::Submethod:D $ast --> Str:D) {
        self.method($ast, 'submethod')
    }

    multi method deparse(RakuAST::Substitution:D $ast --> Str:D) {
        my str @parts = $ast.immutable ?? 'S' !! 's';
        @parts.push(':samespace') if $ast.samespace;

        if $ast.adverbs -> @adverbs {
            @parts.push(self.deparse($_)) for @adverbs;
        }

        if $ast.infix -> $infix {
            @parts.push('{');
            @parts.push(self.deparse($ast.pattern));
            @parts.push('} ');
            @parts.push(self.deparse($infix));
            @parts.push(' ');
            @parts.push(self.deparse($ast.replacement));
        }
        else {
            @parts.push('/');
            @parts.push(self.deparse($ast.pattern));
            @parts.push('/');
            @parts.push(self.deparse($ast.replacement).substr(1,*-1));
            @parts.push('/');
        }

        @parts.join
    }

    multi method deparse(
      RakuAST::SubstitutionReplacementThunk:D $ast
    --> Str:D) {
        self.deparse($ast.infix)
    }

#- Term ------------------------------------------------------------------------

    multi method deparse(RakuAST::Term::Capture:D $ast --> Str:D) {
        Q/\/ ~ self.parenthesize($ast.source)
    }

    multi method deparse(RakuAST::Term::EmptySet:D $ --> Str:D) {
        $.term-empty-set
    }

    multi method deparse(RakuAST::Term::HyperWhatever:D $ --> Str:D) {
        $.term-hyperwhatever
    }

    multi method deparse(RakuAST::Term::Name:D $ast --> Str:D) {
        self.deparse($ast.name)
    }

    multi method deparse(RakuAST::Term::Named:D $ast --> Str:D) {
        self.xsyn('term', $ast.name)
    }

    multi method deparse(RakuAST::Term::Rand:D $ --> Str:D) {
        self.xsyn('term', $.term-rand)
    }

    multi method deparse(RakuAST::Term::RadixNumber:D $ast --> Str:D) {
        # multi-part doesn't need to be checked, as it only involves
        # the legality of what is put in .value.  So deparsing .value
        # is enough
        ':' ~ $ast.radix ~ self.deparse($ast.value)
    }

    multi method deparse(RakuAST::Term::Reduce:D $ast --> Str:D) {
        my $args := $ast.args;

        ($ast.triangle ?? $.reduce-triangle !! $.reduce-open)
          ~ self.deparse($ast.infix)
          ~ $.reduce-close
          ~ ($args.defined && $args.elems == 1
              ?? self.deparse($args)
              !! self.parenthesize($args)
            )
    }

    multi method deparse(RakuAST::Term::Self:D $ --> Str:D) {
        self.hsyn('invocant', self.xsyn('term', $.term-self))
    }

    multi method deparse(RakuAST::Term::TopicCall:D $ast --> Str:D) {
        self.deparse($ast.call)
    }

    multi method deparse(RakuAST::Term::Whatever:D $ --> Str:D) {
        self.hsyn('var-term', $.term-whatever)
    }

#- Ternary ---------------------------------------------------------------------

    multi method deparse(RakuAST::Ternary:D $ast --> Str:D) {
        my $heredoc := $*HEREDOC;

        # no place to store heredocs, make one, try again, add them at the end
        if nqp::istype($heredoc,Failure) {
            my $*TERNARY = "";  # indenting for nested ternaries

            $heredoc := my $*HEREDOC := my str @;
            my $deparsed := self.deparse($ast);

            return nqp::elems($heredoc)
              ?? $deparsed ~ $heredoc.join ~ "\n"
              !! $deparsed
        }

        # already have a place to store heredocs
        my $then := $ast.then;
        my $else := $ast.else;
        my $intern := $*TERNARY;
        my $nested := $intern
          || nqp::istype($then,RakuAST::Ternary)
          || nqp::istype($else,RakuAST::Ternary);
        my str $indent = $nested
          ?? "\n" ~ ($intern ~= '  ').chop  # assume 1 space left of ?? !!
          !! '';

        my str @parts =
          self.deparse($ast.condition),
          $indent,
          self.hsyn('ternary', $.ternary1);

        # helper sub for a ternary part
        sub deparse-part($node --> Nil) {
            if nqp::istype($node,RakuAST::Heredoc) {
                my str ($header,$rest) = self.deparse($node).split("\n",2);
                @parts.push($header);
                $heredoc.push("\n" ~ $rest.chomp);
            }
            else {
                @parts.push(self.deparse($node));
            }
        }

        deparse-part($then);
        @parts.push($indent);
        @parts.push(self.hsyn('ternary', $.ternary2));
        deparse-part($else);

        @parts.join
    }

#- Trait -----------------------------------------------------------------------

    multi method deparse(RakuAST::Trait::Is:D $ast --> Str:D) {
        my str $base = self.syn-trait($ast.IMPL-TRAIT-NAME)
          ~ ' '
          ~ self.deparse($ast.name);
        with $ast.argument {
            $base ~ self.deparse($_)
        }
        else {
            $base
        }
    }

    multi method deparse(RakuAST::Trait::Type:D $ast --> Str:D) {
        self.syn-trait($ast.IMPL-TRAIT-NAME) ~ ' ' ~ self.deparse($ast.type)
    }

#- Type ------------------------------------------------------------------------

    multi method deparse(RakuAST::Type::Capture:D $ast --> Str:D) {
        '::' ~ self.deparse($ast.name)
    }

    multi method deparse(RakuAST::Type::Coercion:D $ast --> Str:D) {
        my str $constraint = self.deparse($ast.constraint);
        $constraint = "" if $constraint eq 'SETTING::<Any>';
        self.deparse($ast.base-type) ~ "($constraint)"
    }

    multi method deparse(RakuAST::Type::Definedness:D $ast --> Str:D) {
        self.deparse($ast.base-type.name)
          ~ ($ast.definite ?? ':D' !! ':U')
    }

    multi method deparse(RakuAST::Type::Enum:D $ast --> Str:D) {
        my str @parts = self.syn-typer('enum');

        my str $scope = $ast.scope;
        @parts.unshift(self.syn-scope($scope))
          if $scope && $scope ne $ast.default-scope;

        @parts.unshift(self.deparse($_)) with $ast.of;
        @parts.push(self.deparse($_)) with $ast.name;

        if $ast.clean-clone.traits -> @traits {
            @parts.push(self.deparse($_)) for @traits;
        }
        @parts.push(self.deparse($ast.term));

        self.add-any-docs(@parts.join(' '), $ast.WHY)
    }

    multi method deparse(RakuAST::Type::Parameterized:D $ast --> Str:D) {
        my str $args = self.deparse($ast.args);
        self.deparse($ast.base-type) ~ ($args ?? "[$args]" !! "")
    }

    multi method deparse(RakuAST::Type::Setting:D $ast --> Str:D) {
        my str @parts = nqp::split('::',self.deparse($ast.name));
        my str $root = @parts.shift;

        'SETTING::<' ~ $root ~ '>' ~ @parts.map({ '.WHO<' ~ $_ ~ '>' }).join
    }

    multi method deparse(RakuAST::Type::Simple:D $ast --> Str:D) {
        self.deparse($ast.name)
    }

    multi method deparse(RakuAST::Type::Subset:D $ast --> Str:D) {
        my str @parts = self.syn-typer('subset');

        my str $scope = $ast.scope;
        @parts.unshift(self.syn-scope($scope))
          if $scope && $scope ne $ast.default-scope;

        @parts.push(self.deparse($ast.name));
        @parts.push(self.deparse($_)) with $ast.of;
        @parts.push(self.deparse($_)) for $ast.traits;
        @parts.push('where ' ~ self.deparse($_)) with $ast.where;

        self.add-any-docs(@parts.join(' '), $ast.WHY)
    }

#- Var -------------------------------------------------------------------------

    multi method deparse(RakuAST::Var::Attribute:D $ast --> Str:D) {
        self.hsyn('var-attribute', $ast.name)
    }

    multi method deparse(RakuAST::Var::Compiler::File:D $ast --> Str:D) {
        self.hsyn('var-compile',$.var-compiler-file)
    }

    multi method deparse(RakuAST::Var::Compiler::Line:D $ast --> Str:D) {
        self.hsyn('var-compile', $.var-compiler-line)
    }

    multi method deparse(RakuAST::Var::Compiler::Lookup:D $ast --> Str:D) {
        self.hsyn('var-compile', $ast.name)
    }

    multi method deparse(RakuAST::Var::Doc:D $ast --> Str:D) {
        self.hsyn('var-rakudoc', '$=' ~ $ast.name)
    }

    multi method deparse(RakuAST::Var::Dynamic:D $ast --> Str:D) {
        self.hsyn('var-dynamic', $ast.name)
    }

    multi method deparse(RakuAST::Var::Lexical:D $ast --> Str:D) {
        my $name := $ast.name;
        self.hsyn('var-lexical',$name.starts-with('$whatevercode_arg_') ?? '*' !! $name)
    }

    multi method deparse(RakuAST::Var::Lexical::Setting:D $ast --> Str:D) {
        self.hsyn('var-setting', 'SETTING::<' ~ $ast.name ~ '>')
    }

    multi method deparse(RakuAST::Var::NamedCapture:D $ast --> Str:D) {
        self.hsyn('cap-named', '$' ~ self.deparse($ast.index))
    }

    multi method deparse(RakuAST::Var::Package:D $ast --> Str:D) {
        self.hsyn('var-package', $ast.sigil ~ self.deparse($ast.name))
    }

    multi method deparse(RakuAST::Var::PositionalCapture:D $ast --> Str:D) {
        self.hsyn('cap-positional', '$' ~ $ast.index.Str)
    }

#- VarDeclaration --------------------------------------------------------------

    multi method deparse(RakuAST::VarDeclaration::Anonymous:D $ast --> Str:D) {
        my str $sigil = $ast.sigil;
        my str $scope = $ast.scope;

        $scope eq 'state'
          ?? $sigil
          !! self.xsyn('scope', $scope) ~ ' ' ~ $sigil
    }

    multi method deparse(RakuAST::VarDeclaration::Auto:D $ast --> Str:D) {
        self.deparse(RakuAST::Var::Lexical.new($ast.name))
    }

    multi method deparse(RakuAST::VarDeclaration::Constant:D $ast --> Str:D) {
        my str @parts;

        my str $scope = $ast.scope;
        @parts.push(self.syn-scope($scope))
          if $scope ne $ast.default-scope;

        @parts.push(self.syn-type($_)) with $ast.type;
        @parts.push(self.xsyn('scope', 'constant'));
        @parts.push($ast.name);
        if $ast.traits -> @traits {
            @parts.push(self.deparse($_)) for @traits;
        }
        @parts.push(self.deparse($ast.initializer).trim-leading);

        @parts.join(' ');
    }

    multi method deparse(RakuAST::VarDeclaration::Implicit:D $ast --> Str:D) {
        self.hsyn('var-implicit', $ast.name)
    }

    multi method deparse(
      RakuAST::VarDeclaration::Implicit::Constant:D $ast
    --> Str:D) {
        (self.hsyn('scope-my', self.xsyn('scope', 'my')),
          self.hsyn('scope-constant', self.xsyn('scope', 'constant')),
          self.hsyn('var-term', $ast.name),
          self.hsyn('infix', '='),
          $ast.value.raku
        ).join(' ')
    }

    multi method deparse(
      RakuAST::VarDeclaration::Placeholder::Named:D $ast
    --> Str:D) {
        self.hsyn('var-placeholder', .substr(0, 1) ~ ':' ~ .substr(1))
          given $ast.lexical-name
    }

    multi method deparse(
      RakuAST::VarDeclaration::Placeholder::Positional:D $ast
    --> Str:D) {
        self.hsyn('var-placeholder', .substr(0, 1) ~ '^' ~ .substr(1))
          given $ast.lexical-name
    }

    multi method deparse(
      RakuAST::VarDeclaration::Placeholder::SlurpyArray:D $
    --> Str:D) {
        self.hsyn('var-placeholder', '@_')
    }

    multi method deparse(
      RakuAST::VarDeclaration::Placeholder::SlurpyHash:D $
    --> Str:D) {
        self.hsyn('var-placeholder', '%_')
    }

    multi method deparse(RakuAST::VarDeclaration::Signature:D $ast --> Str:D) {
        my str @parts = self.syn-scope($ast.scope);
        @parts.push(self.syn-type($_)) with $ast.type;
        @parts.push('(' ~ self.deparse($ast.signature) ~ ')');

        if $ast.initializer -> $initializer {
            @parts.push(self.deparse($initializer));
        }

        @parts.join(' ')
    }

    multi method deparse(RakuAST::VarDeclaration::Simple:D $ast --> Str:D) {
        my str $scope = $ast.scope;
        my str @parts;

        @parts.push(self.syn-scope($ast.scope));
        @parts.push(' ');

        if $ast.type -> $type {
            @parts.push(self.syn-type($type));
            @parts.push(' ');
        }

        my str $twigil = $ast.twigil;
        @parts.push(
          self.hsyn(%twigil2type{$twigil} // 'var-lexical', $ast.name)
        );

        if $ast.traits -> @traits {
            for @traits {
                @parts.push(' ');
                @parts.push(self.deparse($_));
            }
        }

        if $ast.initializer -> $initializer {
            @parts.push(self.deparse($initializer));
        }

        self.add-any-docs(@parts.join, $ast.WHY)
    }

    multi method deparse(RakuAST::VarDeclaration::Term:D $ast --> Str:D) {
        my str @parts;

        @parts.push(self.syn-scope($ast.scope));
        @parts.push(' ');

        if $ast.type -> $type {
            @parts.push(self.syn-type($type));
            @parts.push(' ');
        }

        @parts.push(Q/\/);
        @parts.push(self.hsyn('var-term', self.deparse($ast.name)));

        @parts.push(self.deparse($ast.initializer));

        @parts.join
    }

}

nqp::bindhllsym('Raku', 'DEPARSE', RakuAST::Deparse);

# vim: expandtab shiftwidth=4
