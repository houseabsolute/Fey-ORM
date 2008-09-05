use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new
        ( module_name          => 'Fey::ORM',
          license              => 'perl',
          requires             => { 'Exception::Class'          => '0',
                                    'Exporter'                  => '0',
                                    'Fey'                       => '0.12',
                                    'Fey::DBIManager'           => '0.07',
                                    'List::MoreUtils'           => '0',
                                    'Moose'                     => '0.57',
                                    'MooseX::AttributeHelpers'  => '0.13',
                                    'MooseX::ClassAttribute'    => '0',
                                    'MooseX::StrictConstructor' => '0.07',
                                    'Scalar::Util'              => '0',
                                  },
          build_requires       => { 'Fey::Test'  => '0.05',
                                    'Test::More' => '0',
                                  },
          recursive_test_files => 1,
          create_makefile_pl   => 'passthrough',
          create_readme        => 1,
          sign                 => 1,
        );

$builder->create_build_script();
