# Marker for anything that can be used as the source for a capture.
class RakuAST::CaptureSource
  is RakuAST::Node { }

# Everything that can appear as an expression does RakuAST::Expression.
class RakuAST::Expression
  is RakuAST::IMPL::ImmediateBlockUser
{
    # All expressions can be thunked - that is, compiled such that they get
    # wrapped up in a code object of some kind. For such expressions, this
    # thunks attribute will point to a linked list of thunks to apply, the
    # outermost first. (Rationale: we'll add these at check time, and children
    # are visited ahead of parents. Adding to a linked list at the start is
    # cheapest.
    has Mu $!thunks;

    method wrap-with-thunk(RakuAST::ExpressionThunk $thunk) {
        $thunk.set-next($!thunks) if $!thunks;
        nqp::bindattr(self, RakuAST::Expression, '$!thunks', $thunk);
        Nil
    }

    method dump-extras(int $indent) {
        my $prefix := nqp::x(' ', $indent);
        my @chunks;
        self.visit-thunks(-> $thunk {
            @chunks.push("$prefix🧠 " ~ $thunk.thunk-kind ~ "\n");
            $thunk.visit-children(-> $child {
                @chunks.push($child.dump($indent + 2));
            });
        });
        nqp::join('', @chunks)
    }

    method IMPL-QAST-ADD-THUNK-DECL-CODE(RakuAST::IMPL::QASTContext $context, Mu $target) {
        if $!thunks {
            $!thunks.IMPL-THUNK-CODE-QAST($context, $target, self);
        }
    }

    method IMPL-TO-QAST(RakuAST::IMPL::QASTContext $context, *%opts) {
        $!thunks
            ?? $!thunks.IMPL-THUNK-VALUE-QAST($context)
            !! self.IMPL-EXPR-QAST($context, |%opts)
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        nqp::die('Missing IMPL-EXPR-QAST method on ' ~ self.HOW.name(self))
    }

    method visit-thunks(Code $visitor) {
        my $cur-thunk := $!thunks;
        while $cur-thunk {
            $visitor($cur-thunk);
            $cur-thunk := $cur-thunk.next;
        }
    }

    method outer-most-thunk() {
        $!thunks
    }

    method IMPL-CURRY(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context, Str $arg) {
        my $thunk := RakuAST::CurryThunk.new($arg);
        $thunk.IMPL-CHECK($resolver, $context, True);
        self.wrap-with-thunk($thunk);
        $thunk
    }

    method IMPL-CURRIED() {
        my $cur-thunk := $!thunks;
        while $cur-thunk {
            return $cur-thunk if nqp::istype($cur-thunk, RakuAST::CurryThunk);
            $cur-thunk := $cur-thunk.next;
        }
        False
    }

    method IMPL-UNCURRY() {
        my $prev-thunk;
        my $cur-thunk := $!thunks;
        while $cur-thunk {
            if nqp::istype($cur-thunk, RakuAST::CurryThunk) {
                my $params := $cur-thunk.IMPL-PARAMS;
                if $prev-thunk {
                    $prev-thunk.set-next($cur-thunk.next);
                }
                else {
                    nqp::bindattr(self, RakuAST::Expression, '$!thunks', $cur-thunk.next);
                }
                return $params;
            }
            $prev-thunk := $cur-thunk;
            $cur-thunk := $cur-thunk.next;
        }
        nqp::die("UNCURRY didn't find a CurryThunk");
    }

    method IMPL-IMMEDIATELY-USES(RakuAST::Code $node) {
        $!thunks ?? True !! False
    }

    method IMPL-ADJUST-QAST-FOR-LVALUE(Mu $qast) {
        $qast
    }
}

#-------------------------------------------------------------------------------
# Role for handling operator properties

class RakuAST::OperatorProperties
{

    # Obtain operator properties from config or from actual object
    method properties() {
        my $properties;
        if nqp::can(self,'is-resolved') {

            # This feels very much like a hack, and should probably be
            # changed at some time.  Perhaps when we get a "parse time"
            # stage?
            self.resolve-with($*R) if !self.is-resolved && $*R;

            if self.is-resolved {
                my $resolution := self.resolution;
                $properties := $resolution.compile-time-value.op_props
                  if nqp::istype($resolution,RakuAST::CompileTimeValue);
            }
        }

        nqp::isconcrete($properties)
          ?? $properties
          !! self.default-operator-properties
    }
}

#-------------------------------------------------------------------------------
# Infix operators

# Marker for all kinds of infixish operators.
class RakuAST::Infixish
  is RakuAST::ImplicitLookups
{
    method IMPL-LIST-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operands) {
        nqp::die('Cannot compile ' ~ self.HOW.name(self) ~ ' as a list infix');
    }

    # A node can implement this if it wishes to have full control of the
    # compilation of nodes. Most implement IMPL-INFIX-QAST, which gets the
    # QAST of the operands.
    method IMPL-INFIX-COMPILE(RakuAST::IMPL::QASTContext $context,
            RakuAST::Expression $left, RakuAST::Expression $right) {
        self.IMPL-INFIX-QAST: $context, $left.IMPL-TO-QAST($context),
            $right.IMPL-TO-QAST($context)
    }

    method IMPL-THUNK-ARGUMENTS(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context,
                                RakuAST::Expression *@operands) {
    }

    # %curried == 0 means do not curry
    # %curried == 1 means curry Whatever only
    # %curried == 2 means curry WhateverCode only
    # %curried == 3 means curry both Whatever and WhateverCode (default)
    method IMPL-CURRIES() { 0 }
}

