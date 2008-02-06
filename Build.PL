use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new
        ( module_name        => 'Fey::ORM',
          license            => 'perl',
          requires           => { 'Fey'                       => 0.03,
                                  'Fey::DBIManager'           => 0,
                                  'Moose'                     => 0.34,
                                  'MooseX::ClassAttribute'    => 0,
                                  'MooseX::StrictConstructor' => 0,
                                  'Scalar::Util'              => 0,
                                },
          build_requires     => { 'Fey::Test'  => 0,
                                  'Test::More' => 0,
                                },
          create_makefile_pl => 'passthrough',
          create_readme      => 1,
          sign               => 1,
        );

$builder->create_build_script();
