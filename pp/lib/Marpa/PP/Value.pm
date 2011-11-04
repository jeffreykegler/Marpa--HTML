# Copyright 2011 Jeffrey Kegler
# This file is part of Marpa::PP.  Marpa::PP is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::PP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::PP.  If not, see
# http://www.gnu.org/licenses/.

package Marpa::PP::Value;

use 5.010;
use warnings;
use strict;
use integer;

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '0.011_001';
$STRING_VERSION = $VERSION;
## no critic (BuiltinFunctions::ProhibitStringyEval)
$VERSION = eval $VERSION;
## use critic

package Marpa::PP::Internal::Value;

use English qw( -no_match_vars );

# This perlcritic check is broken as of 9 Aug 2010
## no critic (TestingAndDebugging::ProhibitNoWarnings)
no warnings qw(qw);
## use critic

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '0.011_000';
$STRING_VERSION = $VERSION;
## no critic (BuiltinFunctions::ProhibitStringyEval)
$VERSION = eval $VERSION;
## use critic

BEGIN {
my $structure = <<'END_OF_STRUCTURE';

    :package=Marpa::PP::Internal::Or_Node

    ID
    TAG
    ITEM
    RULE_ID
    POSITION
    AND_NODE_IDS

    CYCLE { Can this Or node be part of a cycle? }

    INITIAL_RANK_REF

    =LAST_FIELD
END_OF_STRUCTURE
    Marpa::PP::offset($structure);
} ## end BEGIN

BEGIN {
my $structure = <<'END_OF_STRUCTURE';

    :package=Marpa::PP::Internal::And_Node

    ID
    TAG
    RULE_ID
    TOKEN_NAME
    VALUE_REF
    VALUE_OPS

    { Fields before this (except ID)
    are used in evaluate() }

    PREDECESSOR_ID
    CAUSE_ID

    CAUSE_EARLEME

    INITIAL_RANK_REF
    CONSTANT_RANK_REF
    TOKEN_RANK_REF

    { These earleme positions will be needed for the callbacks: }

    START_EARLEME
    END_EARLEME

    POSITION { This is only used for diagnostics, but
    diagnostics are important. }

    =LAST_FIELD

END_OF_STRUCTURE
    Marpa::PP::offset($structure);
} ## end BEGIN

BEGIN {
my $structure = <<'END_OF_STRUCTURE';

    :package=Marpa::PP::Internal::Iteration_Node

    OR_NODE { The or-node }

    CHOICES {
    A list of remaining choices of and-node.
    The current choice is first in the list.
    }

    PARENT { Offset of the parent in the iterations stack }

    CAUSE_IX { Offset of the cause child, if any }
    PREDECESSOR_IX { Offset of the predecessor child, if any }
    { IX value is -1 if IX needs to be recalculated }

    CHILD_TYPE { Cause or Predecessor }

    RANK { Current rank }
    CLEAN { Boolean -- true if rank does not need to
    be recalculated }

END_OF_STRUCTURE
    Marpa::PP::offset($structure);
} ## end BEGIN

BEGIN {
my $structure = <<'END_OF_STRUCTURE';

    :package=Marpa::PP::Internal::Task

    INITIALIZE
    POPULATE_OR_NODE
    POPULATE_DEPTH

    RANK_ALL

    ITERATE
    FIX_TREE
    STACK_INODE

END_OF_STRUCTURE
    Marpa::PP::offset($structure);
} ## end BEGIN

BEGIN {
my $structure = <<'END_OF_STRUCTURE';

    :package=Marpa::PP::Internal::Op

    :{ These are the valuation-time ops }
    ARGC
    CALL
    CONSTANT_RESULT
    VIRTUAL_HEAD
    VIRTUAL_KERNEL
    VIRTUAL_TAIL

END_OF_STRUCTURE
    Marpa::PP::offset($structure);
} ## end BEGIN

BEGIN {
my $structure = <<'END_OF_STRUCTURE';

    :package=Marpa::PP::Internal::Choice

    { These are the valuation-time ops }

    AND_NODE
    RANK { *NOT* a rank ref }

END_OF_STRUCTURE
    Marpa::PP::offset($structure);
} ## end BEGIN

use constant SKIP => -1;

use warnings;

# The internal parameter is slightly misnamed -- between
# calls it is the count of the *next* parse
sub Marpa::PP::Recognizer::parse_count {
    my ($recce) = @_;
    return $recce->[Marpa::PP::Internal::Recognizer::PARSE_COUNT] - 1;
}

sub Marpa::PP::Recognizer::and_node_tag {
    my ($recce, $and_node) = @_;
    my $or_nodes = $recce->[Marpa::PP::Internal::Recognizer::OR_NODES];
    my $grammar = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];
    my $symbol_hash = $grammar->[Marpa::PP::Internal::Grammar::SYMBOL_HASH];
    my $recce_c     = $recce->[Marpa::PP::Internal::Recognizer::C];
    my $origin_earleme = $and_node->[Marpa::PP::Internal::And_Node::START_EARLEME];
    my $current_earleme = $and_node->[Marpa::PP::Internal::And_Node::END_EARLEME];
    my $middle_earleme = $and_node->[Marpa::PP::Internal::And_Node::CAUSE_EARLEME];
    my $position = $and_node->[Marpa::PP::Internal::And_Node::POSITION] + 1;
    my $rule = $and_node->[Marpa::PP::Internal::And_Node::RULE_ID];
    my $tag =
	  'R' 
	. $rule . q{:}
	. $position . q{@}
	. $origin_earleme . q{-}
	. $current_earleme;
    my $cause_id  = $and_node->[Marpa::PP::Internal::And_Node::CAUSE_ID];
    if (defined $cause_id) {
	my $cause = $or_nodes->[$cause_id];
	my $cause_rule = $cause->[Marpa::PP::Internal::Or_Node::RULE_ID];
	$tag .= 'C' . $cause_rule;
    } else {
	my $token_name =
	    $and_node->[Marpa::PP::Internal::And_Node::TOKEN_NAME];
	my $symbol = $symbol_hash->{$token_name};
	$tag .= 'S' . $symbol;
    }
    $tag .= q{@} . $middle_earleme;
    return $tag;
}

sub Marpa::PP::Recognizer::or_node_tag {
    my ( $recce, $or_node ) = @_;
    die unless defined $or_node;
    my $item = $or_node->[Marpa::PP::Internal::Or_Node::ITEM];
    my $set = $item->[Marpa::PP::Internal::Earley_Item::SET];
    my $origin   = $item->[Marpa::PP::Internal::Earley_Item::ORIGIN];
    my $rule     = $or_node->[Marpa::PP::Internal::Or_Node::RULE_ID];
    my $position = $or_node->[Marpa::PP::Internal::Or_Node::POSITION];
    return 'R' . $rule . q{:} . $position . q{@} . $origin . q{-} . $set;
} ## end sub Marpa::PP::Recognizer::or_node_tag

sub Marpa::PP::Recognizer::show_and_nodes {
    my ($recce) = @_;
    my $and_nodes  = $recce->[Marpa::PP::Internal::Recognizer::AND_NODES];
    my @data = ();
    for my $and_node (@{$and_nodes}) {
         my $desc = $recce->and_node_tag($and_node);
	 my ($rule, $position, $origin, $dot, $cause_type, $cause, $middle) = (
	     $desc =~ /\A R (\d+) [:] (\d+)
	     [@] (\d+) [-] (\d+) ([SC]) (\d+)
	     [@] (\d+) \z/msx
	 );
        push @data,
            [ $origin, $dot, $rule, $position,
		$middle,
		($cause_type eq "C" ? $cause : -1),
		($cause_type eq "S" ? $cause : -1),
		$desc ];
    }
    my @tags = map { $_->[-1] } sort {
       $a->[0] <=> $b->[0]
       or $a->[1] <=> $b->[1]
       or $a->[2] <=> $b->[2]
       or $a->[3] <=> $b->[3]
       or $a->[4] <=> $b->[4]
       or $a->[5] <=> $b->[5]
       or $a->[6] <=> $b->[6]
    } @data;
    my $result = (join "\n", @tags) . "\n";
    return $result;
}

sub Marpa::PP::Recognizer::show_or_nodes {
    my ($recce) = @_;
    my $or_nodes  = $recce->[Marpa::PP::Internal::Recognizer::OR_NODES];
    my @data = ();
    for my $or_node (@{$or_nodes}) {
         my $desc = $recce->or_node_tag($or_node);
	 my @elements = ($desc =~ /\A R (\d+) [:] (\d+) [@] (\d+) [-] (\d+) \z/msx);
	 push @data, [ @elements, $desc ];
    }
    my @tags = map { $_->[-1] } sort {
       $a->[2] <=> $b->[2]
       or $a->[3] <=> $b->[3]
       or $a->[0] <=> $b->[0]
       or $a->[1] <=> $b->[1]
    } @data;
    my $result = (join "\n", @tags) . "\n";
    return $result;
}

sub Marpa::PP::brief_iteration_node {
    my ($iteration_node) = @_;

    my $or_node =
        $iteration_node->[Marpa::PP::Internal::Iteration_Node::OR_NODE];
    my $or_node_id   = $or_node->[Marpa::PP::Internal::Or_Node::ID];
    my $and_node_ids = $or_node->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS];
    my $text         = "o$or_node_id";
    DESCRIBE_CHOICES: {
        if ( not defined $and_node_ids ) {
            $text .= ' UNPOPULATED';
            last DESCRIBE_CHOICES;
        }
        my $choices =
            $iteration_node->[Marpa::PP::Internal::Iteration_Node::CHOICES];
        if ( not defined $choices ) {
            $text .= ' Choices not initialized';
            last DESCRIBE_CHOICES;
        }
        my $choice = $choices->[0];
        if ( defined $choice ) {
            $text
                .= " [$choice] == a"
                . $choice->[Marpa::PP::Internal::Choice::AND_NODE]
                ->[Marpa::PP::Internal::And_Node::ID];
            last DESCRIBE_CHOICES;
        } ## end if ( defined $choice )
        $text .= "o$or_node_id has no choices left";
    } ## end DESCRIBE_CHOICES:
    my $parent_ix =
        $iteration_node->[Marpa::PP::Internal::Iteration_Node::PARENT]
        // q{-};
    return "$text; p=$parent_ix";
} ## end sub Marpa::PP::brief_iteration_node

sub Marpa::PP::show_rank_ref {
    my ($rank_ref) = @_;
    return 'undef' if not defined $rank_ref;
    return 'SKIP'  if $rank_ref == Marpa::PP::Internal::Value::SKIP;
    return ${$rank_ref};
} ## end sub Marpa::PP::show_rank_ref