# A simple (non-meta) infix operator. Some of these are just function calls,
# others need more special attention.
class RakuAST::Infix
  is RakuAST::Infixish
  is RakuAST::OperatorProperties
  is RakuAST::Lookup
{
    has str $.operator;

    method new(str $operator) {
        my $obj := nqp::create(self);
        nqp::bindattr_s($obj, RakuAST::Infix, '$!operator', $operator);
        $obj
    }

    method default-operator-properties() {
        OperatorProperties.infix($!operator)
    }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('Match')),
        ])
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-infix($!operator);
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method reducer-name() { self.properties.reducer-name }

    method IMPL-THUNK-ARGUMENT(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context,
                               RakuAST::Expression $expression, str $type) {
        if $type eq 'b' && !nqp::istype($expression, RakuAST::Code) {
            my $thunk := RakuAST::BlockThunk.new;
            $thunk.IMPL-CHECK($resolver, $context, True);
            $expression.wrap-with-thunk($thunk);
        }
        elsif $type eq 't' && !nqp::istype($expression, RakuAST::Code) {
            my $thunk := RakuAST::ExpressionThunk.new;
            $thunk.IMPL-CHECK($resolver, $context, True);
            $expression.wrap-with-thunk($thunk);
        }
        # TODO implement other thunk types
    }

    method IMPL-THUNK-ARGUMENTS(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context,
                                RakuAST::Expression *@operands) {
        if (
               $!operator eq 'xx'     || $!operator eq 'andthen'
            || $!operator eq 'orelse' || $!operator eq 'notandthen'
            || $!operator eq 'with'   || $!operator eq 'without'
        ) {
            my $thunky := self.properties.thunky;
            my $i := 0;
            for @operands {
                my $type := nqp::substr($thunky, $i, $i + 1);
                if $type && $type ne '.' {
                    self.IMPL-THUNK-ARGUMENT($resolver, $context, $_, $type);
                }
                $i++ if $i < nqp::chars($thunky) - 1;
            }
        }
    }

    method IMPL-CURRIES() {
        # Lookup of infix operators and whether either left / right side
        # will curry:
        #  0 = do not curry
        #  1 = curry Whatever only
        #  2 = curry WhateverCode only
        #  3 = curry both Whatever and WhateverCode (default)
        my constant CURRIED := nqp::hash(
            '...'   , 0,
            '…'     , 0,
            '...^'  , 0,
            '…^'    , 0,
            '^...'  , 0,
            '^…'    , 0,
            '^...^' , 0,
            '^…^'   , 0,
            '='     , 0,
            ':='    , 0,
            '&&',   , 0,
            '||',   , 0,
            '~~'    , 1,
            '∘'     , 1,
            'o'     , 1,
            '..'    , 2,
            '..^'   , 2,
            '^..'   , 2,
            '^..^'  , 2,
            'xx'    , 2,
        );
        CURRIED{$!operator} // 3
    }

    method IMPL-INFIX-COMPILE(RakuAST::IMPL::QASTContext $context,
            RakuAST::Expression $left, RakuAST::Expression $right) {
        # Hash value is negation flag
        my constant OP-SMARTMATCH := nqp::hash( '~~', 0, '!~~', 1 );
        my str $op := $!operator;
        if $op eq ':=' {
            if $left.can-be-bound-to {
                $left.IMPL-BIND-QAST($context, $right.IMPL-TO-QAST($context))
            }
            else {
                nqp::die('Cannot compile bind to ' ~ $left.HOW.name($left));
            }
        }
        elsif nqp::existskey(OP-SMARTMATCH, $op) && !nqp::istype($right, RakuAST::Var) {
            self.IMPL-SMARTMATCH-QAST($context, $left, $right, nqp::atkey(OP-SMARTMATCH, $op));
        }
        else {
            self.IMPL-INFIX-QAST:
                $context,
                $op eq '='
                    ?? $left.IMPL-ADJUST-QAST-FOR-LVALUE($left.IMPL-TO-QAST($context))
                    !! $left.IMPL-TO-QAST($context),
                $right.IMPL-TO-QAST($context)
        }
    }

    method IMPL-INFIX-QAST(
      RakuAST::IMPL::QASTContext $context,
                              Mu $left-qast,
                              Mu $right-qast
    ) {
        # Operators that map directly into a QAST op
        my constant QAST-OP := nqp::hash(
          '||',  'unless',
          'or',  'unless',
          '&&',  'if',
          'and', 'if',
          '^^',  'xor',
          'xor', 'xor',
          '//',  'defor'
        );

        (my str $op := QAST-OP{$!operator})
          # Directly mapping
          ?? QAST::Op.new(:$op, $left-qast, $right-qast)
          # Otherwise, it's called by finding the lexical sub to call, and
          # compiling it as chaining if required.
          !! QAST::Op.new(
               :op(self.properties.chain ?? 'chain' !! 'call'),
               :name(self.resolution.lexical-name),
               $left-qast,
               $right-qast
             )
    }

    method IMPL-SMARTMATCH-QAST( RakuAST::IMPL::QASTContext $context,
                                 RakuAST::Expression $left,
                                 RakuAST::Expression $right,
                                 int $negate ) {
        # Handle cases of s/// or m// separately. For a non-negating smartmatch this case could've been reduced to
        # plain topic localization except that we must ensure a False returned when there is no match.
        if nqp::istype($right, RakuAST::RegexThunk)
            && (!nqp::can($right, 'match-immediately') || $right.match-immediately)
        {
            my $match-type :=
              self.get-implicit-lookups.AT-POS(0).resolution.compile-time-value;
            my $result-local := QAST::Node.unique('!sm-result');
            my $rhs := $right.IMPL-EXPR-QAST($context);
            return self.IMPL-TEMPORARIZE-TOPIC(
                $left.IMPL-TO-QAST($context),
                $negate
                    ?? QAST::Op.new( :op<callmethod>, :name<not>, $rhs)
                    !! QAST::Op.new( :op<unless>, $rhs, QAST::WVal.new( :value(False) )));
        }

        my $accepts-call;
        if $negate {
            $accepts-call := QAST::Op.new(
                :op<callmethod>, :name<not>,
                QAST::Op.new(
                    :op('callmethod'), :name('ACCEPTS'),
                    $right.IMPL-TO-QAST($context),
                    QAST::Var.new(:name<$_>, :scope<lexical>)));
        }
        else {
            my $rhs-local := QAST::Node.unique('!sm-rhs');
            $accepts-call := QAST::Op.new(
                :op('callmethod'), :name('ACCEPTS'),
                QAST::Var.new( :name($rhs-local), :scope<local> ),
                QAST::Var.new(:name<$_>, :scope<lexical>));
            $accepts-call := QAST::Op.new(
                :op<if>,
                QAST::Op.new(
                    :op<istype>,
                    QAST::Op.new(
                        :op<bind>,
                        QAST::Var.new( :name($rhs-local), :scope<local>, :decl<var> ),
                        $right.IMPL-TO-QAST($context),
                    ),
                    QAST::WVal.new( :value(Regex) )),
                $accepts-call,
                QAST::Op.new(
                    :op<callmethod>,
                    :name<Bool>,
                    $accepts-call ));
        }
        self.IMPL-TEMPORARIZE-TOPIC( $left.IMPL-TO-QAST($context), $accepts-call )
    }

    method IMPL-LIST-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operands) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name );
        for $operands {
            $op.push($_);
        }
        $op
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        my $name := self.resolution.lexical-name;
        QAST::Var.new( :scope('lexical'), :$name )
    }

    method IMPL-CAN-INTERPRET() {
        nqp::istype(self.resolution,RakuAST::CompileTimeValue)
          && !self.properties.short-circuit
          && !self.properties.chain
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx, List $operands) {
        my $op := self.resolution.compile-time-value;
        my @operands;
        for self.IMPL-UNWRAP-LIST($operands) {
            nqp::push(@operands, $_.IMPL-INTERPRET($ctx));
        }
        $op(|@operands)
    }
}

