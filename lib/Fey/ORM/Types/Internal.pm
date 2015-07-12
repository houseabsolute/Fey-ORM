package Fey::ORM::Types::Internal;

use strict;
use warnings;

our $VERSION = '0.47';

use MooseX::Types -declare => [
    qw(
        ArrayRefOfClasses
        ClassDoesIterator
        DoesHasMany
        DoesHasOne
        IterableArrayRef
        TableWithSchema
        )
];

use MooseX::Types::Moose
    qw( ArrayRef ClassName Object Undef );

role_type DoesHasMany, { role => 'Fey::Meta::Role::Relationship::HasMany' };
role_type DoesHasOne, { role => 'Fey::Meta::Role::Relationship::HasOne' };

#<<<
subtype TableWithSchema,
    as class_type('Fey::Table'),
    where { $_[0]->has_schema() },
    message {
        'A table used for has-one or -many relationships must have a schema'
    };

subtype ClassDoesIterator,
    as ClassName,
    where { $_[0]->meta()->does_role('Fey::ORM::Role::Iterator') },
    message {"$_[0] does not do the Fey::ORM::Role::Iterator role"};

subtype ArrayRefOfClasses,
    as ArrayRef[ClassName],
    where { @{$_} > 0 };

coerce ArrayRefOfClasses,
    from ClassName,
    via { return [$_] };


subtype IterableArrayRef,
    as ArrayRef[ArrayRef[Object|Undef]],
    message {
        'You must provide an array reference of which each '
            . ' element is in turn an array reference. The inner '
            . ' references should contain objects or undef.';
    };

coerce IterableArrayRef,
    from ArrayRef[Object|Undef],
    via {
        [ map { [$_] } @{$_} ];
    };
#>>>

1;

# ABSTRACT: Types for use in Fey::ORM

__END__

=head1 DESCRIPTION

This module defines a whole bunch of types used by the Fey::ORM core
classes. None of these types are documented for external use at the present,
though that could change in the future.

=head1 BUGS

See L<Fey::ORM> for details on how to report bugs.

=cut
