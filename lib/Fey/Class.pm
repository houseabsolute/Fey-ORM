package Fey::Class;

use strict;
use warnings;

our @EXPORT = ## no critic ProhibitAutomaticExportation
    qw( has_table has_one transform inflate deflate );
use base 'Exporter';

use Fey::Object;
use Fey::Exceptions qw( param_error );
use Fey::Validate qw( validate_pos TABLE_TYPE FK_TYPE BOOLEAN_TYPE );
use Moose ();
use MooseX::AttributeHelpers;
use MooseX::ClassAttribute;
use MooseX::StrictConstructor::Meta::Class;


# This re-exporting is a mess. Once MooseX::Exporter is done,
# hopefully it can replace all of this.
sub import
{
    my $caller = Moose::_get_caller();

    return if $caller eq 'main';

    Moose::init_meta( $caller,
                      'Fey::Object',
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

        param_error 'A table object passed to has_table() must have at least one key'
            unless $table->primary_key();

        my $caller = caller();

        _make_class_attributes( $caller, $table );
        _make_column_attributes( $caller, $table );
    }
}

sub _make_class_attributes
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

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_RowSQL' =>
          ( is        => 'rw',
            isa       => 'Fey::SQL',
            lazy      => 1,
            default   => sub { return $_[0]->_MakeRowSQL() },
          )
        );

    MooseX::ClassAttribute::process_class_attribute
        ( $caller,
          '_Manager' =>
          ( is  => 'rw',
            isa => 'Fey::DBIManager',
          )
        );
}

sub _make_column_attributes
{
    my $caller = shift;
    my $table  = shift;

    my $meta = $caller->meta();

    my %pk = map { $_->name() => 1 } $table->primary_key();

    for my $column ( $table->columns() )
    {
        my $name = $column->name();

        next if $meta->has_method($name);

        my %default_or_required =
            ( $pk{$name}
              ? ( required => 1 )
              : ( lazy    => 1,
                  default => sub { $_[0]->_get_column_value($name) } )
            );

        $meta->_process_attribute
            ( $name,
              is      => 'rw',
              isa     => _type_for_column( $caller, $column ),
              writer  => q{_} . $name,
              %default_or_required,
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

{
    my $simple_spec = ( TABLE_TYPE );
    my $complex_spec = { table => TABLE_TYPE,
                         cache => BOOLEAN_TYPE,
                         fk    => FK_TYPE,
                       };

    sub has_one
    {
        my %p;
        if ( @_ == 1 )
        {
            ( $p{table} ) = validate_pos( @_, $simple_spec );
        }
        else
        {
            %p = validate( @_, $complex_spec );
        }

        param_error 'A table object passed to has_one() must have a schema'
            unless $p{table}->has_schema();

        my $caller = caller();

        param_error 'You must call has_table() before calling has_one().'
            unless $caller->can('Table');

        $p{fk} ||= _find_one_fk( $caller->Table(), $p{table}, 'has_one' );

        _make_has_one_attribute( $caller, \%p );
    }
}

sub _find_one_fk
{
    my $from = shift;
    my $to   = shift;
    my $func = shift;

    my @fk = $from->schema()->foreign_keys_between_tables( $from, $to );

    return $fk[0] if @fk == 1;

    if ( @fk == 0 )
    {
        param_error
            'There are no foreign keys between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name() . '.';
    }
    elsif ( @fk == 2 )
    {
        param_error
            'There is more than one foreign keys between the table for this class, '
            . $from->name()
            . " and the table you passed to $func(), "
            . $to->name()
            . '. You must specify one explicitly.';
    }
}

sub _make_has_one_attribute
{
    my $caller = shift;
    my $p      = shift;

    # XXX - names should be settable via a Fey::Class::Policy
    my $name = $p->{name} || lc $p->{table}->name();

    my $default_sub = _make_has_one_default_sub($p);

    if ( $p->{cache} )
    {
        # It'd be nice to set isa to the actual foreign class, but we may
        # not be able to map a table to a class yet, since that depends on
        # the related class being loaded. It doesn't really matter, since
        # this accessor is read-only, so there's really no typing issue to
        # deal with.
        $caller->meta()->_process_attribute
            ( $name,
              is      => 'ro',
              isa     => 'Fey::Object',
              lazy    => 1,
              default => $default_sub,
            );
    }
    else
    {
        $caller->meta()->add_method( $name => $default_sub );
    }
}

sub _make_has_one_default_sub
{
    my $p = shift;

    my $table = $p->{table};
    my @column_names = map { $_->name() } $p->{fk}->source_columns();

    return
        sub { my $self = shift;

              return
                  Fey::Object
                      ->TableToClass($table)
                      ->new( map { $_ => $self->$_() }
                             @column_names );
            };
}


1;