class RakuAST::Feed
  is RakuAST::Infix
  is RakuAST::BeginTime
{
    method new(str $operator) {
        my $obj := nqp::create(self);
        nqp::bindattr_s($obj, RakuAST::Infix, '$!operator', $operator);
        $obj
    }

    method PERFORM-BEGIN(Resolver $resolver, Context $context) {
        my $operator := nqp::getattr_s(self, RakuAST::Infix, '$!operator');
        if $operator eq "==>>" || $operator eq "<<==" {
            self.add-sorry:
                $resolver.build-exception: 'X::Comp::NYI', :feature($operator ~ " feed operator");
        }
    }

    method IMPL-LIST-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operands) {
        my @stages;
        my $operator := nqp::getattr_s(self, RakuAST::Infix, '$!operator');
        if $operator eq "==>" {
            for $operands {
                @stages.push: $_;
            }
        } else {  # "<<==" and "==>>" are NYI, caught already in the grammar actions
            for $operands {
                @stages.unshift: $_;
            }
        }

        # Check what's in each stage and make a chain of blocks
        # that call each other. They'll return lazy things, which
        # will be passed in as var-arg parts to other things. The
        # first thing is just considered the result.
        my $result := @stages.shift;
        for @stages {
            my $stage := $_;
            # Wrap current result in a block, so it's thunked and can be
            # called at the right point.
            $result := QAST::Block.new( $result );

            # Check what we have. XXX Real first step should be looking
            # for @(*) since if we find that it overrides all other things.
            # But that's todo...soon. :-)
            if nqp::istype($stage, QAST::Op) && $stage.op eq 'call' {
                # It's a call. Stick a call to the current supplier in
                # as its last argument.
                $stage.push(QAST::Op.new( :op('call'), $result ));
            }
            elsif nqp::istype($stage, QAST::Var) {
                # It's a variable. We need code that gets the results, pushes
                # them onto the variable and then returns them (since this
                # could well be a tap.
                my $tmp := QAST::Node.unique('feed_tmp');
                $stage := QAST::Stmts.new(
                    QAST::Op.new(
                        :op('bind'),
                        QAST::Var.new( :scope('local'), :name($tmp), :decl('var') ),
                        QAST::Op.new(
                            :op('callmethod'), :name('list'),
                            QAST::Op.new( :op('call'), $result )
                            ),
                        ),
                    QAST::Op.new(
                        :op('callmethod'), :name('append'),
                        $stage,
                        QAST::Var.new( :scope('local'), :name($tmp) )
                        ),
                    QAST::Var.new( :scope('local'), :name($tmp) )
                    );
                $stage := QAST::Op.new( :op('locallifetime'), $stage, $tmp );
            }
            else {
                my str $error := "Only routine calls or variables that can '.append' may appear on either side
of feed operators.";
                if nqp::istype($stage, QAST::Children) && nqp::istype($stage[0], QAST::Var) {
                    if nqp::istype($stage, QAST::Op) && $stage.op eq 'ifnull'
                        && nqp::eqat($stage[0].name, '&', 0) {
                        $error := "A feed may not sink values into a code object.
Did you mean a call like '"
                            ~ nqp::substr($stage[0].name, 1)
                            ~ "()' instead?";
                    }

                    # Looks like an array, yet we wound up here (which we
                    # wouldn't if it was an ordinary array.  Assume it's
                    # a shaped array definition throwing a spanner into the
                    # works.
                    elsif nqp::eqat($stage[0].name, '@', 0) {
                        $error := "Cannot feed into shaped arrays, as one cannot '.append' to them.";
                    }
                }
                $_.PRECURSOR.panic($error);
            }
            $result := $stage;
        }
        $result
    }
}

# Assignment is a special case of infix, as it behaves differently in the
# grammar depending on context.  This subclass covers the case of needing
# to be able to provide different operator properties depending on item
# or list assignment.  Deparses as a normal infix otherwise, this is purely
# to make the grammar do the right thing depending on context.
class RakuAST::Assignment
  is RakuAST::Infix
{
    has int                $.item;
    has OperatorProperties $.properties;

    method new(Bool :$item) {
        my $obj := nqp::create(self);
        nqp::bindattr_s($obj,RakuAST::Infix,'$!operator','=');
        nqp::bindattr_i($obj,RakuAST::Assignment,'$!item',$item ?? 1 !! 0);
        nqp::bindattr($obj,RakuAST::Assignment,'$!properties',
          OperatorProperties.infix($item ?? '$=' !! '@='));
        $obj
    }
    method item { $!item ?? True !! False }
}

# A bracketed infix.
class RakuAST::BracketedInfix
  is RakuAST::Infixish
{
    has RakuAST::Infixish $.infix;

    method new(RakuAST::Infixish $infix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::BracketedInfix, '$!infix', $infix);
        $obj
    }

    method properties() { $!infix.properties }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method reducer-name() { $!infix.reducer-name }

    method IMPL-INFIX-COMPILE(RakuAST::IMPL::QASTContext $context,
            RakuAST::Expression $left, RakuAST::Expression $right) {
        $!infix.IMPL-INFIX-COMPILE($context, $left, $right)
    }

    method IMPL-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $left-qast, Mu $right-qast) {
        $!infix.IMPL-INFIX-QAST($context, $left-qast, $right-qast)
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        $!infix.IMPL-HOP-INFIX-QAST($context)
    }
}

# A function infix (`$x [&func] $y`).
class RakuAST::FunctionInfix
  is RakuAST::Infixish
{
    has RakuAST::Expression $.function;

    method new(RakuAST::Expression $function) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::FunctionInfix, '$!function', $function);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!function);
    }

    method properties() {
        # Should check if operator properties can be derived from $!function,
        # and should default to:
        OperatorProperties.infix('+')
    }

    method reducer-name() { '&METAOP_REDUCE_LEFT' }

    method IMPL-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $left-qast, Mu $right-qast) {
        QAST::Op.new:
            :op('call'),
            $!function.IMPL-TO-QAST($context),
            $left-qast, $right-qast
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        $!function.IMPL-TO-QAST($context)
    }
}

#-------------------------------------------------------------------------------
# Meta infixes

# Base class, mostly for type checking
class RakuAST::MetaInfix
  is RakuAST::Infixish
  is RakuAST::CheckTime
{
    method IMPL-HOP-INFIX() {
        self.get-implicit-lookups().AT-POS(0).resolution.compile-time-value()(
            self.infix.resolution.compile-time-value
        )
    }

    method PERFORM-CHECK(
               RakuAST::Resolver $resolver,
      RakuAST::IMPL::QASTContext $context
    ) {
        self.properties.fiddly
          ?? $resolver.add-sorry(
               $resolver.build-exception("X::Syntax::CannotMeta",
                 meta     => "negate",
                 operator => self.infix.operator,
                 dba      => self.properties.dba,
                 reason   => "too fiddly"
               )
             )
          !! True
    }
}

