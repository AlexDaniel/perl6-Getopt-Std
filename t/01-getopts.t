#!/usr/bin/env perl6

use v6.c;

use Test;

use Getopt::Std :DEFAULT, :util;

my Str:D %base-opts = :foo('bar'), :baz('quux'), :h(''), :something('15'), :O('-3.5');
my Str:D @base-args = <-v -I tina -vOverbose something -o something -- else -h>;
my $base-optstr = 'I:O:o:v';
my Str:D %empty_hash;

class TestCase
{
	has Str:D $.name is required;
	has Str:D $.optstring = $base-optstr;
	has @.args = @base-args;
	has Str:D %.opts = %base-opts;
	has Bool:D $.res = True;
	has @.res-args is required;
	has %.res-opts is required;
}

sub check-deeply-relaxed($got, $expected) returns Bool:D
{
	given $expected {
		when Associative {
			return False unless $got ~~ Associative;
			return False if Set.new($got.keys) ⊖ Set.new($expected.keys);
			return ?( $got.keys.map(
			    { check-deeply-relaxed($got{$_}, $expected{$_}) }
			    ).all);
		}
		
		when Positional {
			return False unless $got ~~ Positional;
			return False unless $got.elems == $expected.elems;
			return ?( ($got.list Z $expected.list).map(-> ($g, $e)
			    { check-deeply-relaxed($g, $e) }
			    ).all);
			return True;
		}
		
		when Str {
			return $got eq $expected;
		}
		
		when Numeric {
			return $got == $expected;
		}
		
		default {
			return False;
		}
	}
}

sub test-deeply-relaxed($got, $expected) returns Bool:D
{
	return True if check-deeply-relaxed($got, $expected);
	diag "Expected:\n\t$expected.perl()\nGot:\n\t$got.perl()\n";
	return False;
}

sub test-getopts(TestCase:D $t)
{
	my Bool:D %defs = getopts-parse-optstring($t.optstring);

	for (False, True) -> $all {
		my Str:D $test = "$t.name() [all: $all]";
		my Str:D @test-args = $t.args;
		my %test-opts = $t.opts;
		my Bool:D $result = getopts($t.optstring, %test-opts, @test-args, :$all);
		is $result, $t.res, "$test: returned result";

		my %exp-opts = $t.res-opts;
		getopts-collapse-array(%defs, %exp-opts) unless $all;
		ok test-deeply-relaxed(%test-opts, %exp-opts), "$test: stores the expected options";
		ok test-deeply-relaxed(@test-args, $t.res-args), "$test: leaves the expected arguments";
	}
}

my @tests = (
	TestCase.new(
		:name('empty string'),
		:optstring(''),
		:!res,
		:res-args(@base-args),
		:res-opts(%base-opts),
	),
	TestCase.new(
		:name('no command-line arguments'),
		:args(()),
		:res-args(()),
		:res-opts({}),
	),
	TestCase.new(
		:name('no options specified'),
		:args(<no options specified>),
		:res-args(<no options specified>),
		:res-opts({}),
	),
	TestCase.new(
		:name('early --'),
		:args(<-- -v -I -i -O -o>),
		:res-args(<-v -I -i -O -o>),
		:res-opts({}),
	),
	TestCase.new(
		:name('single flag'),
		:args(<-v out>),
		:res-args([<out>]),
		:res-opts({:v('v')}),
	),
	TestCase.new(
		:name('repeated flag'),
		:args(<-vv out>),
		:res-args([<out>]),
		:res-opts({:v([<v v>])}),
	),
	TestCase.new(
		:name('another repeated flag'),
		:args(<-v -v out>),
		:res-args([<out>]),
		:res-opts({:v([<v v>])}),
	),
	TestCase.new(
		:name('glued argument'),
		:args(<-Ifoo bar>),
		:res-args([<bar>]),
		:res-opts({:I('foo')}),
	),
	TestCase.new(
		:name('separate argument'),
		:args(<-I foo bar>),
		:res-args([<bar>]),
		:res-opts({:I('foo')}),
	),
	TestCase.new(
		:name('glued argument and an option'),
		:args(<-vIfoo bar>),
		:res-args([<bar>]),
		:res-opts({:I('foo'), :v('v')}),
	),
	TestCase.new(
		:name('separate argument and an option'),
		:args(<-vI foo bar>),
		:res-args([<bar>]),
		:res-opts({:I('foo'), :v('v')}),
	),
	TestCase.new(
		:name('repeated argument 1'),
		:args(<-Ifoo -Ibar baz>),
		:res-args([<baz>]),
		:res-opts({:I[<foo bar>]}),
	),
	TestCase.new(
		:name('repeated argument 2'),
		:args(<-Ifoo -I bar baz>),
		:res-args([<baz>]),
		:res-opts({:I[<foo bar>]}),
	),
	TestCase.new(
		:name('repeated argument 3'),
		:args(<-I foo -Ibar baz>),
		:res-args([<baz>]),
		:res-opts({:I[<foo bar>]}),
	),
	TestCase.new(
		:name('repeated argument 4'),
		:args(<-I foo -I bar baz>),
		:res-args([<baz>]),
		:res-opts({:I[<foo bar>]}),
	),
	TestCase.new(
		:name('complicated example'),
		:res-args(<something -o something -- else -h>),
		:res-opts({:I('tina'), :O('verbose'), :v([<v v>])}),
	),
	TestCase.new(
		:name('unrecognized option'),
		:args([<-X>]),
		:!res,
		:res-args(()),
		:res-opts({}),
	),
	TestCase.new(
		:name('unrecognized option glued to a good one'),
		:args([<-vX>]),
		:!res,
		:res-args(()),
		:res-opts({:v('v')}),
	),
	TestCase.new(
		:name('unrecognized option after a good one'),
		:args([<-v -X>]),
		:!res,
		:res-args(()),
		:res-opts({:v('v')}),
	),
	TestCase.new(
		:name('-X as an option argument'),
		:args([<-I -X>]),
		:res-args(()),
		:res-opts({:I('-X')}),
	),
	TestCase.new(
		:name('-X after --'),
		:args(<-v -- -X>),
		:res-opts({:v('v')}),
		:res-args([<-X>]),
	),
	TestCase.new(
		:name('-X after a non-option argument'),
		:args(<-v nah -X>),
		:res-opts({:v('v')}),
		:res-args(<nah -X>),
	),
	TestCase.new(
		:name('a dash after the options'),
		:args(<-v - foo>),
		:res-args(<- foo>),
		:res-opts({:v('v')}),
	),
);

plan 3 * 2 * @tests.elems;
test-getopts($_) for @tests;
