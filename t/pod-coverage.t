use strict;
use warnings;

use Test::More;

plan skip_all => 'This test is only run for the module author'
    unless -d '.svn' || $ENV{IS_MAINTAINER};

eval 'use Test::Pod::Coverage 1.04; use Pod::Coverage::Moose;';
plan skip_all => 'Test::Pod::Coverage 1.04 and Pod::Coverage::Moose required for testing POD coverage'
    if $@;


my %Exclude =
    map { $_ => 1 } qw( Fey::Hash::ColumnsKey Fey::Meta::Method::Constructor );

my @mods = grep { ! $Exclude{$_} } Test::Pod::Coverage::all_modules();

plan tests => scalar @mods;


my %Trustme = ( 'Fey::ORM::Schema' => qr/^init_meta$/,
                'Fey::ORM::Table'  => qr/^init_meta$/,
              );

for my $mod (@mods)
{
    my @trustme = qr/^BUILD$/;
    push @trustme, $Trustme{$mod} if $Trustme{$mod};

    pod_coverage_ok( $mod, { coverage_class => 'Pod::Coverage::Moose',
                             trustme => \@trustme,
                           },
                     "pod coverage for $mod" );
}