# An assign meta-operator, operator on another infix.
class RakuAST::MetaInfix::Assign
  is RakuAST::MetaInfix
{
    has RakuAST::Infixish $.infix;

    method new(RakuAST::Infixish $infix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaInfix::Assign, '$!infix', $infix);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method PERFORM-CHECK(
               RakuAST::Resolver $resolver,
      RakuAST::IMPL::QASTContext $context
    ) {
        my $properties := self.properties;
        $properties.fiddly || $properties.diffy
          ?? $resolver.add-sorry(
               $resolver.build-exception("X::Syntax::CannotMeta",
                 meta     => "assign",
                 operator => self.infixx.operator,
                 reason   => "too fiddly or diffy"
               )
             )
          !! True
    }

    method properties() { OperatorProperties.infix('$=') }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('&METAOP_ASSIGN')),
        ])
    }

    method IMPL-CURRIES() { 0 }

    method IMPL-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $left-qast, Mu $right-qast) {
        if nqp::istype($!infix, RakuAST::Infix) && $!infix.properties.short-circuit {
            # TODO case-analyzed assignments
            my $temp := QAST::Node.unique('meta_assign');
            my $bind-lhs := QAST::Op.new(
              :op<bind>,
              QAST::Var.new(:decl('var'), :scope('local'), :name($temp)),
              $left-qast
            );
            # Compile the short-circuit ones "inside out", so we can avoid the
            # assignment.
            QAST::Stmt.new(
                $bind-lhs,
                $!infix.IMPL-INFIX-QAST(
                    $context,
                    QAST::Var.new( :scope('local'), :name($temp) ),
                    QAST::Op.new(
                        :op('assign'),
                        QAST::Var.new( :scope('local'), :name($temp) ),
                        $right-qast
                    )
                )
            )
        }
        else {
            QAST::Op.new(:op<call>,
              self.IMPL-HOP-INFIX-QAST($context) , $left-qast, $right-qast
            )
        }
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        QAST::Op.new:
            :op('callstatic'), :name('&METAOP_ASSIGN'),
            $!infix.IMPL-HOP-INFIX-QAST($context)
    }
}

# The negate infix meta-operator (e.g. $a !cmp $b)
class RakuAST::MetaInfix::Negate
  is RakuAST::MetaInfix
{
    has RakuAST::Infixish $.infix;

    method new(RakuAST::Infixish $infix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaInfix::Negate, '$!infix', $infix);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method PERFORM-CHECK(
               RakuAST::Resolver $resolver,
      RakuAST::IMPL::QASTContext $context
    ) {
        self.properties.iffy
          || $resolver.add-sorry:
               $resolver.build-exception: "X::Syntax::CannotMeta",
                 meta     => "negate",
                 operator => self.infix.operator,
                 dba      => self.properties.dba,
                 reason   => "not iffy enough"
    }

    method properties() { $!infix.properties }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('&METAOP_NEGATE')),
        ])
    }

    method IMPL-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $left-qast, Mu $right-qast) {
        QAST::Op.new(:op<hllbool>,
          QAST::Op.new(:op<isfalse>,
            $!infix.IMPL-INFIX-QAST($context, $left-qast, $right-qast)
          )
        )
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        QAST::Op.new(:op<call>,
          :name<&METAOP_NEGATE>, $!infix.IMPL-HOP-INFIX-QAST($context)
        )
    }
}

# A reverse meta-operator.
class RakuAST::MetaInfix::Reverse
  is RakuAST::MetaInfix
{
    has RakuAST::Infixish $.infix;

    method new(RakuAST::Infixish $infix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaInfix::Reverse, '$!infix', $infix);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method properties() { $!infix.properties }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('&METAOP_REVERSE')),
        ])
    }

    method IMPL-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $left-qast, Mu $right-qast) {
        $!infix.IMPL-INFIX-QAST($context, $right-qast, $left-qast)
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        QAST::Op.new:
            :op('callstatic'), :name('&METAOP_REVERSE'),
            $!infix.IMPL-HOP-INFIX-QAST($context)
    }
}

# A cross meta-operator.
class RakuAST::MetaInfix::Cross
  is RakuAST::MetaInfix
{
    has RakuAST::Infixish $.infix;

    method new(RakuAST::Infixish $infix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaInfix::Cross, '$!infix', $infix);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method properties() { OperatorProperties.infix('X') }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('&METAOP_CROSS')),
        ])
    }

    method IMPL-LIST-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operands) {
        my $op := QAST::Op.new( :op('call'), self.IMPL-HOP-INFIX-QAST($context) );
        for $operands {
            $op.push($_);
        }
        $op
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        QAST::Op.new:
            :op('callstatic'), :name('&METAOP_CROSS'),
            $!infix.IMPL-HOP-INFIX-QAST($context),
            QAST::Var.new( :name($!infix.reducer-name), :scope('lexical') )
    }
}

# A zip meta-operator.
class RakuAST::MetaInfix::Zip
  is RakuAST::MetaInfix
{
    has RakuAST::Infixish $.infix;

    method new(RakuAST::Infixish $infix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaInfix::Zip, '$!infix', $infix);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method properties() { OperatorProperties.infix('Z') }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('&METAOP_ZIP')),
        ])
    }

    method IMPL-LIST-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operands) {
        my $op := QAST::Op.new( :op('call'), self.IMPL-HOP-INFIX-QAST($context) );
        for $operands {
            $op.push($_);
        }
        $op
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        QAST::Op.new:
            :op('callstatic'), :name('&METAOP_ZIP'),
            $!infix.IMPL-HOP-INFIX-QAST($context),
            QAST::Var.new( :name($!infix.reducer-name), :scope('lexical') )
    }
}

# An infix hyper operator.
class RakuAST::MetaInfix::Hyper
  is RakuAST::MetaInfix
{
    has RakuAST::Infixish $.infix;
    has Bool $.dwim-left;
    has Bool $.dwim-right;

    method new(RakuAST::Infixish :$infix!, Bool :$dwim-left, Bool :$dwim-right) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaInfix::Hyper, '$!infix', $infix);
        nqp::bindattr($obj, RakuAST::MetaInfix::Hyper, '$!dwim-left',
            $dwim-left ?? True !! False);
        nqp::bindattr($obj, RakuAST::MetaInfix::Hyper, '$!dwim-right',
            $dwim-right ?? True !! False);
        $obj
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
    }

    method properties() { $!infix.properties }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('&METAOP_HYPER')),
        ])
    }

    method IMPL-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $left-qast, Mu $right-qast) {
        QAST::Op.new:
            :op('call'),
            self.IMPL-HOP-INFIX-QAST($context),
            $left-qast,
            $right-qast
    }

    method IMPL-HOP-INFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        my $call := QAST::Op.new:
            :op('callstatic'), :name('&METAOP_HYPER'),
            $!infix.IMPL-HOP-INFIX-QAST($context);
        if $!dwim-left {
            $call.push: QAST::WVal.new: :value(True), :named('dwim-left');
        }
        if $!dwim-right {
            $call.push: QAST::WVal.new: :value(True), :named('dwim-right');
        }
        $call
    }

    method IMPL-HOP-INFIX() {
        self.get-implicit-lookups().AT-POS(0).resolution.compile-time-value()(
            self.infix.resolution.compile-time-value,
            :dwim-left($!dwim-left),
            :dwim-right($!dwim-right)
        )
    }
}

#-------------------------------------------------------------------------------
# Application of operators

