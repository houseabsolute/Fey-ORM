package Fey::Class::Accessor;

use strict;
use warnings;

sub import
{
    my $caller = (caller(1))[0];

    _make_accessor( $caller, $_ ) for @_;
}

sub _make_accessor
{
    my $declarer = shift;
    my $field    = shift;

    my $data;

    my $set_meth;
    if ( $field =~ /^_/ )
    {
        ( my $copy = $field ) =~ s/^_//;

        $set_meth = '_Set' . $copy;
    }
    else
    {
        $set_meth = 'Set' . $field;
    }

    my $set =
        sub { my $class = ref $_[0] || $_[0];

              if ( $class ne $declarer )
              {
                  Fey::Class::Accessor::_make_accessor( $class, $field );

                  return $class->$set_meth(@_);
              }

              $data = $_[1];
            };

    my $get = { return $data };

    no warnings 'redefine';

    *{$declarer . '::' . $set_meth} = $set;
    *{$declarer . '::' . $field}    = $get;
}


1;

__END__
