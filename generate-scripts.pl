#!/usr/bin/env perl
# http://blogs.perl.org/users/michael_g_schwern/2011/03/and-the-fastest-oo-accessor-is.html

use strict;
use warnings;
use FindBin;
use IO::File ();
use File::Basename qw(basename);

chdir $FindBin::Bin;

our @scripts;
sub script {
  my ($name, $load, $inst, $act) = @_;

  push @scripts, [$name => join("\n",
    <<'PREFIX',
our $x = 400_000;
our ($t, $mu, @sizes);
BEGIN {
  # most programs would include much of the following anyway (and lots more)
  # so we won't worry about the minor resources they add to the program
  use strict;
  use warnings;
  use Time::HiRes qw(gettimeofday tv_interval);
  use Devel::Size qw(total_size);
  use Memory::Usage;
  $mu = Memory::Usage->new;
  sub main::rec {
    my $n = shift;
    $mu->record($n);
    push(@sizes, [$n => total_size($_[0])])
      if @_;
  };
  $mu->record('begin');
  $t = [gettimeofday];
}
PREFIX
    qq{print qq[## $name\\n];},

    ($load ? "{$load}" : ()),
    qq#BEGIN { rec 'loaded'; }#,
    qq#my \$object = $inst#,
    qq#my \$arg = 32; \$arg =~ m/./;#,

    q#rec built => $object;#,
    qq#sub act {
      $act
    }
    act();
    #,
    q#rec called => $object;#,

    q#my @objects = map {#,
    '  ' . $inst,
    q#} 1 .. $x;#,

    q#
rec "$x  built" => \@objects;

for ( @objects ) {
  $object = $_;
  act();
}

rec "$x called" => \@objects;
$t = tv_interval($t, [gettimeofday]);
$mu->record('end');
print $mu->report;
print join(';', sprintf('object size: %15s: %12.4f k (%12d)', $_->[0], $_->[1]/1024, $_->[1])), "\n" for @sizes;
print "took: $t\n";
#
  )];
}

# ...........hash...............
script hash =>
  '', # nothing to load
  '+{};',
  q#
    $object->{bar} = $arg;
    my $x = $object->{bar};
  #;

# ...........hash with check...............
script hash_check =>
  'use Carp',
  '+{};',
  q#
    croak "we take an integer"
      unless defined $arg and $arg =~ /^[+-]?\d+$/;
    $object->{bar} = $arg;
    my $x = $object->{bar};
  #;

# ...........by hand..............
script manual =>
  q#
    package Foo::Manual::NoChecks;
    sub new { bless {} => shift }
    sub bar {
        my $self = shift;
        return $self->{bar} unless @_;
        $self->{bar} = shift;
    }
  #,
  'Foo::Manual::NoChecks->new;',
  q#
    $object->bar($arg);
    my $x = $object->bar;
  #;

# ...........by hand with checks..............
script manual_check =>
  q!
    package Foo::Manual;
    use Carp;

    sub new { bless {} => shift }
    sub bar {
        my $self = shift;
        if( @_ ) {
            # Simulate argument checking
            my $arg = shift;
            croak "we take an integer"
              unless defined $arg and $arg =~ /^[+-]?\d+$/;
            $self->{bar} = $arg;
        }
        return $self->{bar};
    }
  !,
  'Foo::Manual->new;',
  q{
    $object->bar($arg);
    my $x = $object->bar;
  };


#.............Mouse.............
{
  my @mouse = (
  q#
    package Foo::Mouse;
    use Mouse;
    has bar => (is => 'rw', isa => "Int");
    __PACKAGE__->meta->make_immutable;
  #,
  'Foo::Mouse->new;',
  q{
    $object->bar($arg);
    my $x = $object->bar;
  });

  script Mouse => @mouse;

  $mouse[0] = 'BEGIN { $ENV{MOUSE_PUREPERL} = 1; }' . $mouse[0];
  script MousePP => @mouse;
}

script Moose =>
  q#
    package Foo::Moose;
    use Moose;
    has bar => (is => 'rw', isa => "Int");
    __PACKAGE__->meta->make_immutable;
  #,
  'Foo::Moose->new;',
  q{
    $object->bar($arg);
    my $x = $object->bar;
  };


#.............Moo...........
script Moo =>
  q#
    package Foo::Moo;
    use Moo;
    has bar => (is => 'rw', isa => sub { $_[0] =~ /^[+-]?\d+$/ });
  #,
  'Foo::Moo->new;',
  q{
    $object->bar($arg);
    my $x = $object->bar;
  };


#........... Moo using Sub::Quote..............
script 'Moo w/ Sub::Quote' =>
  q#
    package Foo::Moo::QS;
    use Moo;
    use Sub::Quote;
    has bar => (is => 'rw', isa => quote_sub q{ $_[0] =~ /^[+-]?\d+$/ });
  #,
  'Foo::Moo::QS->new;',
  q{
    $object->bar($arg);
    my $x = $object->bar;
  };

#............Object::Tiny..............
script 'Object::Tiny' =>
  q#
    package Foo::Object::Tiny;
    use Object::Tiny qw(bar);
  #,
  'Foo::Object::Tiny->new( bar => $arg );',
  q{
    my $x = $object->bar;
  };

#............Object::Tiny::XS..............
script 'Object::Tiny::XS' =>
  q#
    package Foo::Object::Tiny::XS;
    use Object::Tiny::XS qw(bar);
  #,
  'Foo::Object::Tiny::XS->new(bar => $arg);',
  q{
    my $x = $object->bar;
  };

#......................................end

require "$_.pm" for qw(Moose Mouse Moo);
print "Testing Perl $], Moose $Moose::VERSION, Mouse $Mouse::VERSION, Moo $Moo::VERSION\n";

=pod
        Moose                   => \&moose,
        Mouse                   => \&mouse,
        manual                  => \&manual,
        "manual, no check"      => \&manual_nc,
        'hash, no check'        => \&hash_nc,
        hash                    => \&hash,
        Moo                     => \&moo,
        "Moo w/quote_sub"       => \&mooqs,
        "Object::Tiny"          => \&ot,
        "Object::Tiny::XS"      => \&otxs,
=cut

foreach my $i ( 0 .. $#scripts ){
  my ($name, $code) = @{ $scripts[$i] };
  print $code;
}