# Application of an infix operator.
class RakuAST::ApplyInfix
  is RakuAST::Expression
  is RakuAST::BeginTime
  is RakuAST::CheckTime
{
    has RakuAST::Infixish $.infix;
    has RakuAST::ArgList  $.args;

    method new(RakuAST::Infixish :$infix!, RakuAST::Expression :$left!,
            RakuAST::Expression :$right!) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj,RakuAST::ApplyInfix,'$!infix',$infix);
        nqp::bindattr($obj,RakuAST::ApplyInfix,'$!args',RakuAST::ArgList.new);
        $obj.set-left($left);
        $obj.set-right($right);
        $obj
    }

    method left() { $!args.arg-at-pos(0) }
    method set-left(RakuAST::Expression $left) {
        $!args.set-arg-at-pos(0, $left);
    }
    method right() { $!args.arg-at-pos(1) }
    method set-right(RakuAST::Expression $right) {
        $!args.set-arg-at-pos(1, $right);
    }
    method add-colonpair(RakuAST::ColonPair $pair) {
        $!args.push($pair);
        Nil
    }

    method PERFORM-BEGIN(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        my $infix   := $!infix;
        my $CURRIES := $infix.IMPL-CURRIES;
        my $left    := self.left;
        my $right   := self.right;

        if nqp::bitand_i($CURRIES,2) && (my $curried := $left.IMPL-CURRIED) {
            my $params := $left.IMPL-UNCURRY;
            self.IMPL-CURRY($resolver, $context, '') unless self.IMPL-CURRIED;
            $curried := self.IMPL-CURRIED;
            for $params {
                $curried.IMPL-ADD-PARAM($_.target.lexical-name);
            }
        }
        if nqp::bitand_i($CURRIES, 1) {
            for "left", "right" {
                my $operand := self."$_"();
                if nqp::istype($operand, RakuAST::Term::Whatever) {
                    my $curried := self.IMPL-CURRIED;
                    my $param_name := '$whatevercode_arg_' ~ ($curried ?? $curried.IMPL-NUM-PARAMS + 1 !! 1);
                    my $param;
                    if $curried {
                        $param := $curried.IMPL-ADD-PARAM($param_name);
                        $curried.IMPL-CHECK($resolver, $context, True);
                    }
                    else {
                        $param := self.IMPL-CURRY($resolver, $context, $param_name).IMPL-LAST-PARAM;
                    }
                    self."set-$_"($param.target.generate-lookup);
                }
            }
        }
        if nqp::bitand_i($CURRIES, 2) && ($curried := $right.IMPL-CURRIED) {
            my $params := $right.IMPL-UNCURRY;
            self.IMPL-CURRY($resolver, $context, '') unless self.IMPL-CURRIED;
            $curried := self.IMPL-CURRIED;
            my $param-num := $curried.IMPL-NUM-PARAMS;
            for $params {
                $param-num++;
                $_.target.set-name('$whatevercode_arg_' ~ $param-num);
                $curried.IMPL-ADD-PARAM($_.target.lexical-name);
            }
        }

        $infix.IMPL-THUNK-ARGUMENTS($resolver, $context, $left, $right);
    }

    method PERFORM-CHECK(
               RakuAST::Resolver $resolver,
      RakuAST::IMPL::QASTContext $context
    ) {
        my $infix := $!infix;
        my $left  := self.left;
        my $right := self.right;

        # handle op=
        if nqp::eqaddr($infix.WHAT,RakuAST::MetaInfix::Assign) {
            my str $operator := $infix.infix.operator;
            if $operator eq ',' || $operator eq 'xx' {
                my $sigil := (try $left.sigil) // '';
                if $sigil eq '$' || $sigil eq '@' {
                    $resolver.add-worry:
                      $resolver.build-exception: 'X::AdHoc',
                        payload => "Using $operator on a "
                          ~ ($sigil eq '$' ?? 'scalar' !! 'array')
                          ~ " is probably NOT what you want, as it will create\n"
                          ~ "a self-referential structure with little meaning";
                }
            }
        }

        # a "normal" infix op
        elsif nqp::istype($infix,RakuAST::Infix) {
            if $infix.operator eq ':=' && !$left.can-be-bound-to {
                $resolver.add-sorry:
                  $resolver.build-exception: 'X::Bind';
            }
        }
        True
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        $!infix.IMPL-INFIX-COMPILE($context, self.left, self.right)
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
        $visitor($!args)
    }

    method IMPL-CAN-INTERPRET() {
        $!infix.IMPL-CAN-INTERPRET && $!args.IMPL-CAN-INTERPRET
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        $!infix.IMPL-INTERPRET($ctx, self.IMPL-UNWRAP-LIST($!args.args) );
    }
}

# Application of an list-precedence infix operator.
class RakuAST::ApplyListInfix
  is RakuAST::Expression
  is RakuAST::BeginTime
{
    has RakuAST::Infixish $.infix;
    has List $!operands;

    method new(RakuAST::Infixish :$infix!, List :$operands!) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::ApplyListInfix, '$!infix', $infix);
        nqp::bindattr($obj, RakuAST::ApplyListInfix, '$!operands', my $list := []);
        for self.IMPL-UNWRAP-LIST($operands) {
            if nqp::istype($_, RakuAST::ColonPairs) {
                for $_.colonpairs {
                    nqp::push($list, $_);
                }
            }
            else {
                nqp::push($list, $_);
            }
        }
        $obj
    }

    method operands() {
        self.IMPL-WRAP-LIST($!operands)
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        my @operands;
        for $!operands {
            @operands.push($_.IMPL-TO-QAST($context));
        }
        $!infix.IMPL-LIST-INFIX-QAST: $context, @operands;
    }

    method visit-children(Code $visitor) {
        $visitor($!infix);
        for $!operands {
            $visitor($_);
        }
    }

    method PERFORM-BEGIN(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        $!infix.IMPL-THUNK-ARGUMENTS($resolver, $context, |self.IMPL-UNWRAP-LIST($!operands));
    }

    method IMPL-CAN-INTERPRET() {
        if $!infix.IMPL-CAN-INTERPRET {
            for self.IMPL-UNWRAP-LIST($!operands) {
                return False unless $_.IMPL-CAN-INTERPRET;
            }
            True
        }
        else {
            False
        }
    }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        $!infix.IMPL-INTERPRET($ctx, $!operands)
    }
}

#-------------------------------------------------------------------------------
# Dotty stuff

# The base of all dotty infixes (`$foo .bar` or `$foo .= bar()`).
class RakuAST::DottyInfixish
  is RakuAST::Node
  is RakuAST::OperatorProperties
{
    method new() { nqp::create(self) }
}

# The `.` dotty infix.
class RakuAST::DottyInfix::Call
  is RakuAST::DottyInfixish
{

    method IMPL-DOTTY-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $lhs-qast,
            RakuAST::Postfixish $rhs-ast) {
        $rhs-ast.IMPL-POSTFIX-QAST($context, $lhs-qast)
    }

    method default-operator-properties() {
        OperatorProperties.infix('.')
    }
}

# The `.=` dotty infix.
class RakuAST::DottyInfix::CallAssign
  is RakuAST::DottyInfixish
{

    method default-operator-properties() {
        OperatorProperties.infix('.=')
    }

    method IMPL-DOTTY-INFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $lhs-qast,
            RakuAST::Postfixish $rhs-ast) {
        # Store the target in a temporary, so we only evaluate it once.
        my $temp := QAST::Node.unique('meta_assign');
        my $bind-lhs := QAST::Op.new(
            :op('bind'),
            QAST::Var.new( :decl('var'), :scope('local'), :name($temp) ),
            $lhs-qast
        );

        # Emit the assignment.
        # TODO case analyze these
        QAST::Stmt.new(
            $bind-lhs,
            QAST::Op.new(
                :op('assign'),
                QAST::Var.new( :scope('local'), :name($temp) ),
                $rhs-ast.IMPL-POSTFIX-QAST(
                    $context,
                    QAST::Var.new( :scope('local'), :name($temp) ),
                )
            )
        )
    }
}

