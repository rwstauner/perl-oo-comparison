#!/usr/bin/env perl
# http://blogs.perl.org/users/michael_g_schwern/2011/03/and-the-fastest-oo-accessor-is.html

use strict;
use warnings;

use Carp;

BEGIN {
     # uncomment to test pure Perl Mouse
#    $ENV{MOUSE_PUREPERL} = 1;
}

# ...........hash...............

my $hash = {};
sub hash_nc {
    $hash->{bar} = 32;
    my $x = $hash->{bar};
}


# ...........hash with check...............

my $hash_check = {};
sub hash {
    my $arg = 32;
    croak "we take an integer" unless defined $arg and $arg =~ /^[+-]?\d+$/;
    $hash_check->{bar} = $arg;
    my $x = $hash_check->{bar};
}


# ...........by hand..............
{
    package Foo::Manual::NoChecks;
    sub new { bless {} => shift }
    sub bar {
        my $self = shift;
        return $self->{bar} unless @_;
        $self->{bar} = shift;
    }
}
my $manual_nc = Foo::Manual::NoChecks->new;
sub manual_nc {
    $manual_nc->bar(32);
    my $x = $manual_nc->bar;
}


# ...........by hand with checks..............
{
    package Foo::Manual;
    use Carp;

    sub new { bless {} => shift }
    sub bar {
        my $self = shift;
        if( @_ ) {
            # Simulate argument checking
            my $arg = shift;
            croak "we take an integer" unless defined $arg and $arg =~ /^[+-]?\d+$/;
            $self->{bar} = $arg;
        }
        return $self->{bar};
    }
}
my $manual = Foo::Manual->new;
sub manual {
    $manual->bar(32);
    my $x = $manual->bar;
}


#.............Mouse.............
{
    package Foo::Mouse;
    use Mouse;
    has bar => (is => 'rw', isa => "Int");
    __PACKAGE__->meta->make_immutable;
}
my $mouse = Foo::Mouse->new;
sub mouse {
    $mouse->bar(32);
    my $x = $mouse->bar;
}


#............Moose............
{
    package Foo::Moose;
    use Moose;
    has bar => (is => 'rw', isa => "Int");
    __PACKAGE__->meta->make_immutable;
}
my $moose = Foo::Moose->new;
sub moose {
    $moose->bar(32);
    my $x = $moose->bar;
}


#.............Moo...........
{
    package Foo::Moo;
    use Moo;
    has bar => (is => 'rw', isa => sub { $_[0] =~ /^[+-]?\d+$/ });
}
my $moo = Foo::Moo->new;
sub moo {
    $moo->bar(32);
    my $x = $moo->bar;
}


#........... Moo using Sub::Quote..............
{
    package Foo::Moo::QS;
    use Moo;
    use Sub::Quote;
    has bar => (is => 'rw', isa => quote_sub q{ $_[0] =~ /^[+-]?\d+$/ });
}
my $mooqs = Foo::Moo::QS->new;
sub mooqs {
    $mooqs->bar(32);
    my $x = $mooqs->bar;
}


#............Object::Tiny..............
{
    package Foo::Object::Tiny;
    use Object::Tiny qw(bar);
}
my $ot = Foo::Object::Tiny->new( bar => 32 );
sub ot {
    my $x = $ot->bar;
}


#............Object::Tiny::XS..............
{
    package Foo::Object::Tiny::XS;
    use Object::Tiny::XS qw(bar);
}
my $otxs = Foo::Object::Tiny::XS->new(bar => 32);
sub otxs {
    my $x = $otxs->bar;
}


use Benchmark 'timethese';

print "Testing Perl $], Moose $Moose::VERSION, Mouse $Mouse::VERSION, Moo $Moo::VERSION\n";
timethese(
    6_000_000,
    {
#        Moose                   => \&moose,
        Mouse                   => \&mouse,
        manual                  => \&manual,
        "manual, no check"      => \&manual_nc,
        'hash, no check'        => \&hash_nc,
        hash                    => \&hash,
#        Moo                     => \&moo,
#        "Moo w/quote_sub"       => \&mooqs,
        "Object::Tiny"          => \&ot,
        "Object::Tiny::XS"      => \&otxs,
    }
);


__END__
Testing Perl 5.012002, Moose 1.24, Mouse 0.91, Moo 0.009007, Object::Tiny 1.08, Object::Tiny::XS 1.01
Benchmark: timing 6000000 iterations of Moo, Moo w/quote_sub, Moose, Mouse, Object::Tiny, Object::Tiny::XS, hash, manual, manual with no checks...
Object::Tiny::XS:  1 secs ( 1.20 usr + -0.01 sys =  1.19 CPU) @ 5042016.81/s
hash, no check  :  3 secs ( 1.86 usr +  0.01 sys =  1.87 CPU) @ 3208556.15/s
Mouse           :  3 secs ( 3.66 usr +  0.00 sys =  3.66 CPU) @ 1639344.26/s
Object::Tiny    :  3 secs ( 3.80 usr +  0.00 sys =  3.80 CPU) @ 1578947.37/s
hash            :  5 secs ( 5.53 usr +  0.01 sys =  5.54 CPU) @ 1083032.49/s
manual, no check:  9 secs ( 9.11 usr +  0.02 sys =  9.13 CPU) @  657174.15/s
Moo             : 17 secs (17.37 usr +  0.03 sys = 17.40 CPU) @  344827.59/s
manual          : 17 secs (17.89 usr +  0.02 sys = 17.91 CPU) @  335008.38/s
Mouse no XS     : 20 secs (20.50 usr +  0.03 sys = 20.53 CPU) @  292255.24/s
Moose           : 21 secs (21.33 usr +  0.03 sys = 21.36 CPU) @  280898.88/s
Moo w/quote_sub : 23 secs (23.07 usr +  0.04 sys = 23.11 CPU) @  259627.87/s
__CSV__
,Name,get/set per sec,% diff from manual,get per sec,% diff from manual,set per sec,% diff from manual,notes,,,,,,,,
,Moo,"344,827",2.93%,"1,153,400",-11.53%,"603,015",-4.62%,,,,,,,,,
,manual,"335,008",0.00%,"1,303,700",0.00%,"632,244",0.00%,,,,,,,,,
,Mouse no XS,"292,255",-12.76%,"1,305,400",0.13%,"417,536",-33.96%,,,,,,,,,
,"manual, no check","657,174",96.17%,"1,307,100",0.26%,"1,604,278",153.74%,no check,,,,,,,,
,Moo w/quote_sub,"259,627",-22.50%,"1,379,300",5.80%,"338,409",-46.47%,,,,,,,,,
,Moose,"280,898",-16.15%,"1,408,400",8.03%,"376,884",-40.39%,,,,,,,,,
,Object::Tiny,"1,578,947",371.32%,"1,567,300",20.22%,n/a,n/a,"no check, read only",,,,,,,,
,Mouse,"1,639,344",389.34%,"3,194,800",145.06%,"3,592,814",468.26%,,,,,,,,,
,Object::Tiny::XS,"5,042,016","1,405.04%","4,255,300",226.40%,n/a,n/a,"no check, read only",,,,,,,,
,"hash, no check","3,208,556",857.76%,"4,950,400",279.72%,"7,692,307","1,116.67%",no check,,,,,,,,
,hash,"1,083,032",223.29%,"5,076,100",289.36%,"1,566,579",147.78%,,,,,,,,,
