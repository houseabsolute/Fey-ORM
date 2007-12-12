package Fey::Class;

use strict;
use warnings;

our @EXPORT = qw( has_table transform inflate deflate ); ## no critic ProhibitAutomaticExportation
use base 'Exporter';

use Fey::Class::Object;
use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate_pos TABLE_TYPE );
use Moose ();
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;


# This re-exporting is a mess. Once MooseX::Exporter is done,
# hopefully it can replace all of this.
sub import
{
    my $caller = Moose::_get_caller();

    return if $caller eq 'main';

    Moose::init_meta( $caller,
                      'Fey::Class::Object',
                      'MooseX::StrictConstructor::Meta::Class',
                    );

    Moose->import( { into => $caller } );

    __PACKAGE__->export_to_level( 1, @_ );

    return;
}

sub unimport ## no critic RequireFinalReturn
{
    my $caller = caller();

    no strict 'refs'; ## no critic ProhibitNoStrict
    foreach my $name (@EXPORT)
    {
        if ( defined &{ $caller . '::' . $name } )
        {
            my $keyword = \&{ $caller . '::' . $name };

            my $pkg_name =
                eval { svref_2object($keyword)->GV()->STASH()->NAME() };

            next if $@;
            next if $pkg_name ne __PACKAGE__;

            delete ${ $caller . '::' }{$name};
        }
    }

    Moose::unimport( { into_level => 1 } );
}

{
    my $spec = ( TABLE_TYPE );
    sub has_table
    {
        my ($table) = validate_pos( @_, $spec );

        param_error 'A table object passed to has_table() must have a schema'
            unless $table->has_schema();

        my $caller = caller();

        _make_table_attribute( $caller, $table );
        _make_column_attributes( $caller, $table );
    }
}

sub _make_table_attribute
{
    my $caller = shift;
    my $table  = shift;

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          'Table' =>
          ( is     => 'ro',
            isa    => 'Fey::Table',
            writer => '_SetTable',
          )
        );

    $caller->_SetTable($table);
}

sub _make_column_attributes
{
    my $caller = shift;
    my $table  = shift;

    my $meta = $caller->meta();

    for my $column ( $table->columns() )
    {
        my $name = $column->name();

        next if $meta->has_method($name);

        $meta->_process_attribute
            ( $name,
              is      => 'ro',
              isa     => _type_for_column( $caller, $column ),
              lazy    => 1,
              default => sub { $_[0]->_get_column_value($name) },
            );
    }
}

# XXX - can this be overridden or customized? should it account for
# per-column/policy-level transforms?
{
    my %FeyToMoose = ( text     => 'Str',
                       blob     => 'Str',
                       integer  => 'Int',
                       float    => 'Num',
                       datetime => 'Str',
                       date     => 'Str',
                       time     => 'Str',
                       boolean  => 'Bool',
                       other    => 'Value',
                     );

    sub _type_for_column
    {
        my $caller = shift;
        my $column = shift;

        my $type = $FeyToMoose{ $column->generic_type() };

        $type .= q{ | Undef}
            if $column->is_nullable();

        return $type;
    }
}

sub transform
{
    my @p;

    push @p, pop @_ while ref $_[-1];

    my %p = _combine_hashes(@p);

    my $caller = caller();

    for my $name (@_)
    {
        _transform( $caller, $name, %p );
    }
}

sub _transform
{
    my $caller = shift;
    my $name   = shift;
    my %p      = @_;

    my $attr = $caller->meta()->get_attribute($name);

    param_error "No such attribute $name"
        unless $attr;

    if ( my $inflate_sub = $p{inflate} )
    {
        my $raw_reader = $name . q{_raw};

        param_error "Cannot provide more than one inflator for a column ($name)"
            if $caller->meta()->has_method($raw_reader);

        $caller->meta()->add_method( $raw_reader => $attr->get_read_method_ref() );

        my $inflator =
            sub { my $orig = shift;
                  my $val = $_[0]->$orig();

                  return $_[0]->$inflate_sub($val);
                };

        $caller->meta()->add_around_method_modifier( $name => $inflator );
    }

    if ( $p{deflate} )
    {
        _make_deflate_attribute($caller);

        param_error "Cannot provide more than one deflator for a column ($name)"
            if $caller->_HasDeflator($name);

        $caller->_SetDeflator( $name => $p{deflate} );
    }
}

sub _combine_hashes
{
    return map { %{ $_ } } @_;
}

sub inflate (&)
{
    return { inflate => $_[0] };
}

sub deflate (&)
{
    return { deflate => $_[0] };
}

sub _make_deflate_attribute
{
    my $caller = shift;

    return if $caller->can('Deflators');

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          'Deflators' =>
          ( metaclass => 'Collection::Hash',
            is        => 'rw',
            isa       => 'HashRef[CodeRef]',
            default   => sub { {} },
            lazy      => 1,
            provides  => { get    => '_GetDeflator',
                           set    => '_SetDeflator',
                           exists => '_HasDeflator',
                         },
          )
        );
}


1;