# Application of an dotty infix operator. These are infixes that actually
# parse a postfix operation on their right hand side, and thus won't fit in
# the standard infix model.
class RakuAST::ApplyDottyInfix
  is RakuAST::Expression
{
    has RakuAST::DottyInfixish $.infix;
    has RakuAST::Expression $.left;
    has RakuAST::Postfixish $.right;

    method new(RakuAST::DottyInfixish :$infix!, RakuAST::Expression :$left!,
            RakuAST::Postfixish :$right!) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::ApplyDottyInfix, '$!infix', $infix);
        nqp::bindattr($obj, RakuAST::ApplyDottyInfix, '$!left', $left);
        nqp::bindattr($obj, RakuAST::ApplyDottyInfix, '$!right', $right);
        $obj
    }

    method properties() { $!infix.properties }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        $!infix.IMPL-DOTTY-INFIX-QAST: $context,
            $!left.IMPL-TO-QAST($context),
            $!right
    }

    method visit-children(Code $visitor) {
        $visitor($!left);
        $visitor($!infix);
        $visitor($!right);
    }
}

#-------------------------------------------------------------------------------
# Prefixes

# Marker for all kinds of prefixish operators.
class RakuAST::Prefixish
  is RakuAST::Node
{
    has List $.colonpairs;

    method add-colonpair(RakuAST::ColonPair $pair) {
        $!colonpairs.push: $pair;
    }

    method visit-colonpairs(Code $visitor) {
        for $!colonpairs {
            $visitor($_);
        }
    }

    method IMPL-ADD-COLONPAIRS-TO-OP(RakuAST::IMPL::QASTContext $context, Mu $op) {
        for $!colonpairs {
            my $val-ast := $_.named-arg-value.IMPL-TO-QAST($context);
            $val-ast.named($_.named-arg-name);
            $op.push($val-ast);
        }
    }

    method IMPL-CURRIES() { 3 }
}

# A lookup of a simple (non-meta) prefix operator.
class RakuAST::Prefix
  is RakuAST::Prefixish
  is RakuAST::OperatorProperties
  is RakuAST::Lookup
{
    has str $.operator;

    method new(str $operator) {
        my $obj := nqp::create(self);
        nqp::bindattr_s($obj, RakuAST::Prefix, '$!operator', $operator);
        nqp::bindattr($obj, RakuAST::Prefixish, '$!colonpairs', []);
        $obj
    }

    method default-operator-properties() {
        OperatorProperties.prefix($!operator)
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-prefix($!operator);
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method IMPL-PREFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand-qast );
        self.IMPL-ADD-COLONPAIRS-TO-OP($context, $op);
        $op
    }

    method IMPL-HOP-PREFIX-QAST(RakuAST::IMPL::QASTContext $context) {
        my $name := self.resolution.lexical-name;
        QAST::Var.new( :scope('lexical'), :$name )
    }
}

# The prefix hyper meta-operator.
class RakuAST::MetaPrefix::Hyper
  is RakuAST::Prefixish
{
    has RakuAST::Prefix $.prefix;

    method new(RakuAST::Prefix $prefix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaPrefix::Hyper, '$!prefix', $prefix);
        nqp::bindattr($obj, RakuAST::Prefixish, '$!colonpairs', []);
        $obj
    }

    method IMPL-PREFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $op := QAST::Op.new:
            :op('call'),
            QAST::Op.new(
                :op('callstatic'), :name('&METAOP_HYPER_PREFIX'),
                $!prefix.IMPL-HOP-PREFIX-QAST($context)
            ),
            $operand-qast;
        self.IMPL-ADD-COLONPAIRS-TO-OP($context, $op);
        $op
    }

    method visit-children(Code $visitor) {
        $visitor($!prefix);
    }

    method properties() { $!prefix.properties }
}

#-------------------------------------------------------------------------------
# Everything that is termish (a term with prefixes or postfixes applied).

class RakuAST::Termish
  is RakuAST::Expression
  is RakuAST::CaptureSource { }

# Everything that is a kind of term does RakuAST::Term.
class RakuAST::Term
  is RakuAST::Termish { }

# Application of a prefix operator.
class RakuAST::ApplyPrefix
  is RakuAST::Termish
  is RakuAST::BeginTime
{
    has RakuAST::Prefixish $.prefix;
    has RakuAST::Expression $.operand;

    method new(:$prefix!, :$operand!) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::ApplyPrefix, '$!prefix', $prefix);
        nqp::bindattr($obj, RakuAST::ApplyPrefix, '$!operand', $operand);
        $obj
    }

    method add-colonpair(RakuAST::ColonPair $pair) {
        $!prefix.add-colonpair($pair);
    }

    method PERFORM-BEGIN(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        if nqp::bitand_i($!prefix.IMPL-CURRIES, 1) {
            if nqp::istype($!operand, RakuAST::Term::Whatever) {
                nqp::bindattr(self, RakuAST::ApplyPrefix, '$!operand', RakuAST::Var::Lexical.new('$_'));
                self.IMPL-CURRY($resolver, $context, '$_');
                $!operand.resolve-with($resolver);
            }
        }
        if nqp::bitand_i($!prefix.IMPL-CURRIES, 2) {
            if $!operand.IMPL-CURRIED {
                $!operand.IMPL-UNCURRY;
                self.IMPL-CURRY($resolver, $context, '$_');
            }
        }
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        $!prefix.IMPL-PREFIX-QAST($context, $!operand.IMPL-TO-QAST($context))
    }

    method visit-children(Code $visitor) {
        $visitor($!prefix);
        $visitor($!operand);
    }
}

#-------------------------------------------------------------------------------
# Postfixes

# Marker for all kinds of postfixish operators.
class RakuAST::Postfixish
  is RakuAST::Node
  is RakuAST::OperatorProperties
{
    has List $.colonpairs;

    method add-colonpair(RakuAST::ColonPair $pair) {
        $!colonpairs.push: $pair;
    }

    method visit-colonpairs(Code $visitor) {
        for $!colonpairs {
            $visitor($_);
        }
    }

    method IMPL-ADD-COLONPAIRS-TO-OP(RakuAST::IMPL::QASTContext $context, Mu $op) {
        for $!colonpairs {
            my $val-ast := $_.named-arg-value.IMPL-TO-QAST($context);
            $val-ast.named($_.named-arg-name);
            $op.push($val-ast);
        }
    }

    # %curried == 0 means do not curry
    # %curried == 1 means curry Whatever only
    # %curried == 2 means curry WhateverCode only
    # %curried == 3 means curry both Whatever and WhateverCode (default)
    method IMPL-CURRIES() { 0 }

    method can-be-used-with-hyper() { False }
}