sub Marpa::PP::Recognizer::show_iteration_node {
    my ( $recce, $iteration_node, $verbose ) = @_;

    my $or_node =
        $iteration_node->[Marpa::PP::Internal::Iteration_Node::OR_NODE];
    my $or_node_id  = $or_node->[Marpa::PP::Internal::Or_Node::ID];
    my $or_node_tag = $or_node->[Marpa::PP::Internal::Or_Node::TAG];
    my $text        = "o$or_node_id $or_node_tag; ";
    given (
        $iteration_node->[Marpa::PP::Internal::Iteration_Node::CHILD_TYPE] )
    {
        when (Marpa::PP::Internal::And_Node::CAUSE_ID) {
            $text .= 'cause '
        }
        when (Marpa::PP::Internal::And_Node::PREDECESSOR_ID) {
            $text .= 'predecessor '
        }
        default {
            $text .= '- '
        }
    } ## end given

    $text
        .= 'pr='
        . (
        $iteration_node->[Marpa::PP::Internal::Iteration_Node::PREDECESSOR_IX]
            // q{-} )
        . q{;c=}
        . ( $iteration_node->[Marpa::PP::Internal::Iteration_Node::CAUSE_IX]
            // q{-} )
        . q{;p=}
        . ( $iteration_node->[Marpa::PP::Internal::Iteration_Node::PARENT]
            // q{-} )
        . q{; rank=}
        . ( $iteration_node->[Marpa::PP::Internal::Iteration_Node::RANK]
            // 'undef' )
        . (
        $iteration_node->[Marpa::PP::Internal::Iteration_Node::CLEAN]
        ? q{}
        : ' (dirty)'
        ) . "\n";

    DESCRIBE_CHOICES: {
        my $and_node_ids =
            $or_node->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS];
        if ( not defined $and_node_ids ) {
            $text .= " UNPOPULATED\n";
            last DESCRIBE_CHOICES;
        }
        my $choices =
            $iteration_node->[Marpa::PP::Internal::Iteration_Node::CHOICES];
        if ( not defined $choices ) {
            $text .= " Choices not initialized\n";
            last DESCRIBE_CHOICES;
        }
        if ( not scalar @{$choices} ) {
            $text .= " has no choices left\n";
            last DESCRIBE_CHOICES;
        }
        for my $choice_ix ( 0 .. $#{$choices} ) {
            my $choice = $choices->[$choice_ix];
            $text .= " o$or_node_id" . '[' . $choice_ix . '] ';
            my $and_node = $choice->[Marpa::PP::Internal::Choice::AND_NODE];
            my $and_node_tag =
                $and_node->[Marpa::PP::Internal::And_Node::TAG];
            my $and_node_id = $and_node->[Marpa::PP::Internal::And_Node::ID];
            $text .= " ::= a$and_node_id $and_node_tag";
            no integer;
            if ($verbose) {
                $text .= q{; rank=}
                    . $choice->[Marpa::PP::Internal::Choice::RANK];
            } ## end if ($verbose)
            $text .= "\n";
            last CHOICE if not $verbose;
        } ## end for my $choice_ix ( 0 .. $#{$choices} )
    } ## end DESCRIBE_CHOICES:
    return $text;
} ## end sub Marpa::PP::Recognizer::show_iteration_node

sub Marpa::PP::Recognizer::show_iteration_stack {
    my ( $recce, $verbose ) = @_;
    my $iteration_stack =
        $recce->[Marpa::PP::Internal::Recognizer::ITERATION_STACK];
    my $text = q{};
    for my $ix ( 0 .. $#{$iteration_stack} ) {
        my $iteration_node = $iteration_stack->[$ix];
        $text .= "$ix: "
            . $recce->show_iteration_node( $iteration_node, $verbose );
    }
    return $text;
} ## end sub Marpa::PP::Recognizer::show_iteration_stack

package Marpa::PP::Internal::Recognizer;
our $DEFAULT_ACTION_VALUE = \undef;

package Marpa::PP::Internal::Value;

sub Marpa::PP::Internal::Recognizer::set_null_values {
    my ($recce) = @_;
    my $grammar = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];
    my $trace_values =
        $recce->[Marpa::PP::Internal::Recognizer::TRACE_VALUES];

    my $rules   = $grammar->[Marpa::PP::Internal::Grammar::RULES];
    my $symbols = $grammar->[Marpa::PP::Internal::Grammar::SYMBOLS];
    my $default_null_value =
        $grammar->[Marpa::PP::Internal::Grammar::DEFAULT_NULL_VALUE];

    my $null_values;
    $#{$null_values} = $#{$symbols};

    SYMBOL: for my $symbol ( @{$symbols} ) {
        next SYMBOL if not $symbol->[Marpa::PP::Internal::Symbol::NULLING];

        my $null_value = undef;
        if ( $symbol->[Marpa::PP::Internal::Symbol::NULL_VALUE] ) {
            $null_value =
                ${ $symbol->[Marpa::PP::Internal::Symbol::NULL_VALUE] };
        }
        else {
            $null_value = $default_null_value;
        }
        next SYMBOL if not defined $null_value;

        my $symbol_id = $symbol->[Marpa::PP::Internal::Symbol::ID];
        $null_values->[$symbol_id] = $null_value;

        if ($trace_values) {
            print {$Marpa::PP::Internal::TRACE_FH}
                'Setting null value for symbol ',
                $symbol->[Marpa::PP::Internal::Symbol::NAME],
                ' to ', Data::Dumper->new( [ \$null_value ] )->Terse(1)->Dump
                or Marpa::PP::exception('Could not print to trace file');
        } ## end if ($trace_values)

    } ## end for my $symbol ( @{$symbols} )

    return $null_values;

}    # set_null_values

# Given the grammar and an action name, resolve it to a closure,
# or return undef
sub Marpa::PP::Internal::Recognizer::resolve_semantics {
    my ( $recce, $closure_name ) = @_;
    my $grammar  = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];
    my $closures = $recce->[Marpa::PP::Internal::Recognizer::CLOSURES];
    my $trace_actions =
        $recce->[Marpa::PP::Internal::Recognizer::TRACE_ACTIONS];

    Marpa::PP::exception(q{Trying to resolve 'undef' as closure name})
        if not defined $closure_name;

    if ( my $closure = $closures->{$closure_name} ) {
        if ($trace_actions) {
            print {$Marpa::PP::Internal::TRACE_FH}
                qq{Resolved "$closure_name" to explicit closure\n}
                or Marpa::PP::exception('Could not print to trace file');
        }

        return $closure;
    } ## end if ( my $closure = $closures->{$closure_name} )

    my $fully_qualified_name;
    DETERMINE_FULLY_QUALIFIED_NAME: {
        if ( $closure_name =~ /([:][:])|[']/xms ) {
            $fully_qualified_name = $closure_name;
            last DETERMINE_FULLY_QUALIFIED_NAME;
        }
        if (defined(
                my $actions_package =
                    $grammar->[Marpa::PP::Internal::Grammar::ACTIONS]
            )
            )
        {
            $fully_qualified_name = $actions_package . q{::} . $closure_name;
            last DETERMINE_FULLY_QUALIFIED_NAME;
        } ## end if ( defined( my $actions_package = $grammar->[...]))

        if (defined(
                my $action_object_class =
                    $grammar->[Marpa::PP::Internal::Grammar::ACTION_OBJECT]
            )
            )
        {
            $fully_qualified_name =
                $action_object_class . q{::} . $closure_name;
        } ## end if ( defined( my $action_object_class = $grammar->[...]))
    } ## end DETERMINE_FULLY_QUALIFIED_NAME:

    return if not defined $fully_qualified_name;

    no strict 'refs';
    my $closure = *{$fully_qualified_name}{'CODE'};
    use strict 'refs';

    if ($trace_actions) {
        print {$Marpa::PP::Internal::TRACE_FH}
            ( $closure ? 'Successful' : 'Failed' )
            . qq{ resolution of "$closure_name" },
            'to ', $fully_qualified_name, "\n"
            or Marpa::PP::exception('Could not print to trace file');
    } ## end if ($trace_actions)

    return $closure;

} ## end sub Marpa::PP::Internal::Recognizer::resolve_semantics

sub Marpa::PP::Internal::Recognizer::set_actions {
    my ($recce) = @_;
    my $grammar = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];

    my ( $rules, $default_action, ) = @{$grammar}[
        Marpa::PP::Internal::Grammar::RULES,
        Marpa::PP::Internal::Grammar::DEFAULT_ACTION,
    ];

    my $evaluator_rules = [];

    my $default_action_closure;
    if ( defined $default_action ) {
        $default_action_closure =
            Marpa::PP::Internal::Recognizer::resolve_semantics( $recce,
            $default_action );
        Marpa::PP::exception(
            "Could not resolve default action named '$default_action'")
            if not $default_action_closure;
    } ## end if ( defined $default_action )

    RULE: for my $rule ( @{$rules} ) {

        next RULE if not $rule->[Marpa::PP::Internal::Rule::USED];

        my $rule_id = $rule->[Marpa::PP::Internal::Rule::ID];
        my $ops = $evaluator_rules->[$rule_id] = [];

        my $virtual_rhs = $rule->[Marpa::PP::Internal::Rule::VIRTUAL_RHS];
        my $virtual_lhs = $rule->[Marpa::PP::Internal::Rule::VIRTUAL_LHS];

        if ($virtual_lhs) {
            push @{$ops},
                (
                $virtual_rhs
                ? Marpa::PP::Internal::Op::VIRTUAL_KERNEL
                : Marpa::PP::Internal::Op::VIRTUAL_TAIL
                ),
                $rule->[Marpa::PP::Internal::Rule::REAL_SYMBOL_COUNT];
            next RULE;
        } ## end if ($virtual_lhs)

        # If we are here the LHS is real, not virtual

        if ($virtual_rhs) {
            push @{$ops},
                Marpa::PP::Internal::Op::VIRTUAL_HEAD,
                $rule->[Marpa::PP::Internal::Rule::REAL_SYMBOL_COUNT];
        } ## end if ($virtual_rhs)
            # assignment instead of comparison is deliberate
        elsif ( my $argc =
            scalar @{ $rule->[Marpa::PP::Internal::Rule::RHS] } )
        {
            push @{$ops}, Marpa::PP::Internal::Op::ARGC, $argc;
        }

        if ( my $action = $rule->[Marpa::PP::Internal::Rule::ACTION] ) {
            my $closure =
                Marpa::PP::Internal::Recognizer::resolve_semantics( $recce,
                $action );

            Marpa::PP::exception(qq{Could not resolve action name: "$action"})
                if not defined $closure;
            push @{$ops}, Marpa::PP::Internal::Op::CALL, $closure;
            next RULE;
        } ## end if ( my $action = $rule->[Marpa::PP::Internal::Rule::ACTION...])

        # Try to resolve the LHS as a closure name,
        # if it is not internal.
        # If we can't resolve
        # the LHS as a closure name, it's not
        # a fatal error.
        if ( my $action =
            $rule->[Marpa::PP::Internal::Rule::LHS]
            ->[Marpa::PP::Internal::Symbol::NAME] )
        {
            if ($action !~ /[\]] \z/xms
                and defined(
                    my $closure =
                        Marpa::PP::Internal::Recognizer::resolve_semantics(
                        $recce, $action
                        )
                )
                )
            {
                push @{$ops}, Marpa::PP::Internal::Op::CALL, $closure;
                next RULE;
            } ## end if ( $action !~ /[\]] \z/xms and defined( my $closure...)[)
        } ## end if ( my $action = $rule->[Marpa::PP::Internal::Rule::LHS...])

        if ( defined $default_action_closure ) {
            push @{$ops}, Marpa::PP::Internal::Op::CALL,
                $default_action_closure;
            next RULE;
        }

        # If there is no default action specified, the fallback
        # is to return an undef
        push @{$ops}, Marpa::PP::Internal::Op::CONSTANT_RESULT,
            $Marpa::PP::Internal::Recognizer::DEFAULT_ACTION_VALUE;

    } ## end for my $rule ( @{$rules} )

    return $evaluator_rules;

}    # set_actions

