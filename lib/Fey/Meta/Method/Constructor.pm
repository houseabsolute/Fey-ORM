package Fey::Meta::Method::Constructor;

use strict;
use warnings;

use Moose;

extends 'MooseX::StrictConstructor::Meta::Method::Constructor';

# XXX - This is copied straight from Moose 0.36 because there's no
# good way to override it (note the eval it does at the end).
sub intialize_body {
    my $self = shift;
    # TODO:
    # the %options should also include a both
    # a call 'initializer' and call 'SUPER::'
    # options, which should cover approx 90%
    # of the possible use cases (even if it
    # requires some adaption on the part of
    # the author, after all, nothing is free)
    my $source = 'sub {';
    $source .= "\n" . 'my $class = shift;';

    # XXX - override
    $source .= "\n" . 'my $meta = $class->meta();';

    $source .= "\n" . 'return $class->Moose::Object::new(@_)';
    $source .= "\n" . '    if $class ne \'' . $self->associated_metaclass->name . '\';';

    $source .= "\n" . 'my %params = (scalar @_ == 1) ? %{$_[0]} : @_;';

    # XXX - override
    $source .= "\n" . $self->_search_cache();

    # XXX - override
    $source .= "\n" . 'my $instance;';

    # XXX - override
    $source .= "\n" . 'eval {';

    # XXX - override
    $source .= "\n" . '$instance = ' . $self->meta_instance->inline_create_instance('$class');

    $source .= ";\n" . (join ";\n" => map {
        $self->_generate_slot_initializer($_)
    } 0 .. (@{$self->attributes} - 1));

    $source .= ";\n" . $self->_generate_BUILDALL();

    # XXX - override
    $source .= ";\n" . '};';

    # XXX - override
    $source .= "\n" . 'if ( my $e = $@ ) {';
    $source .= "\n" . '    return if blessed $e && $e->isa(q{Fey::Exception::NoSuchRow});';
    $source .= "\n" . '    die $e;';
    $source .= "\n" . '}';

    # XXX - override
    $source .= "\n" . $self->_write_to_cache();

    $source .= "\n" . 'return $instance;';
    $source .= "\n" . '}';

    # XXX - override
    $source .= "\n";

    warn $source if $self->options->{debug};

    my $code;
    {
        # NOTE:
        # create the nessecary lexicals
        # to be picked up in the eval
        my $attrs = $self->attributes;

        # We need to check if the attribute ->can('type_constraint')
        # since we may be trying to immutabilize a Moose meta class,
        # which in turn has attributes which are Class::MOP::Attribute
        # objects, rather than Moose::Meta::Attribute. And 
        # Class::MOP::Attribute attributes have no type constraints.
        # However we need to make sure we leave an undef value there
        # because the inlined code is using the index of the attributes
        # to determine where to find the type constraint

        my @type_constraints = map {
            $_->can('type_constraint') ? $_->type_constraint : undef
        } @$attrs;

        my @type_constraint_bodies = map {
            defined $_ ? $_->_compiled_type_constraint : undef;
        } @type_constraints;

        $code = eval $source;
        confess "Could not eval the constructor :\n\n$source\n\nbecause :\n\n$@" if $@;
    }
    $self->{'&!body'} = $code;
}

sub _search_cache
{
    my $self = shift;

    my $source = "\n" . 'if ( $meta->_object_cache_is_enabled() ) {';
    $source .= "\n" . '    my $instance = $meta->_search_cache(\\%params);';
    $source .= "\n" . '    return $instance if $instance;';
    $source .= "\n" . '}';
}

sub _write_to_cache
{
    my $self = shift;

    return "\n" . '$meta->_write_to_cache($instance) if $meta->_object_cache_is_enabled();';
}

no Moose;

1;