# A lookup of a simple (non-meta) postfix operator.
class RakuAST::Postfix
  is RakuAST::Postfixish
  is RakuAST::Lookup
{
    has str $.operator;

    method new(str $operator) {
        my $obj := nqp::create(self);
        nqp::bindattr_s($obj, RakuAST::Postfix, '$!operator', $operator);
        nqp::bindattr($obj, RakuAST::Postfixish, '$!colonpairs', []);
        $obj
    }

    method default-operator-properties() {
        OperatorProperties.postfix($!operator)
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-postfix($!operator);
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method IMPL-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $name := self.resolution.lexical-name;
        QAST::Op.new( :op('call'), :$name, $operand-qast )
    }

    method can-be-used-with-hyper() { True }

    method IMPL-POSTFIX-HYPER-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        QAST::Op.new:
            :op('callstatic'), :name('&METAOP_HYPER_POSTFIX_ARGS'),
            $operand-qast,
            self.resolution.IMPL-LOOKUP-QAST($context)
    }

    method IMPL-CURRIES() { 3 }
}

# Base class for literal postfixes
class RakuAST::Postfix::Literal
  is RakuAST::Postfixish
  is RakuAST::Lookup
{
    has Mu $!value;

    method new(Mu $value) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Postfix::Literal, '$!value', $value);
        nqp::bindattr($obj, RakuAST::Postfixish, '$!colonpairs', []);
        $obj
    }

    method IMPL-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $name := self.resolution.lexical-name;
        $context.ensure-sc($!value);
        QAST::Op.new:
            :op('call'), :$name,
            $operand-qast,
            QAST::WVal.new( :value($!value) )
    }

    method can-be-used-with-hyper() { False }

    method IMPL-CURRIES() { 3 }
}

# The postfix exponentiation operator (2⁴⁵).
class RakuAST::Postfix::Power
  is RakuAST::Postfix::Literal
{

    method default-operator-properties() {
        OperatorProperties.postfix('ⁿ')
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-postfix('ⁿ');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method power() { nqp::getattr(self,RakuAST::Postfix::Literal,'$!value') }
}

# The postfix vulgar operator (4⅔ or 4²/₃).
class RakuAST::Postfix::Vulgar
  is RakuAST::Postfix::Literal
{

    method default-operator-properties() {
        OperatorProperties.postfix('+')
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-infix('+');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method vulgar() { nqp::getattr(self,RakuAST::Postfix::Literal,'$!value') }
}

#-------------------------------------------------------------------------------
# Postcircumfixes

# A marker for all postcircumfixes. These each have relatively special
# compilation, so they get distinct nodes.
class RakuAST::Postcircumfix
  is RakuAST::Postfixish { }

# A postcircumfix array index operator, possibly multi-dimensional.
class RakuAST::Postcircumfix::ArrayIndex
  is RakuAST::Postcircumfix
  is RakuAST::Lookup
{
    has RakuAST::SemiList $.index;
    has RakuAST::Expression $.assignee;

    method new(RakuAST::SemiList :$index!, RakuAST::Expression :$assignee) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Postcircumfix::ArrayIndex, '$!index', $index);
        nqp::bindattr($obj, RakuAST::Postcircumfix::ArrayIndex, '$!assignee', $assignee // RakuAST::Expression);
        nqp::bindattr($obj, RakuAST::Postfixish, '$!colonpairs', []);
        $obj
    }

    method set-assignee(RakuAST::Expression $assignee) {
        nqp::bindattr(self, RakuAST::Postcircumfix::ArrayIndex, '$!assignee', $assignee);
    }

    method can-be-bound-to() {
        True
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-lexical(
            nqp::elems($!index.code-statements) > 1
                ?? '&postcircumfix:<[; ]>'
                !! '&postcircumfix:<[ ]>');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method default-operator-properties() {
        OperatorProperties.postcircumfix('[ ]')
    }

    method visit-children(Code $visitor) {
        $visitor($!index);
        $visitor($!assignee) if $!assignee;
        self.visit-colonpairs($visitor);
    }

    method IMPL-CURRIES() { 3 }

    method IMPL-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand-qast );
        $op.push($!index.IMPL-TO-QAST($context)) unless $!index.is-empty;
        $op.push($!assignee.IMPL-TO-QAST($context)) if $!assignee;
        $op
    }

    method IMPL-BIND-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context,
            RakuAST::Expression $operand, QAST::Node $source-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand.IMPL-TO-QAST($context) );
        $op.push($!index.IMPL-TO-QAST($context)) unless $!index.is-empty;
        my $bind := $source-qast;
        $bind.named('BIND');
        $op.push($bind);
        $op
    }

    method can-be-used-with-hyper() { True }

    method IMPL-POSTFIX-HYPER-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        QAST::Op.new:
            :op('callstatic'), :name('&METAOP_HYPER_POSTFIX_ARGS'),
            $operand-qast,
            $!index.IMPL-TO-QAST($context),
            self.resolution.IMPL-LOOKUP-QAST($context)
    }
}

# A postcircumfix hash index operator, possibly multi-dimensional.
class RakuAST::Postcircumfix::HashIndex
  is RakuAST::Postcircumfix
  is RakuAST::Lookup
{
    has RakuAST::SemiList $.index;

    method new(RakuAST::SemiList $index) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Postcircumfix::HashIndex, '$!index', $index);
        nqp::bindattr($obj, RakuAST::Postfixish, '$!colonpairs', []);
        $obj
    }

    method can-be-bound-to() {
        True
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-lexical(
            nqp::elems($!index.code-statements) > 1
                ?? '&postcircumfix:<{; }>'
                !! '&postcircumfix:<{ }>');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method visit-children(Code $visitor) {
        $visitor($!index);
        self.visit-colonpairs($visitor);
    }

    method default-operator-properties() {
        OperatorProperties.postcircumfix('{ }')
    }

    method IMPL-CURRIES() { 3 }

    method IMPL-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand-qast );
        $op.push($!index.IMPL-TO-QAST($context)) unless $!index.is-empty;
        self.IMPL-ADD-COLONPAIRS-TO-OP($context, $op);
        $op
    }

    method IMPL-BIND-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context,
            RakuAST::Expression $operand, QAST::Node $source-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand.IMPL-TO-QAST($context) );
        $op.push($!index.IMPL-TO-QAST($context)) unless $!index.is-empty;
        self.IMPL-ADD-COLONPAIRS-TO-OP($context, $op);
        my $bind := $source-qast;
        $bind.named('BIND');
        $op.push($bind);
        $op
    }
}