# Returns false if no parse
sub do_rank_all {
    my ( $recce, $depth_by_id ) = @_;
    my $grammar = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];
    my $symbols = $grammar->[Marpa::PP::Internal::Grammar::SYMBOLS];
    my $rules   = $grammar->[Marpa::PP::Internal::Grammar::RULES];

    my $cycle_ranking_action =
        $grammar->[Marpa::PP::Internal::Grammar::CYCLE_RANKING_ACTION];
    my $cycle_closure;
    if ( defined $cycle_ranking_action ) {
        $cycle_closure =
            Marpa::PP::Internal::Recognizer::resolve_semantics( $recce,
            $cycle_ranking_action );
        Marpa::PP::exception(
            "Could not resolve cycle ranking action named '$cycle_ranking_action'"
        ) if not $cycle_closure;
    } ## end if ( defined $cycle_ranking_action )

    # Set up rank closures by symbol
    my %ranking_closures_by_symbol = ();
    SYMBOL: for my $symbol ( @{$symbols} ) {
        my $ranking_action =
            $symbol->[Marpa::PP::Internal::Symbol::RANKING_ACTION];
        next SYMBOL if not defined $ranking_action;
        my $ranking_closure =
            Marpa::PP::Internal::Recognizer::resolve_semantics( $recce,
            $ranking_action );
        my $symbol_name = $symbol->[Marpa::PP::Internal::Symbol::NAME];
        Marpa::PP::exception(
            "Could not resolve ranking action for symbol.\n",
            qq{    Symbol was "$symbol_name".},
            qq{    Ranking action was "$ranking_action".}
        ) if not defined $ranking_closure;
        $ranking_closures_by_symbol{$symbol_name} = $ranking_closure;
    }    # end for my $symbol ( @{$symbols} )

    # Get closure used in ranking, by rule
    my @ranking_closures_by_rule = ();
    RULE: for my $rule ( @{$rules} ) {

        my $ranking_action =
            $rule->[Marpa::PP::Internal::Rule::RANKING_ACTION];
        my $ranking_closure;
        my $cycle_rule = $rule->[Marpa::PP::Internal::Rule::CYCLE];

        Marpa::PP::exception(
            "Rule which cycles has an explicit ranking action\n",
            qq{   The ranking action is "$ranking_action"\n},
            qq{   To solve this problem,\n},
            qq{   Rewrite the grammar so that this rule does not cycle\n},
            qq{   Or eliminate its ranking action.\n}
        ) if $ranking_action and $cycle_rule;

        if ($ranking_action) {
            $ranking_closure =
                Marpa::PP::Internal::Recognizer::resolve_semantics( $recce,
                $ranking_action );
            Marpa::PP::exception(
                "Ranking closure '$ranking_action' not found")
                if not defined $ranking_closure;
        } ## end if ($ranking_action)

        if ($cycle_rule) {
            $ranking_closure = $cycle_closure;
        }

        next RULE if not $ranking_closure;

        # If the RHS is empty ...
        # Empty rules are never in cycles -- they are either
        # unused (because of the CHAF rewrite) or the special
        # null start rule.
        if ( not scalar @{ $rule->[Marpa::PP::Internal::Rule::RHS] } ) {
            Marpa::PP::exception(
                "Ranking closure '$ranking_action' not found")
                if not defined $ranking_closure;

            $ranking_closures_by_symbol{ $rule
                    ->[Marpa::PP::Internal::Rule::LHS]
                    ->[Marpa::PP::Internal::Symbol::NULL_ALIAS]
                    ->[Marpa::PP::Internal::Symbol::NAME] } =
                $ranking_closure;
        } ## end if ( not scalar @{ $rule->[Marpa::PP::Internal::Rule::RHS...]})

        next RULE if not $rule->[Marpa::PP::Internal::Rule::USED];

        $ranking_closures_by_rule[ $rule->[Marpa::PP::Internal::Rule::ID] ] =
            $ranking_closure;

    } ## end for my $rule ( @{$rules} )

    my $and_nodes = $recce->[Marpa::PP::Internal::Recognizer::AND_NODES];
    my $or_nodes  = $recce->[Marpa::PP::Internal::Recognizer::OR_NODES];

    my @and_node_worklist = ();
    AND_NODE: for my $and_node_id ( 0 .. $#{$and_nodes} ) {

        my $and_node = $and_nodes->[$and_node_id];
        my $rule_id  = $and_node->[Marpa::PP::Internal::And_Node::RULE_ID];
        my $rule_closure = $ranking_closures_by_rule[$rule_id];
        my $token_name =
            $and_node->[Marpa::PP::Internal::And_Node::TOKEN_NAME];
        my $token_closure;
        if ($token_name) {
            $token_closure = $ranking_closures_by_symbol{$token_name};
        }

        my $token_rank_ref;
        my $rule_rank_ref;

        # It is a feature of the ranking closures that they are always
        # called once per instance, even if the result is never used.
        # This sometimes makes for unnecessary calls,
        # but it makes these closures predictable enough
        # to allow their use for side effects.
        EVALUATION:
        for my $evaluation_data (
            [ \$token_rank_ref, $token_closure ],
            [ \$rule_rank_ref,  $rule_closure ]
            )
        {
            my ( $rank_ref_ref, $closure ) = @{$evaluation_data};
            next EVALUATION if not defined $closure;

            my @warnings;
            my $eval_ok;
            my $rank_ref;
            DO_EVAL: {
                local $Marpa::PP::Internal::CONTEXT =
                    [ 'and-node', $and_node, $recce ];
                local $SIG{__WARN__} =
                    sub { push @warnings, [ $_[0], ( caller 0 ) ]; };
                $eval_ok = eval { $rank_ref = $closure->(); 1; };
            } ## end DO_EVAL:

            my $fatal_error;
            CHECK_FOR_ERROR: {
                if ( not $eval_ok or scalar @warnings ) {
                    $fatal_error = $EVAL_ERROR // 'Fatal Error';
                    last CHECK_FOR_ERROR;
                }
                if ( defined $rank_ref and not ref $rank_ref ) {
                    $fatal_error =
                        "Invalid return value from ranking closure: $rank_ref";
                }
            } ## end CHECK_FOR_ERROR:

            if ( defined $fatal_error ) {

                Marpa::PP::Internal::code_problems(
                    {   fatal_error => $fatal_error,
                        grammar     => $grammar,
                        eval_ok     => $eval_ok,
                        warnings    => \@warnings,
                        where       => 'ranking and-node '
                            . $and_node->[Marpa::PP::Internal::And_Node::TAG],
                    }
                );
            } ## end if ( defined $fatal_error )

            ${$rank_ref_ref} = $rank_ref // Marpa::PP::Internal::Value::SKIP;

        } ## end for my $evaluation_data ( [ \$token_rank_ref, $token_closure...])

        # Set the token rank if there is a token.
        # It is zero if there is no token, or
        # if there is one with no closure.
        # Note: token can never cause a cycle, but they
        # can cause an and-node to be skipped.
        if ($token_name) {
            $and_node->[Marpa::PP::Internal::And_Node::TOKEN_RANK_REF] =
                $token_rank_ref // \0;
        }

        # See if we can set the rank for this node to a constant.
        my $constant_rank_ref;
        SET_CONSTANT_RANK: {

            if ( defined $token_rank_ref && !ref $token_rank_ref ) {
                $constant_rank_ref = Marpa::PP::Internal::Value::SKIP;
                last SET_CONSTANT_RANK;
            }

            # If we have ranking closure for this rule, the rank
            # is constant:
            # 0 for a non-final node,
            # the result of the closure for a final one
            if ( defined $rule_rank_ref ) {
                $constant_rank_ref =
                      $and_node->[Marpa::PP::Internal::And_Node::VALUE_OPS]
                    ? $rule_rank_ref
                    : \0;
                last SET_CONSTANT_RANK;
            } ## end if ( defined $rule_rank_ref )

            # It there is a token and no predecessor, the rank
            # of this rule is a constant:
            # 0 is there was not token symbol closure
            # the result of that closure if there was one
            if ( $token_name
                and not defined
                $and_node->[Marpa::PP::Internal::And_Node::PREDECESSOR_ID] )
            {
                $constant_rank_ref = $token_rank_ref // \0;
            } ## end if ( $token_name and not defined $and_node->[...])

        } ## end SET_CONSTANT_RANK:

        if ( defined $constant_rank_ref ) {
            $and_node->[Marpa::PP::Internal::And_Node::INITIAL_RANK_REF] =
                $and_node->[Marpa::PP::Internal::And_Node::CONSTANT_RANK_REF]
                = $constant_rank_ref;

            next AND_NODE;
        } ## end if ( defined $constant_rank_ref )

        # If we are here there is (so far) no constant rank
        # so we stack this and-node for depth-sensitive evaluation
        push @and_node_worklist, $and_node_id;

    } ## end for my $and_node_id ( 0 .. $#{$and_nodes} )

    # Now go through the and-nodes that require context to be ranked
    # This loop assumes that all cycles has been taken care of
    # with constant ranks
    AND_NODE: while ( defined( my $and_node_id = pop @and_node_worklist ) ) {

        no integer;

        my $and_node = $and_nodes->[$and_node_id];

        # Go to next if we have already ranked this and-node
        next AND_NODE
            if defined
                $and_node->[Marpa::PP::Internal::And_Node::INITIAL_RANK_REF];

        # The rank calculated so far from the
        # children
        my $calculated_rank = 0;

        my $is_cycle = 0;
        my $is_skip  = 0;
        OR_NODE:
        for my $field (
            Marpa::PP::Internal::And_Node::PREDECESSOR_ID,
            Marpa::PP::Internal::And_Node::CAUSE_ID,
            )
        {
            my $or_node_id = $and_node->[$field];
            next OR_NODE if not defined $or_node_id;

            my $or_node = $or_nodes->[$or_node_id];
            if (defined(
                    my $or_node_initial_rank_ref =
                        $or_node
                        ->[Marpa::PP::Internal::Or_Node::INITIAL_RANK_REF]
                )
                )
            {
                if ( ref $or_node_initial_rank_ref ) {
                    $calculated_rank += ${$or_node_initial_rank_ref};
                    next OR_NODE;
                }

                # At this point only possible value is skip
                $and_node->[Marpa::PP::Internal::And_Node::INITIAL_RANK_REF] =
                    $and_node
                    ->[Marpa::PP::Internal::And_Node::CONSTANT_RANK_REF] =
                    Marpa::PP::Internal::Value::SKIP;

                next AND_NODE;
            } ## end if ( defined( my $or_node_initial_rank_ref = $or_node...))
            my @ranks              = ();
            my @unranked_and_nodes = ();
            CHILD_AND_NODE:
            for my $child_and_node_id (
                @{ $or_node->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS] } )
            {
                my $rank_ref =
                    $and_nodes->[$child_and_node_id]
                    ->[Marpa::PP::Internal::And_Node::INITIAL_RANK_REF];
                if ( not defined $rank_ref ) {
                    push @unranked_and_nodes, $child_and_node_id;

                    next CHILD_AND_NODE;
                } ## end if ( not defined $rank_ref )

                # Right now the only defined scalar value for a rank is
                # Marpa::PP::Internal::Value::SKIP
                next CHILD_AND_NODE if not ref $rank_ref;

                push @ranks, ${$rank_ref};

            } ## end for my $child_and_node_id ( @{ $or_node->[...]})

            # If we have unranked child and nodes, those have to be
            # ranked first.  Schedule the work and move on.
            if ( scalar @unranked_and_nodes ) {

                push @and_node_worklist, $and_node_id, @unranked_and_nodes;
                next AND_NODE;
            }

            # If there were no non-skipped and-nodes, the
            # parent and-node must also be skipped
            if ( not scalar @ranks ) {
                $or_node->[Marpa::PP::Internal::Or_Node::INITIAL_RANK_REF] =
                    $and_node
                    ->[Marpa::PP::Internal::And_Node::INITIAL_RANK_REF] =
                    $and_node
                    ->[Marpa::PP::Internal::And_Node::CONSTANT_RANK_REF] =
                    Marpa::PP::Internal::Value::SKIP;

                next AND_NODE;
            } ## end if ( not scalar @ranks )

            my $or_calculated_rank = List::Util::max @ranks;
            $or_node->[Marpa::PP::Internal::Or_Node::INITIAL_RANK_REF] =
                \$or_calculated_rank;
            $calculated_rank += $or_calculated_rank;

        } ## end for my $field ( ...)

        my $token_rank_ref =
            $and_node->[Marpa::PP::Internal::And_Node::TOKEN_RANK_REF];
        $calculated_rank += defined $token_rank_ref ? ${$token_rank_ref} : 0;
        $and_node->[Marpa::PP::Internal::And_Node::INITIAL_RANK_REF] =
            \$calculated_rank;

    } ## end while ( defined( my $and_node_id = pop @and_node_worklist...))

    return;

} ## end sub do_rank_all

