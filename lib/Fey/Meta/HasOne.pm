package Fey::Meta::HasOne;

use strict;
use warnings;

use Fey::Exceptions qw( param_error );

use Moose;
use MooseX::StrictConstructor;

extends 'Fey::Meta::FK';


has associated_attribute =>
    ( is         => 'rw',
      isa        => 'Maybe[Moose::Meta::Attribute]',
      writer     => '_set_associated_attribute',
      init_arg   => undef,
      lazy_build => 1,
    );

has associated_method =>
    ( is         => 'rw',
      isa        => 'Maybe[Moose::Meta::Method]',
      writer     => '_set_associated_method',
      init_arg   => undef,
      lazy_build => 1,
    );

has handles =>
    ( is  => 'ro',
      # just gets passed on for attribute creation
      isa => 'Any',
    );

has allows_undef =>
    ( is         => 'ro',
      isa        => 'Bool',
      lazy_build => 1,
    );


sub _build_name
{
    my $self = shift;

    return lc $self->foreign_table()->name();
}

sub _build_associated_attribute
{
    my $self = shift;

    return unless $self->is_cached();

    # It'd be nice to set isa to the actual foreign class, but we may
    # not be able to map a table to a class yet, since that depends on
    # the related class being loaded. It doesn't really matter, since
    # this accessor is read-only, so there's really no typing issue to
    # deal with.
    my $type = 'Fey::Object::Table';
    $type = "Maybe[$type]" if $self->allows_undef();

    my %attr_p =
        ( is        => 'rw',
          isa       => $type,
          lazy      => 1,
          default   => $self->_make_subref(),
          writer    => q{_set_} . $self->name(),
          predicate => q{_has_} . $self->name(),
          clearer   => q{_clear_} . $self->name(),
        );

    $attr_p{handles} = $self->handles()
        if $self->handles();

    return
        $self->associated_class()->attribute_metaclass()
             ->new( $self->name(),
                    %attr_p,
                  );
}

sub _build_is_cached { 1 }

sub _build_associated_method
{
    my $self = shift;

    return if $self->is_cached();

    return
        $self->associated_class()->method_metaclass()
             ->wrap( name         => $self->name(),
                     package_name => $self->associated_class()->name(),
                     body         => $self->_make_subref(),
                   );
}

sub attach_to_class
{
    my $self  = shift;
    my $class = shift;

    $self->_set_associated_class($class);

    if ( $self->is_cached() )
    {
        $class->add_attribute( $self->associated_attribute() );
    }
    else
    {
        $class->add_method( $self->name() => $self->associated_method() );
    }
}

sub detach_from_class
{
    my $self  = shift;

    return unless $self->associated_class();

    if ( $self->is_cached() )
    {
        $self->associated_class->remove_attribute( $self->name() );
    }
    else
    {
        $self->associated_class->remove_method( $self->name() );
    }

    $self->_clear_associated_class();
}


no Moose;

__PACKAGE__->meta()->make_immutable();

1;