# A postcircumfix literal hash index operator.
class RakuAST::Postcircumfix::LiteralHashIndex
  is RakuAST::Postcircumfix
  is RakuAST::Lookup
{
    has RakuAST::QuotedString $.index;
    has RakuAST::Expression $.assignee;

    method new(RakuAST::QuotedString :$index!, RakuAST::Expression :$assignee) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Postcircumfix::LiteralHashIndex, '$!index', $index);
        nqp::bindattr($obj, RakuAST::Postcircumfix::LiteralHashIndex, '$!assignee', $assignee // RakuAST::Expression);
        nqp::bindattr($obj, RakuAST::Postfixish, '$!colonpairs', []);
        $obj
    }

    method set-assignee(RakuAST::Expression $assignee) {
        nqp::bindattr(self, RakuAST::Postcircumfix::LiteralHashIndex, '$!assignee', $assignee);
    }

    method can-be-bound-to() {
        True
    }

    method resolve-with(RakuAST::Resolver $resolver) {
        my $resolved := $resolver.resolve-lexical('&postcircumfix:<{ }>');
        if $resolved {
            self.set-resolution($resolved);
        }
        Nil
    }

    method visit-children(Code $visitor) {
        $visitor($!index);
        $visitor($!assignee) if $!assignee;
        self.visit-colonpairs($visitor);
    }

    method default-operator-properties() {
        OperatorProperties.postcircumfix('< >')
    }

    method IMPL-CURRIES() { 3 }

    method IMPL-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand-qast );
        $op.push($!index.IMPL-TO-QAST($context)) unless $!index.is-empty-words;
        $op.push($!assignee.IMPL-TO-QAST($context)) if $!assignee;
        self.IMPL-ADD-COLONPAIRS-TO-OP($context, $op);
        $op
    }

    method IMPL-BIND-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context,
            RakuAST::Expression $operand, QAST::Node $source-qast) {
        my $name := self.resolution.lexical-name;
        my $op := QAST::Op.new( :op('call'), :$name, $operand.IMPL-TO-QAST($context) );
        $op.push($!index.IMPL-TO-QAST($context)) unless $!index.is-empty-words;
        self.IMPL-ADD-COLONPAIRS-TO-OP($context, $op);
        my $bind := $source-qast;
        $bind.named('BIND');
        $op.push($bind);
        $op
    }
}

# An hyper operator on a postfix operator.
class RakuAST::MetaPostfix::Hyper
  is RakuAST::Postfixish
  is RakuAST::CheckTime
{
    has RakuAST::Postfixish $.postfix;

    method new(RakuAST::Postfixish $postfix) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::MetaPostfix::Hyper, '$!postfix', $postfix);
        nqp::bindattr($obj, RakuAST::Postfixish, '$!colonpairs', []);
        $obj
    }

    method PERFORM-CHECK(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        unless $!postfix.can-be-used-with-hyper {
            self.add-sorry: $resolver.build-exception: 'X::AdHoc',
                payload => 'Cannot hyper this postfix'
        }
    }

    method IMPL-POSTFIX-QAST(RakuAST::IMPL::QASTContext $context, Mu $operand-qast) {
        $!postfix.IMPL-POSTFIX-HYPER-QAST($context, $operand-qast)
    }

    method visit-children(Code $visitor) {
        $visitor($!postfix);
        self.visit-colonpairs($visitor);
    }

    method default-operator-properties() {
        $!postfix.properties
    }
}

# Application of a postfix operator.
class RakuAST::ApplyPostfix
  is RakuAST::Termish
  is RakuAST::BeginTime
{
    has RakuAST::Postfixish $.postfix;
    has RakuAST::Expression $.operand;

    method new(:$postfix!, :$operand!) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::ApplyPostfix, '$!postfix', $postfix);
        if nqp::istype($operand, RakuAST::Circumfix::Parentheses)
            && $operand.semilist.IMPL-IS-SINGLE-EXPRESSION
        {
            my $statement :=
              self.IMPL-UNWRAP-LIST($operand.semilist.code-statements)[0];
            $operand := $statement.expression
                unless $statement.condition-modifier || $statement.loop-modifier;
        }
        nqp::bindattr($obj, RakuAST::ApplyPostfix, '$!operand', $operand);
        $obj
    }

    method add-colonpair(RakuAST::ColonPair $pair) {
        $!postfix.add-colonpair($pair);
    }

    method can-be-bound-to() {
        $!postfix.can-be-bound-to
    }

    method on-topic() {
        nqp::istype($!operand,RakuAST::Var::Lexical) && $!operand.name eq '$_'
    }

    method PERFORM-BEGIN(RakuAST::Resolver $resolver, RakuAST::IMPL::QASTContext $context) {
        if nqp::bitand_i($!postfix.IMPL-CURRIES, 1) {
            if nqp::istype($!operand, RakuAST::Term::Whatever) {
                nqp::bindattr(self, RakuAST::ApplyPostfix, '$!operand', RakuAST::Var::Lexical.new('$_'));
                self.IMPL-CURRY($resolver, $context, '$_');
                $!operand.resolve-with($resolver);
            }
        }
        if nqp::bitand_i($!postfix.IMPL-CURRIES, 2) {
            if $!operand.IMPL-CURRIED {
                $!operand.IMPL-UNCURRY;
                self.IMPL-CURRY($resolver, $context, '$_');
            }
        }
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        my $postfix-ast := $!postfix.IMPL-POSTFIX-QAST($context, $!operand.IMPL-TO-QAST($context));
        # Method calls may be to a foreign language, and thus return
        # values may need type mapping into Raku land.
        nqp::istype($!postfix, RakuAST::Call::Methodish)
            ?? QAST::Op.new(:op<hllize>, $postfix-ast)
            !! $postfix-ast
    }

    method IMPL-BIND-QAST(RakuAST::IMPL::QASTContext $context, QAST::Node $source-qast) {
        $!postfix.IMPL-BIND-POSTFIX-QAST($context, $!operand, $source-qast)
    }

    method visit-children(Code $visitor) {
        $visitor($!operand);
        $visitor($!postfix);
    }

    method IMPL-CAN-INTERPRET() { $!operand.IMPL-CAN-INTERPRET && $!postfix.IMPL-CAN-INTERPRET }

    method IMPL-INTERPRET(RakuAST::IMPL::InterpContext $ctx) {
        $!postfix.IMPL-INTERPRET($ctx, -> { $!operand.IMPL-INTERPRET($ctx) })
    }
}

#-------------------------------------------------------------------------------
# Ternaries

# The ternary conditional operator (?? !!).
class RakuAST::Ternary
  is RakuAST::Expression
{
    has RakuAST::Expression $.condition;
    has RakuAST::Expression $.then;
    has RakuAST::Expression $.else;

    method new(RakuAST::Expression :$condition!, RakuAST::Expression :$then!,
            RakuAST::Expression :$else!) {
        my $obj := nqp::create(self);
        nqp::bindattr($obj, RakuAST::Ternary, '$!condition', $condition);
        nqp::bindattr($obj, RakuAST::Ternary, '$!then', $then);
        nqp::bindattr($obj, RakuAST::Ternary, '$!else', $else);
        $obj
    }

    method IMPL-EXPR-QAST(RakuAST::IMPL::QASTContext $context) {
        QAST::Op.new(
            :op('if'),
            $!condition.IMPL-TO-QAST($context),
            $!then.IMPL-TO-QAST($context),
            $!else.IMPL-TO-QAST($context),
        )
    }

    method visit-children(Code $visitor) {
        $visitor($!condition);
        $visitor($!then);
        $visitor($!else);
    }

    method properties() { OperatorProperties.infix('?? !!') }
}