# Does not modify stack
sub Marpa::PP::Internal::Recognizer::evaluate {
    my ( $recce, $stack ) = @_;
    my $grammar      = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];
    my $trace_values = $recce->[Marpa::PP::Internal::Recognizer::TRACE_VALUES]
        // 0;

    my $rules = $grammar->[Marpa::PP::Internal::Grammar::RULES];
    my $action_object_class =
        $grammar->[Marpa::PP::Internal::Grammar::ACTION_OBJECT];

    my $action_object_constructor;
    if ( defined $action_object_class ) {
        my $constructor_name = $action_object_class . q{::new};
        my $closure =
            Marpa::PP::Internal::Recognizer::resolve_semantics( $recce,
            $constructor_name );
        Marpa::PP::exception(
            qq{Could not find constructor "$constructor_name"})
            if not defined $closure;
        $action_object_constructor = $closure;
    } ## end if ( defined $action_object_class )

    my $action_object;
    if ($action_object_constructor) {
        my @warnings;
        my $eval_ok;
        my $fatal_error;
        DO_EVAL: {
            local $EVAL_ERROR = undef;
            local $SIG{__WARN__} = sub {
                push @warnings, [ $_[0], ( caller 0 ) ];
            };

            $eval_ok = eval {
                $action_object =
                    $action_object_constructor->($action_object_class);
                1;
            };
            $fatal_error = $EVAL_ERROR;
        } ## end DO_EVAL:

        if ( not $eval_ok or @warnings ) {
            Marpa::PP::Internal::code_problems(
                {   fatal_error => $fatal_error,
                    grammar     => $grammar,
                    eval_ok     => $eval_ok,
                    warnings    => \@warnings,
                    where       => 'constructing action object',
                }
            );
        } ## end if ( not $eval_ok or @warnings )
    } ## end if ($action_object_constructor)

    $action_object //= {};

    my @evaluation_stack   = ();
    my @virtual_rule_stack = ();
    TREE_NODE: for my $and_node ( reverse @{$stack} ) {

        if ( $trace_values >= 3 ) {
            for my $i ( reverse 0 .. $#evaluation_stack ) {
                printf {$Marpa::PP::Internal::TRACE_FH} 'Stack position %3d:',
                    $i
                    or Marpa::PP::exception('print to trace handle failed');
                print {$Marpa::PP::Internal::TRACE_FH} q{ },
                    Data::Dumper->new( [ $evaluation_stack[$i] ] )->Terse(1)
                    ->Dump
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end for my $i ( reverse 0 .. $#evaluation_stack )
        } ## end if ( $trace_values >= 3 )

        my $value_ref = $and_node->[Marpa::PP::Internal::And_Node::VALUE_REF];

        if ( defined $value_ref ) {

            push @evaluation_stack, $value_ref;

            if ($trace_values) {
                my $token_name =
                    $and_node->[Marpa::PP::Internal::And_Node::TOKEN_NAME];

                print {$Marpa::PP::Internal::TRACE_FH}
                    'Pushed value from ',
                    $and_node->[Marpa::PP::Internal::And_Node::TAG], ': ',
                    ( $token_name ? qq{$token_name = } : q{} ),
                    Data::Dumper->new( [$value_ref] )->Terse(1)->Dump
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_values)

        }    # defined $value_ref

        my $ops = $and_node->[Marpa::PP::Internal::And_Node::VALUE_OPS];

        next TREE_NODE if not defined $ops;

        my $current_data = [];
        my $op_ix        = 0;
        while ( $op_ix < scalar @{$ops} ) {
            given ( $ops->[ $op_ix++ ] ) {

                when (Marpa::PP::Internal::Op::ARGC) {

                    my $argc = $ops->[ $op_ix++ ];

                    if ($trace_values) {
                        my $rule_id = $and_node
                            ->[Marpa::PP::Internal::And_Node::RULE_ID];
                        my $rule = $rules->[$rule_id];
                        say {$Marpa::PP::Internal::TRACE_FH}
                            'Popping ',
                            $argc,
                            ' values to evaluate ',
                            $and_node->[Marpa::PP::Internal::And_Node::TAG],
                            ', rule: ', Marpa::PP::brief_rule($rule)
                            or Marpa::PP::exception(
                            'Could not print to trace file');
                    } ## end if ($trace_values)

                    $current_data =
                        [ map { ${$_} }
                            ( splice @evaluation_stack, -$argc ) ];

                } ## end when (Marpa::PP::Internal::Op::ARGC)

                when (Marpa::PP::Internal::Op::VIRTUAL_HEAD) {
                    my $real_symbol_count = $ops->[ $op_ix++ ];

                    if ($trace_values) {
                        my $rule_id = $and_node
                            ->[Marpa::PP::Internal::And_Node::RULE_ID];
                        my $rule = $rules->[$rule_id];
                        say {$Marpa::PP::Internal::TRACE_FH}
                            'Head of Virtual Rule: ',
                            $and_node->[Marpa::PP::Internal::And_Node::TAG],
                            ', rule: ', Marpa::PP::brief_rule($rule),
                            "\n",
                            "Incrementing virtual rule by $real_symbol_count symbols\n",
                            'Currently ',
                            ( scalar @virtual_rule_stack ),
                            ' rules; ', $virtual_rule_stack[-1], ' symbols;',
                            or Marpa::PP::exception(
                            'Could not print to trace file');
                    } ## end if ($trace_values)

                    $real_symbol_count += pop @virtual_rule_stack;
                    $current_data =
                        [ map { ${$_} }
                            ( splice @evaluation_stack, -$real_symbol_count )
                        ];

                } ## end when (Marpa::PP::Internal::Op::VIRTUAL_HEAD)

                when (Marpa::PP::Internal::Op::VIRTUAL_KERNEL) {
                    my $real_symbol_count = $ops->[ $op_ix++ ];
                    $virtual_rule_stack[-1] += $real_symbol_count;

                    if ($trace_values) {
                        my $rule_id = $and_node
                            ->[Marpa::PP::Internal::And_Node::RULE_ID];
                        my $rule = $rules->[$rule_id];
                        say {$Marpa::PP::Internal::TRACE_FH}
                            'Virtual Rule: ',
                            $and_node->[Marpa::PP::Internal::And_Node::TAG],
                            ', rule: ', Marpa::PP::brief_rule($rule),
                            "\nAdding $real_symbol_count",
                            or Marpa::PP::exception(
                            'Could not print to trace file');
                    } ## end if ($trace_values)

                } ## end when (Marpa::PP::Internal::Op::VIRTUAL_KERNEL)

                when (Marpa::PP::Internal::Op::VIRTUAL_TAIL) {
                    my $real_symbol_count = $ops->[ $op_ix++ ];

                    if ($trace_values) {
                        my $rule_id = $and_node
                            ->[Marpa::PP::Internal::And_Node::RULE_ID];
                        my $rule = $rules->[$rule_id];
                        say {$Marpa::PP::Internal::TRACE_FH}
                            'New Virtual Rule: ',
                            $and_node->[Marpa::PP::Internal::And_Node::TAG],
                            ', rule: ', Marpa::PP::brief_rule($rule),
                            "\nReal symbol count is $real_symbol_count",
                            or Marpa::PP::exception(
                            'Could not print to trace file');
                    } ## end if ($trace_values)

                    push @virtual_rule_stack, $real_symbol_count;

                } ## end when (Marpa::PP::Internal::Op::VIRTUAL_TAIL)

                when (Marpa::PP::Internal::Op::CONSTANT_RESULT) {
                    my $result = $ops->[ $op_ix++ ];
                    if ($trace_values) {
                        print {$Marpa::PP::Internal::TRACE_FH}
                            'Constant result: ',
                            'Pushing 1 value on stack: ',
                            Data::Dumper->new( [$result] )->Terse(1)->Dump
                            or Marpa::PP::exception(
                            'Could not print to trace file');
                    } ## end if ($trace_values)
                    push @evaluation_stack, $result;
                } ## end when (Marpa::PP::Internal::Op::CONSTANT_RESULT)

                when (Marpa::PP::Internal::Op::CALL) {
                    my $closure = $ops->[ $op_ix++ ];
                    my $rule_id =
                        $and_node->[Marpa::PP::Internal::And_Node::RULE_ID];
                    my $rule = $rules->[$rule_id];
                    my $original_rule = $rule->[Marpa::PP::Internal::Rule::ORIGINAL_RULE];
                    if ($original_rule->[Marpa::PP::Internal::Rule::DISCARD_SEPARATION])
                    {
                        $current_data =
                            [ @{$current_data}[ grep { not $_ % 2 }
                            0 .. $#{$current_data} ] ];
                    } ## end if ( $rule->[...])
                    my $result;

                    my @warnings;
                    my $eval_ok;
                    DO_EVAL: {
                        local $SIG{__WARN__} = sub {
                            push @warnings, [ $_[0], ( caller 0 ) ];
                        };

                        $eval_ok = eval {
                            $result =
                                $closure->( $action_object,
                                @{$current_data} );
                            1;
                        };

                    } ## end DO_EVAL:

                    if ( not $eval_ok or @warnings ) {
                        my $fatal_error = $EVAL_ERROR;
                        Marpa::PP::Internal::code_problems(
                            {   fatal_error => $fatal_error,
                                grammar     => $grammar,
                                eval_ok     => $eval_ok,
                                warnings    => \@warnings,
                                where       => 'computing value',
                                long_where  => 'Computing value for rule: '
                                    . Marpa::PP::brief_rule($rule),
                            }
                        );
                    } ## end if ( not $eval_ok or @warnings )

                    if ($trace_values) {
                        print {$Marpa::PP::Internal::TRACE_FH}
                            'Calculated and pushed value: ',
                            Data::Dumper->new( [$result] )->Terse(1)->Dump
                            or Marpa::PP::exception(
                            'print to trace handle failed');
                    } ## end if ($trace_values)

                    push @evaluation_stack, \$result;

                } ## end when (Marpa::PP::Internal::Op::CALL)

                default {
                    Marpa::PP::exception("Unknown evaluator Op: $_");
                }

            } ## end given
        } ## end while ( $op_ix < scalar @{$ops} )

    }    # TREE_NODE

    return pop @evaluation_stack;
} ## end sub Marpa::PP::Internal::Recognizer::evaluate

# null parse is special case
sub Marpa::PP::Internal::Recognizer::do_null_parse {
    my ( $recce, $start_rule ) = @_;

    my $start_symbol = $start_rule->[Marpa::PP::Internal::Rule::LHS];

    # Cannot increment the null parse
    return if $recce->[Marpa::PP::Internal::Recognizer::PARSE_COUNT]++;
    my $null_values = $recce->[Marpa::PP::Internal::Recognizer::NULL_VALUES];
    my $evaluator_rules =
        $recce->[Marpa::PP::Internal::Recognizer::EVALUATOR_RULES];

    my $start_symbol_id = $start_symbol->[Marpa::PP::Internal::Symbol::ID];
    my $start_rule_id   = $start_rule->[Marpa::PP::Internal::Rule::ID];

    my $and_node = [];
    $#{$and_node} = Marpa::PP::Internal::And_Node::LAST_FIELD;
    $and_node->[Marpa::PP::Internal::And_Node::VALUE_REF] =
        \( $null_values->[$start_symbol_id] );
    $and_node->[Marpa::PP::Internal::And_Node::RULE_ID] =
        $start_rule->[Marpa::PP::Internal::Rule::ID];
    $and_node->[Marpa::PP::Internal::And_Node::VALUE_OPS] =
        $evaluator_rules->[$start_rule_id];

    $and_node->[Marpa::PP::Internal::And_Node::POSITION]      = 0;
    $and_node->[Marpa::PP::Internal::And_Node::START_EARLEME] = 0;
    $and_node->[Marpa::PP::Internal::And_Node::CAUSE_EARLEME] = 0;
    $and_node->[Marpa::PP::Internal::And_Node::END_EARLEME]   = 0;
    $and_node->[Marpa::PP::Internal::And_Node::ID]            = 0;
    my $symbol_name = $start_symbol->[Marpa::PP::Internal::Symbol::NAME];
    $and_node->[Marpa::PP::Internal::And_Node::TOKEN_NAME]    = $symbol_name;
    $and_node->[Marpa::PP::Internal::And_Node::TAG] =
        Marpa::PP::Recognizer::and_node_tag($recce, $and_node);

    $recce->[Marpa::PP::Internal::Recognizer::AND_NODES]->[0] = $and_node;

    return Marpa::PP::Internal::Recognizer::evaluate( $recce, [$and_node] );

} ## end sub Marpa::PP::Internal::Recognizer::do_null_parse

# Returns false if no parse
sub Marpa::PP::Recognizer::value {
    my ( $recce, @arg_hashes ) = @_;

    my $parse_set_arg = $recce->[Marpa::PP::Internal::Recognizer::END];

    my $trace_tasks = $recce->[Marpa::PP::Internal::Recognizer::TRACE_TASKS];
    local $Marpa::PP::Internal::TRACE_FH =
        $recce->[Marpa::PP::Internal::Recognizer::TRACE_FILE_HANDLE];

    my $and_nodes = $recce->[Marpa::PP::Internal::Recognizer::AND_NODES];
    my $or_nodes  = $recce->[Marpa::PP::Internal::Recognizer::OR_NODES];
    my $ranking_method =
        $recce->[Marpa::PP::Internal::Recognizer::RANKING_METHOD];

    if ( $recce->[Marpa::PP::Internal::Recognizer::SINGLE_PARSE_MODE] ) {
        Marpa::PP::exception(
            qq{Arguments were passed directly to value() in a previous call\n},
            qq{Only one call to value() is allowed per recognizer when arguments are passed directly\n},
            qq{This is the second call to value()\n}
        );
    } ## end if ( $recce->[Marpa::PP::Internal::Recognizer::SINGLE_PARSE_MODE...])

    my $parse_count = $recce->[Marpa::PP::Internal::Recognizer::PARSE_COUNT];
    my $max_parses  = $recce->[Marpa::PP::Internal::Recognizer::MAX_PARSES];
    if ( $max_parses and $parse_count > $max_parses ) {
        Marpa::PP::exception("Maximum parse count ($max_parses) exceeded");
    }

    for my $arg_hash (@arg_hashes) {

        if ( exists $arg_hash->{end} ) {
            if ($parse_count) {
                Marpa::PP::exception(
                    q{Cannot change "end" after first parse result});
            }
            $recce->[Marpa::PP::Internal::Recognizer::SINGLE_PARSE_MODE] = 1;
            $parse_set_arg = $arg_hash->{end};
            delete $arg_hash->{end};
        } ## end if ( exists $arg_hash->{end} )

        if ( exists $arg_hash->{closures} ) {
            if ($parse_count) {
                Marpa::PP::exception(
                    q{Cannot change "closures" after first parse result});
            }
            $recce->[Marpa::PP::Internal::Recognizer::SINGLE_PARSE_MODE] = 1;
            my $closures = $arg_hash->{closures};
            while ( my ( $action, $closure ) = each %{$closures} ) {
                Marpa::PP::exception(qq{Bad closure for action "$action"})
                    if ref $closure ne 'CODE';
            }
            $recce->[Marpa::PP::Internal::Recognizer::CLOSURES] = $closures;
            delete $arg_hash->{closures};
        } ## end if ( exists $arg_hash->{closures} )

        if ( exists $arg_hash->{trace_actions} ) {
            $recce->[Marpa::PP::Internal::Recognizer::SINGLE_PARSE_MODE] = 1;
            $recce->[Marpa::PP::Internal::Recognizer::TRACE_ACTIONS] =
                $arg_hash->{trace_actions};
            delete $arg_hash->{trace_actions};
        } ## end if ( exists $arg_hash->{trace_actions} )

        if ( exists $arg_hash->{trace_values} ) {
            $recce->[Marpa::PP::Internal::Recognizer::SINGLE_PARSE_MODE] = 1;
            $recce->[Marpa::PP::Internal::Recognizer::TRACE_VALUES] =
                $arg_hash->{trace_values};
            delete $arg_hash->{trace_values};
        } ## end if ( exists $arg_hash->{trace_values} )

        # A typo made its way into the documentation, so now it's a
        # synonym.
        for my $trace_fh_alias (qw(trace_fh trace_file_handle)) {
            if ( exists $arg_hash->{$trace_fh_alias} ) {
                $recce->[Marpa::PP::Internal::Recognizer::TRACE_FILE_HANDLE] =
                    $Marpa::PP::Internal::TRACE_FH =
                    $arg_hash->{$trace_fh_alias};
                delete $arg_hash->{$trace_fh_alias};
            } ## end if ( exists $arg_hash->{$trace_fh_alias} )
        } ## end for my $trace_fh_alias (qw(trace_fh trace_file_handle))

        my @unknown_arg_names = keys %{$arg_hash};
        Marpa::PP::exception(
            'Unknown named argument(s) to Marpa::PP::Recognizer::value: ',
            ( join q{ }, @unknown_arg_names ) )
            if @unknown_arg_names;

    } ## end for my $arg_hash (@arg_hashes)

    my $grammar     = $recce->[Marpa::PP::Internal::Recognizer::GRAMMAR];
    my $earley_sets = $recce->[Marpa::PP::Internal::Recognizer::EARLEY_SETS];

    my $furthest_earleme =
        $recce->[Marpa::PP::Internal::Recognizer::FURTHEST_EARLEME];
    my $last_completed_earleme =
        $recce->[Marpa::PP::Internal::Recognizer::LAST_COMPLETED_EARLEME];
    Marpa::PP::exception(
        "Attempt to evaluate incompletely recognized parse:\n",
        "  Last token ends at location $furthest_earleme\n",
        "  Recognition done only as far as location $last_completed_earleme\n"
    ) if $furthest_earleme > $last_completed_earleme;

    my $rules   = $grammar->[Marpa::PP::Internal::Grammar::RULES];
    my $symbols = $grammar->[Marpa::PP::Internal::Grammar::SYMBOLS];

    my $current_parse_set = $parse_set_arg
        // $recce->[Marpa::PP::Internal::Recognizer::FURTHEST_EARLEME];

    # Look for the start item and start rule
    my $earley_set = $earley_sets->[$current_parse_set];

    # Perhaps this call should be moved.
    # The null values are currently a function of the grammar,
    # and should be constant for the life of a recognizer.
    my $null_values =
        $recce->[Marpa::PP::Internal::Recognizer::NULL_VALUES] //=
        Marpa::PP::Internal::Recognizer::set_null_values($recce);

    my @task_list;
    my $start_item;
    my $start_rule;
    if ($parse_count) {
        @task_list = ( [Marpa::PP::Internal::Task::ITERATE] );
    }
    else {
        my $start_state;

        EARLEY_ITEM:
        for my $item (
            @{ $earley_set->[Marpa::PP::Internal::Earley_Set::ITEMS] } )
        {
            $start_state = $item->[Marpa::PP::Internal::Earley_Item::STATE];
            $start_rule =
                $start_state->[Marpa::PP::Internal::AHFA::START_RULE];
            next EARLEY_ITEM if not $start_rule;
            $start_item = $item;
            last EARLEY_ITEM;
        } ## end for my $item ( @{ $earley_set->[...]})

        return if not $start_rule;

        $recce->[Marpa::PP::Internal::Recognizer::EVALUATOR_RULES] =
            Marpa::PP::Internal::Recognizer::set_actions($recce);

        return Marpa::PP::Internal::Recognizer::do_null_parse( $recce,
            $start_rule )
            if $start_rule->[Marpa::PP::Internal::Rule::LHS]
                ->[Marpa::PP::Internal::Symbol::NULLING];

        @task_list = ();
        push @task_list, [Marpa::PP::Internal::Task::INITIALIZE];
    } ## end else [ if ($parse_count) ]

    $recce->[Marpa::PP::Internal::Recognizer::PARSE_COUNT]++;

    my $evaluator_rules =
        $recce->[Marpa::PP::Internal::Recognizer::EVALUATOR_RULES];
    my $iteration_stack =
        $recce->[Marpa::PP::Internal::Recognizer::ITERATION_STACK];

    my $iteration_node_worklist;
    my @and_node_in_use = ();
    for my $iteration_node (@{$iteration_stack}) {
	my $choices = $iteration_node->[Marpa::PP::Internal::Iteration_Node::CHOICES];
	my $choice = $choices->[0];
	my $and_node = $choice->[Marpa::PP::Internal::Choice::AND_NODE];
	my $and_node_id = $and_node->[Marpa::PP::Internal::And_Node::ID];
	$and_node_in_use[$and_node_id] = 1;
    }

    TASK: while ( my $task = pop @task_list ) {

        my ( $task_type, @task_data ) = @{$task};

        # Create the unpopulated top or-node
        if ( $task_type == Marpa::PP::Internal::Task::INITIALIZE ) {

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH}
                    'Task: INITIALIZE; ',
                    ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_tasks)

            my $start_rule_id = $start_rule->[Marpa::PP::Internal::Rule::ID];

            my $start_or_node = [];
            $start_or_node->[Marpa::PP::Internal::Or_Node::ID] = 0;
            $start_or_node->[Marpa::PP::Internal::Or_Node::ITEM] =
                    $start_item;
            $start_or_node->[Marpa::PP::Internal::Or_Node::RULE_ID] =
                $start_rule_id;

            # Start or-node cannot cycle
            $start_or_node->[Marpa::PP::Internal::Or_Node::CYCLE] = 0;
            $start_or_node->[Marpa::PP::Internal::Or_Node::POSITION] =
                scalar @{ $start_rule->[Marpa::PP::Internal::Rule::RHS] };
            {
                my $start_or_node_tag =
                    $start_or_node->[Marpa::PP::Internal::Or_Node::TAG] =
			Marpa::PP::Recognizer::or_node_tag($recce, $start_or_node);
                $recce->[Marpa::PP::Internal::Recognizer::OR_NODE_HASH]
                    ->{$start_or_node_tag} = $start_or_node;
            }

            # Zero out the evaluation
            $#{$and_nodes}       = -1;
            $#{$or_nodes}        = -1;
            $#{$iteration_stack} = -1;
	    $#and_node_in_use = -1;

            # Populate the start or-node
            $or_nodes->[0] = $start_or_node;

            my $start_iteration_node = [];
            $start_iteration_node
                ->[Marpa::PP::Internal::Iteration_Node::OR_NODE] =
                $start_or_node;

            @task_list = ();
            push @task_list, [Marpa::PP::Internal::Task::FIX_TREE],
                [
                Marpa::PP::Internal::Task::STACK_INODE,
                $start_iteration_node
                ];

            if ( $ranking_method eq 'constant' ) {
                push @task_list, [Marpa::PP::Internal::Task::RANK_ALL],
            } ## end if ( $ranking_method eq 'constant' )

            push @task_list,
                [
                Marpa::PP::Internal::Task::POPULATE_DEPTH, 0,
                [$start_or_node]
                ],
                [
                Marpa::PP::Internal::Task::POPULATE_OR_NODE,
                $start_or_node
                ];

            next TASK;

        } ## end if ( $task_type == Marpa::PP::Internal::Task::INITIALIZE)

        # Special processing for the top iteration node
        if ( $task_type == Marpa::PP::Internal::Task::ITERATE ) {

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH}
                    'Task: ITERATE; ',
                    ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_tasks)

            $iteration_node_worklist = undef;

            # In this pass, we go up the iteration stack,
            # looking a node which we can iterate.
            my $iteration_node;
            my $choices;
            ITERATION_NODE:
            while ( $iteration_node = pop @{$iteration_stack} ) {

		my $choices = $iteration_node->[Marpa::PP::Internal::Iteration_Node::CHOICES];

		# Eliminate the current choice
		my $choice = $choices->[0];
		my $and_node = $choice->[Marpa::PP::Internal::Choice::AND_NODE];
		my $and_node_id = $and_node->[Marpa::PP::Internal::And_Node::ID];
		$and_node_in_use[$and_node_id] = undef;
                shift @{$choices};

		# Throw away choices until we find one that does not cycle
                CHOICE: while ( scalar @{$choices} ) {
		    $choice = $choices->[0];
		    $and_node = $choice->[Marpa::PP::Internal::Choice::AND_NODE];
		    $and_node_id = $and_node->[Marpa::PP::Internal::And_Node::ID];
		    last CHOICE if not $and_node_in_use[$and_node_id];
		    shift @{$choices};
		}

                # Climb the parent links, marking the ranks
                # of the nodes "dirty", until we hit one this is
                # already dirty
                my $direct_parent = $iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::PARENT];
                PARENT:
                for ( my $parent = $direct_parent; defined $parent; ) {
                    my $parent_node = $iteration_stack->[$parent];
                    last PARENT
                        if not $parent_node
                            ->[Marpa::PP::Internal::Iteration_Node::CLEAN];
                    $parent_node->[Marpa::PP::Internal::Iteration_Node::CLEAN]
                        = 0;
                    $parent = $parent_node
                        ->[Marpa::PP::Internal::Iteration_Node::PARENT];
                } ## end for ( my $parent = $direct_parent; defined $parent; )

                # This or-node is already populated,
                # or it would not have been put
                # onto the iteration stack
                $choices = $iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::CHOICES];

                if ( not scalar @{$choices} ) {

                    # For the node just popped off the stack
                    # unset the pointer to it in its parent
                    if ( defined $direct_parent ) {

                        #<<< cycles on perltidy version 20090616
                        my $child_type = $iteration_node->[
                            Marpa::PP::Internal::Iteration_Node::CHILD_TYPE ];
                        #>>>
                        #
                        $iteration_stack->[$direct_parent]->[
                            $child_type
                            == Marpa::PP::Internal::And_Node::PREDECESSOR_ID
                            ? Marpa::PP::Internal::Iteration_Node::PREDECESSOR_IX
                            : Marpa::PP::Internal::Iteration_Node::CAUSE_IX
                            ]
                            = undef;
                    } ## end if ( defined $direct_parent )
                    next ITERATION_NODE;
                } ## end if ( scalar @{$choices} <= 1 )

                # Dirty the iteration node and put it back
                # on the stack
                $iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::PREDECESSOR_IX] =
                    undef;
                $iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::CAUSE_IX] = undef;
                $iteration_node->[Marpa::PP::Internal::Iteration_Node::CLEAN]
                    = 0;
                push @{$iteration_stack}, $iteration_node;

		$choice = $choices->[0];
		$and_node = $choice->[Marpa::PP::Internal::Choice::AND_NODE];
		$and_node_id = $and_node->[Marpa::PP::Internal::And_Node::ID];
		$and_node_in_use[$and_node_id] = 1;

                last ITERATION_NODE;

            } ## end while ( $iteration_node = pop @{$iteration_stack} )

            # If we hit the top of the stack without finding any node
            # to iterate, that is it for parsing.
            return if not defined $iteration_node;

            push @task_list, [Marpa::PP::Internal::Task::FIX_TREE];

            next TASK;

        } ## end if ( $task_type == Marpa::PP::Internal::Task::ITERATE)

        # This task is set up to rerun itself until explicitly exited
        FIX_TREE_LOOP:
        while ( $task_type == Marpa::PP::Internal::Task::FIX_TREE ) {

            # If the work list is undefined, initialize it to the entire stack
            $iteration_node_worklist //= [ 0 .. $#{$iteration_stack} ];
            next TASK if not scalar @{$iteration_node_worklist};
            my $working_node_ix = $iteration_node_worklist->[-1];

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH}
                    q{Task: FIX_TREE; },
                    ( scalar @{$iteration_node_worklist} ),
                    " current iteration node #$working_node_ix; ",
                    ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_tasks)

            # We are done fixing the tree is the worklist is empty

            my $working_node = $iteration_stack->[$working_node_ix];
            my $choices =
                $working_node->[Marpa::PP::Internal::Iteration_Node::CHOICES];
            my $choice = $choices->[0];
            my $working_and_node =
                $choice->[Marpa::PP::Internal::Choice::AND_NODE];

            FIELD:
            for my $field ( Marpa::PP::Internal::Iteration_Node::CAUSE_IX,
                Marpa::PP::Internal::Iteration_Node::PREDECESSOR_IX
                )
            {
                my $ix = $working_node->[$field];
                next FIELD if defined $ix;
                my $and_node_field =
                    $field
                    == Marpa::PP::Internal::Iteration_Node::PREDECESSOR_IX
                    ? Marpa::PP::Internal::And_Node::PREDECESSOR_ID
                    : Marpa::PP::Internal::And_Node::CAUSE_ID;

                my $or_node_id = $working_and_node->[$and_node_field];
                if ( not defined $or_node_id ) {
                    $working_node->[$field] = -999_999_999;
                    next FIELD;
                }

                my $new_iteration_node = [];
                $new_iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::OR_NODE] =
                    $or_nodes->[$or_node_id];
                $new_iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::PARENT] =
                    $working_node_ix;
                $new_iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::CHILD_TYPE] =
                    $and_node_field;

                # Restack the current task, adding a task to create
                # the child iteration node
                push @task_list, $task,
                    [
                    Marpa::PP::Internal::Task::STACK_INODE,
                    $new_iteration_node
                    ];
                next TASK;
            } ## end for my $field ( ...)

	    $working_node->[Marpa::PP::Internal::Iteration_Node::CLEAN] =
		1;
	    pop @{$iteration_node_worklist};
	    next FIX_TREE_LOOP;

        } ## end while ( $task_type == Marpa::PP::Internal::Task::FIX_TREE)

        if ( $task_type == Marpa::PP::Internal::Task::POPULATE_OR_NODE ) {

            my $work_or_node = $task_data[0];

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH}
                    'Task: POPULATE_OR_NODE o',
                    $work_or_node->[Marpa::PP::Internal::Or_Node::ID],
                    q{; }, ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_tasks)

            my $work_node_name =
                $work_or_node->[Marpa::PP::Internal::Or_Node::TAG];

            # SET Should be the same for all items
            my $or_node_item = 
                $work_or_node->[Marpa::PP::Internal::Or_Node::ITEM];

	    my $work_set =
		$or_node_item->[Marpa::PP::Internal::Earley_Item::SET];
	    my $work_node_origin =
		$or_node_item->[Marpa::PP::Internal::Earley_Item::ORIGIN];

            my $work_rule_id =
                $work_or_node->[Marpa::PP::Internal::Or_Node::RULE_ID];
            my $work_rule = $rules->[$work_rule_id];
            my $work_position =
                $work_or_node->[Marpa::PP::Internal::Or_Node::POSITION] - 1;
            my $work_symbol =
                $work_rule->[Marpa::PP::Internal::Rule::RHS]
                ->[$work_position];
	    my $work_symbol_name = $work_symbol->[Marpa::PP::Internal::Symbol::NAME];

            {

		my $item = $or_node_item;
                my $or_sapling_set = $work_set;

                my $leo_links =
                    defined $item->[Marpa::PP::Internal::Earley_Item::IS_LEO_EXPANDED]
                    ? [] : $item->[Marpa::PP::Internal::Earley_Item::LEO_LINKS];
                $leo_links //= [];

                # If this is a Leo completion, translate the Leo links
                for my $leo_link ( @{$leo_links} ) {

                    my ( $leo_item, $cause ) =
                        @{$leo_link};

                    my $next_leo_item = $leo_item
                        ->[Marpa::PP::Internal::Leo_Item::PREDECESSOR];
		    my $leo_symbol_name =
			$leo_item->[Marpa::PP::Internal::Leo_Item::LEO_POSTDOT_SYMBOL];
                    my $leo_base_item =
                        $leo_item->[Marpa::PP::Internal::Leo_Item::BASE];

                    my $next_links = [[ $leo_base_item, $cause, ]];

                    LEO_ITEM: for ( ;; ) {

                        if ( not $next_leo_item ) {

                            # die join " ", __FILE__, __LINE__, "next link cnt", (scalar @{$next_links})
                                # if scalar @{$next_links} != 1;

                            #<<< perltidy cycles as of version 20090616
                            push @{ $item
                                    ->[Marpa::PP::Internal::Earley_Item::LINKS
                                    ] },
                                @{$next_links};
                            #<<<

			    # Now that the Leo links are translated, mark the
			    # Earley item accordingly
			    $item->[Marpa::PP::Internal::Earley_Item::IS_LEO_EXPANDED] = 1;

                            last LEO_ITEM;

                        } ## end if ( not $next_leo_item )

			my ( undef, $base_to_state ) =
			    @{ $leo_base_item
				->[ Marpa::PP::Internal::Earley_Item::STATE ]
				->[Marpa::PP::Internal::AHFA::TRANSITION]
				->{$leo_symbol_name} };
                        my $origin = $next_leo_item
                            ->[Marpa::PP::Internal::Leo_Item::SET];

                        my $name = sprintf
                            'S%d@%d-%d',
                            $base_to_state->[Marpa::PP::Internal::AHFA::ID],
                            $origin,
                            $or_sapling_set;
			my $hash_key = join ':', 
                            $base_to_state->[Marpa::PP::Internal::AHFA::ID],
			    $origin;
			my $earley_hash =
			    $earley_sets->[$or_sapling_set]
			    ->[Marpa::PP::Internal::Earley_Set::HASH];

                        my $target_item = $earley_hash->{$hash_key};
                        if ( not defined $target_item ) {
                            $target_item = [];
                            $target_item
                                ->[Marpa::PP::Internal::Earley_Item::ID] =
                                $recce->[
                                Marpa::PP::Internal::Recognizer::NEXT_EARLEY_ITEM_ID
                                ]++;
                            $target_item
                                ->[Marpa::PP::Internal::Earley_Item::ORIGIN] =
                                $origin;
                            $target_item
                                ->[Marpa::PP::Internal::Earley_Item::STATE] =
                                $base_to_state;
                            $target_item
                                ->[Marpa::PP::Internal::Earley_Item::LINKS] =
                                [];
                            $target_item
                                ->[Marpa::PP::Internal::Earley_Item::SET] =
                                $or_sapling_set;
                            $earley_hash->{$hash_key} = $target_item;
                            push @{ $earley_sets->[$or_sapling_set]
                                    ->[Marpa::PP::Internal::Earley_Set::ITEMS]
                                }, $target_item;
                        } ## end if ( not defined $target_item )

                        push @{ $target_item
                                ->[Marpa::PP::Internal::Earley_Item::LINKS] },
                            @{$next_links};

                        $leo_item      = $next_leo_item;
                        $next_leo_item = $leo_item
                            ->[Marpa::PP::Internal::Leo_Item::PREDECESSOR];
                        $leo_base_item =
                            $leo_item->[Marpa::PP::Internal::Leo_Item::BASE];
			$leo_symbol_name =
			    $leo_item->[Marpa::PP::Internal::Leo_Item::LEO_POSTDOT_SYMBOL];

                        $next_links = [ [ $leo_base_item, $target_item, $leo_symbol_name ] ];

                    } ## end for ( ;; )
                } ## end for my $leo_link ( @{$leo_links} )

            }

            my @link_worklist;

            CREATE_LINK_WORKLIST: {

                # Several Earley items may be the source of the same or-node,
                # but the or-node only keeps track of one.  This is sufficient,
                # because the Earley item is tracked by the or-node only for its
                # links, and the links for every Earley item which is the source
                # of the same or-node must be the same.  There's more about this
		# in the libmarpa docs.

                # link worklist item is $predecessor, $cause, $token_name, $value_ref

                # All predecessors apply to a
                # nulling work symbol.

                if ( $work_symbol->[Marpa::PP::Internal::Symbol::NULLING] ) {
                    my $nulling_symbol_id =
                        $work_symbol->[Marpa::PP::Internal::Symbol::ID];
                    my $value_ref = \$null_values->[$nulling_symbol_id];
                    @link_worklist =
                        [ $or_node_item, undef, $work_symbol_name, $value_ref ];
                    last CREATE_LINK_WORKLIST;
                } ## end if ( $work_symbol->[...])

                # Collect links for or node items
                # into link work items
                @link_worklist =
                    @{ $or_node_item->[Marpa::PP::Internal::Earley_Item::LINKS] };

            } ## end CREATE_LINK_WORKLIST:

            # The and node data is put into the hash, only to be taken out immediately,
            # but in the process the very important step of eliminating duplicates
            # is accomplished.
            my %and_node_data = ();

            LINK_WORK_ITEM: for my $link_work_item (@link_worklist) {

		my ( $predecessor, $cause, $symbol_name, $value_ref ) =
                    @{$link_work_item};

		# next LINK_WORK_ITEM if $symbol_name ne $work_symbol_name;

                my $cause_earleme = $work_node_origin;
                my $predecessor_id;
		my $predecessor_name;

                if ( $work_position > 0 ) {

                    $cause_earleme =
                        $predecessor->[Marpa::PP::Internal::Earley_Item::SET];

                    $predecessor_name =
                        "R$work_rule_id:$work_position" . q{@}
                        . $predecessor
                        ->[Marpa::PP::Internal::Earley_Item::ORIGIN] . q{-}
                        . $cause_earleme;

                    FIND_PREDECESSOR: {
                        my $predecessor_or_node =
                            $recce
                            ->[Marpa::PP::Internal::Recognizer::OR_NODE_HASH]
                            ->{$predecessor_name};
                        if ($predecessor_or_node) {
                            $predecessor_id = $predecessor_or_node
                                ->[Marpa::PP::Internal::Or_Node::ID];

                            last FIND_PREDECESSOR;

                        } ## end if ($predecessor_or_node)

                        $predecessor_or_node = [];
                        $predecessor_or_node
                            ->[Marpa::PP::Internal::Or_Node::TAG] =
                            $predecessor_name;
                        $recce
                            ->[Marpa::PP::Internal::Recognizer::OR_NODE_HASH]
                            ->{$predecessor_name} = $predecessor_or_node;
                        $predecessor_or_node
                            ->[Marpa::PP::Internal::Or_Node::RULE_ID] =
                            $work_rule_id;

                        # nulling nodes are never part of cycles
                        # thanks to the CHAF rewrite
                        $predecessor_or_node
                            ->[Marpa::PP::Internal::Or_Node::CYCLE] =
                            $work_rule
                            ->[Marpa::PP::Internal::Rule::VIRTUAL_CYCLE]
                            && $cause_earleme != $work_node_origin;
                        $predecessor_or_node
                            ->[Marpa::PP::Internal::Or_Node::POSITION] =
                            $work_position;
                        $predecessor_or_node
                            ->[Marpa::PP::Internal::Or_Node::ITEM] =
                                $predecessor;
                        $predecessor_id =
                            ( push @{$or_nodes}, $predecessor_or_node ) - 1;

                        Marpa::PP::exception(
                            "Too many or-nodes for evaluator: $predecessor_id"
                            )
                            if $predecessor_id
                                & ~(Marpa::PP::Internal::N_FORMAT_MAX);
                        $predecessor_or_node
                            ->[Marpa::PP::Internal::Or_Node::ID] =
                            $predecessor_id;

                    } ## end FIND_PREDECESSOR:

                } ## end if ( $work_position > 0 )

                my $cause_id;

                if ( defined $cause ) {

                    my $cause_symbol_id =
                        $work_symbol->[Marpa::PP::Internal::Symbol::ID];

                    my $state =
                        $cause->[Marpa::PP::Internal::Earley_Item::STATE];

                    for my $cause_rule (
                        @{  $state
                                ->[Marpa::PP::Internal::AHFA::COMPLETE_RULES]
                                ->[$cause_symbol_id]
                        }
                        )
                    {

                        my $cause_rule_id =
                            $cause_rule->[Marpa::PP::Internal::Rule::ID];

                        my $cause_name =
                            "R$cause_rule_id:"
			    .  (scalar @{ $cause_rule->[Marpa::PP::Internal::Rule::RHS] })
			    . q{@}
                            . $cause->[Marpa::PP::Internal::Earley_Item::ORIGIN]
                            . q{-}
                            . $cause->[Marpa::PP::Internal::Earley_Item::SET];

                        FIND_CAUSE: {
                            my $cause_or_node =
                                $recce->[
                                Marpa::PP::Internal::Recognizer::OR_NODE_HASH]
                                ->{$cause_name};
                            if ($cause_or_node) {
                                $cause_id = $cause_or_node
                                    ->[Marpa::PP::Internal::Or_Node::ID];
                                last FIND_CAUSE;
                            } ## end if ($cause_or_node)

                            $cause_or_node = [];
                            $cause_or_node
                                ->[Marpa::PP::Internal::Or_Node::TAG] =
                                $cause_name;
                            $recce->[
                                Marpa::PP::Internal::Recognizer::OR_NODE_HASH]
                                ->{$cause_name} = $cause_or_node;
                            $cause_or_node
                                ->[Marpa::PP::Internal::Or_Node::RULE_ID] =
                                $cause_rule_id;

                            # nulling nodes are never part of cycles
                            # thanks to the CHAF rewrite
                            $cause_or_node
                                ->[Marpa::PP::Internal::Or_Node::CYCLE] =
                                $cause_rule
                                ->[Marpa::PP::Internal::Rule::VIRTUAL_CYCLE]
                                && $cause_earleme != $work_set;
                            $cause_or_node
                                ->[Marpa::PP::Internal::Or_Node::POSITION] =
                                scalar @{ $cause_rule
                                    ->[Marpa::PP::Internal::Rule::RHS] };
                            $cause_or_node ->[Marpa::PP::Internal::Or_Node::ITEM] =
                                    $cause;
                            $cause_id =
                                ( push @{$or_nodes}, $cause_or_node ) - 1;

                            Marpa::PP::exception(
                                "Too many or-nodes for evaluator: $cause_id")
                                if $cause_id
                                    & ~(Marpa::PP::Internal::N_FORMAT_MAX);
                            $cause_or_node->[Marpa::PP::Internal::Or_Node::ID]
                                = $cause_id;

                        } ## end FIND_CAUSE:

                        my $and_node = [];
                        #<<< cycles in perltidy as of 5 Jul 2010
                        $and_node
                            ->[Marpa::PP::Internal::And_Node::PREDECESSOR_ID
                            ] = $predecessor_id;
                        #>>>
                        $and_node
                            ->[Marpa::PP::Internal::And_Node::CAUSE_EARLEME] =
                            $cause_earleme;
                        $and_node->[Marpa::PP::Internal::And_Node::CAUSE_ID] =
                            $cause_id;

                        $and_node_data{
                            join q{:},
                            ( $predecessor_id // q{} ),
                            $cause_id
                            }
                            = $and_node;

                    } ## end for my $cause_rule ( @{ $state->[...]})

                    next LINK_WORK_ITEM;

                }    # if cause

                my $and_node = [];
                $and_node->[Marpa::PP::Internal::And_Node::PREDECESSOR_ID] =
                    $predecessor_id;
                $and_node->[Marpa::PP::Internal::And_Node::CAUSE_EARLEME] =
                    $cause_earleme;
                $and_node->[Marpa::PP::Internal::And_Node::TOKEN_NAME] =
                    $symbol_name;
                $and_node->[Marpa::PP::Internal::And_Node::VALUE_REF] =
                    $value_ref;

                $and_node_data{
                    join q{:}, ( $predecessor_id // q{} ),
                    q{}, $symbol_name
                    }
                    = $and_node;

            } ## end for my $link_work_item (@link_worklist)

            my @child_and_nodes =
                map { $and_node_data{$_} } sort keys %and_node_data;

            for my $and_node (@child_and_nodes) {

                $and_node->[Marpa::PP::Internal::And_Node::RULE_ID] =
                    $work_rule_id;

                $and_node->[Marpa::PP::Internal::And_Node::VALUE_OPS] =
                    $work_position
                    == $#{ $work_rule->[Marpa::PP::Internal::Rule::RHS] }
                    ? $evaluator_rules
                    ->[ $work_rule->[Marpa::PP::Internal::Rule::ID] ]
                    : undef;

                $and_node->[Marpa::PP::Internal::And_Node::POSITION] =
                    $work_position;
                $and_node->[Marpa::PP::Internal::And_Node::START_EARLEME] =
                    $work_node_origin;
                $and_node->[Marpa::PP::Internal::And_Node::END_EARLEME] =
                    $work_set;
                my $id = ( push @{$and_nodes}, $and_node ) - 1;
                Marpa::PP::exception("Too many and-nodes for evaluator: $id")
                    if $id & ~(Marpa::PP::Internal::N_FORMAT_MAX);
                $and_node->[Marpa::PP::Internal::And_Node::ID] = $id;
                $and_node->[Marpa::PP::Internal::And_Node::TAG] =
		    Marpa::PP::Recognizer::and_node_tag($recce, $and_node);

            } ## end for my $and_node (@child_and_nodes)

            # Populate the or-node, now that we have ID's for all the and-nodes
            $work_or_node->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS] =
                [ map { $_->[Marpa::PP::Internal::And_Node::ID] }
                    @child_and_nodes ];

            next TASK;
        } ## end if ( $task_type == ...)

        if ( $task_type == Marpa::PP::Internal::Task::STACK_INODE ) {

            my $work_iteration_node = $task_data[0];
            my $or_node             = $work_iteration_node
                ->[Marpa::PP::Internal::Iteration_Node::OR_NODE];

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH}
                    'Task: STACK_INODE o',
                    $or_node->[Marpa::PP::Internal::Or_Node::ID],
                    q{; }, ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_tasks)

            my $and_node_ids =
                $or_node->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS];

            # If the or-node is not populated,
            # restack this task, and stack a task to populate the
            # or-node on top of it.
            if ( not defined $and_node_ids ) {
                push @task_list, $task,
                    [ Marpa::PP::Internal::Task::POPULATE_OR_NODE, $or_node ];
                next TASK;
            }

            my $choices = $work_iteration_node
                ->[Marpa::PP::Internal::Iteration_Node::CHOICES];

            # At this point we know the iteration node is populated, so if we don't
            # have the choices list initialized, we can do so now.
            if ( not defined $choices ) {

                if ( $ranking_method eq 'constant' ) {
                    no integer;
                    my @choices = ();
                    AND_NODE: for my $and_node_id ( @{$and_node_ids} ) {
                        my $and_node   = $and_nodes->[$and_node_id];
                        my $new_choice = [];
                        $new_choice->[Marpa::PP::Internal::Choice::AND_NODE] =
                            $and_node;

                        #<<< cycles on perltidy 20090616
                        my $rank_ref = $and_node->[
                            Marpa::PP::Internal::And_Node::INITIAL_RANK_REF ];
                        #>>>
                        die "Undefined rank for a$and_node_id"
                            if not defined $rank_ref;
                        next AND_NODE if not ref $rank_ref;
                        $new_choice->[Marpa::PP::Internal::Choice::RANK] =
                            ${$rank_ref};
                        push @choices, $new_choice;
                    } ## end for my $and_node_id ( @{$and_node_ids} )
                    ## no critic (BuiltinFunctions::ProhibitReverseSortBlock)
                    $choices = [
                        sort {
                            $b->[Marpa::PP::Internal::Choice::RANK]
                                <=> $a->[Marpa::PP::Internal::Choice::RANK]
                            } @choices
                    ];
                } ## end if ( $ranking_method eq 'constant' )
                else {
                    $choices =
                        [ map { [ $and_nodes->[$_], 0 ] } @{$and_node_ids} ];
                }
                $work_iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::CHOICES] =
                    $choices;

            } ## end if ( not defined $choices )

            # Due to skipping, even an initialized set of choices
            # may be empty.  If it is, throw away the stack and iterate.
            if ( not scalar @{$choices} ) {

                @task_list = ( [Marpa::PP::Internal::Task::ITERATE] );
                next TASK;
            } ## end if ( not scalar @{$choices} )

            # Make our choice and set RANK
            my $choice = $choices->[0];

            # Rank is left until later to be initialized

            my $and_node = $choice->[Marpa::PP::Internal::Choice::AND_NODE];
            my $and_node_id = $and_node->[Marpa::PP::Internal::And_Node::ID];
            my $next_iteration_stack_ix = scalar @{$iteration_stack};

	    # Check if we are about to cycle.
	    if ( $and_node_in_use[$and_node_id] ) {

		# If there is another choice, increment choice and restack
		# this task ...
		#
		# This iteration node is not yet on the stack, so we
		# don't need to do anything with the pointers.
		if ( scalar @{$choices} > 1 ) {
		    shift @{$choices};
		    push @task_list, $task;
		    next TASK;
		}

		# Otherwise, throw away all pending tasks and
		# iterate
		@task_list = ( [Marpa::PP::Internal::Task::ITERATE] );
		next TASK;
	    } ## end if ( $and_node_in_use[$and_node_id] )
	    $and_node_in_use[$and_node_id] = 1;


            # Tell the parent that the new iteration node is its child.
            if (defined(
                    my $child_type =
                        $work_iteration_node
                        ->[Marpa::PP::Internal::Iteration_Node::CHILD_TYPE]
                )
                )
            {
                my $parent_ix = $work_iteration_node
                    ->[Marpa::PP::Internal::Iteration_Node::PARENT];
                $iteration_stack->[$parent_ix]->[
                    $child_type
                    == Marpa::PP::Internal::And_Node::PREDECESSOR_ID
                    ? Marpa::PP::Internal::Iteration_Node::PREDECESSOR_IX
                    : Marpa::PP::Internal::Iteration_Node::CAUSE_IX
                    ]
                    = scalar @{$iteration_stack};
            } ## end if ( defined( my $child_type = $work_iteration_node->...))

            # If we are keeping an iteration node worklist,
            # add this node to it.
            defined $iteration_node_worklist
                and push @{$iteration_node_worklist},
                scalar @{$iteration_stack};

            push @{$iteration_stack}, $work_iteration_node;

            next TASK;

        } ## end if ( $task_type == Marpa::PP::Internal::Task::STACK_INODE)

        if ( $task_type == Marpa::PP::Internal::Task::RANK_ALL ) {

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH} 'Task: RANK_ALL; ',
                    ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            }

            do_rank_all($recce);

            next TASK;
        } ## end if ( $task_type == Marpa::PP::Internal::Task::RANK_ALL)

        # This task is for pre-populating the entire and-node and or-node
        # space one "depth level" at a time.  It is used when ranking is
        # being done, because to rank you need to make a pre-pass through
        # the entire and-node and or-node space.
        #
        # As a side effect, depths are calculated for all the and-nodes.
        if ( $task_type == Marpa::PP::Internal::Task::POPULATE_DEPTH ) {
            my ( $depth, $or_node_list ) = @task_data;

            if ($trace_tasks) {
                print {$Marpa::PP::Internal::TRACE_FH}
                    'Task: POPULATE_DEPTH; ',
                    ( scalar @task_list ), " tasks pending\n"
                    or Marpa::PP::exception('print to trace handle failed');
            } ## end if ($trace_tasks)

            # We can assume all or-nodes in the list are populated

            my %or_nodes_at_next_depth = ();

            # Assign a depth to all the and-node children which
            # do not already have one assigned.
            for my $and_node_id (
                map { @{ $_->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS] } }
                @{$or_node_list} )
            {
                my $and_node = $and_nodes->[$and_node_id];
                FIELD:
                for my $field (
                    Marpa::PP::Internal::And_Node::PREDECESSOR_ID,
                    Marpa::PP::Internal::And_Node::CAUSE_ID
                    )
                {
                    my $child_or_node_id = $and_node->[$field];
                    next FIELD if not defined $child_or_node_id;

                    my $next_depth_or_node = $or_nodes->[$child_or_node_id];

                    # Push onto list only if child or-node
                    # is not already populated
                    $next_depth_or_node
                        ->[Marpa::PP::Internal::Or_Node::AND_NODE_IDS]
                        or $or_nodes_at_next_depth{$next_depth_or_node} =
                        $next_depth_or_node;

                } ## end for my $field ( ...)

            } ## end for my $and_node_id ( map { @{ $_->[...]}})

            # No or-nodes at next depth?
            # Great, we are done!
            my @or_nodes_at_next_depth =
                map { $or_nodes_at_next_depth{$_} }
                sort keys %or_nodes_at_next_depth;
            next TASK if not scalar @or_nodes_at_next_depth;

            push @task_list,
                [
                Marpa::PP::Internal::Task::POPULATE_DEPTH, $depth + 1,
                \@or_nodes_at_next_depth
                ],
                map { [ Marpa::PP::Internal::Task::POPULATE_OR_NODE, $_ ] }
                @or_nodes_at_next_depth;

            next TASK;

        } ## end if ( $task_type == Marpa::PP::Internal::Task::POPULATE_DEPTH)

        Marpa::PP::internal_error(
            "Internal error: Unknown task type: $task_type");

    } ## end while ( my $task = pop @task_list )

    my @stack = map {
        $_->[Marpa::PP::Internal::Iteration_Node::CHOICES]->[0]
            ->[Marpa::PP::Internal::Choice::AND_NODE]
    } @{$iteration_stack};

    return Marpa::PP::Internal::Recognizer::evaluate( $recce, \@stack );

} ## end sub Marpa::PP::Recognizer::value

1;
