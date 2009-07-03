use strict;
use warnings;

use Module::Build;

my $builder =
    Module::Build->new
        ( module_name          => 'Fey::ORM',
          license              => 'perl',
          requires =>
              { 'Devel::GlobalDestruction'       => '0',
                'Exception::Class'               => '0',
                'Fey'                            => '0.15',
                'Fey::DBIManager'                => '0.07',
                'List::MoreUtils'                => '0',
                'Moose'                          => '0.86',
                'MooseX::AttributeHelpers'       => '0.13',
                'MooseX::ClassAttribute'         => '0.08',
                'MooseX::SemiAffordanceAccessor' => '0',
                'MooseX::StrictConstructor'      => '0.08',
                'Scalar::Util'                   => '0',
                'Sub::Exporter'                  => '0',
              },
          build_requires =>
              { 'Fey::Test'       => '0.05',
                'Test::Exception' => '0',
                'Test::More'      => '0',
              },
          recursive_test_files => 1,
          create_makefile_pl   => 'traditional',
          create_readme        => 1,
          sign                 => 1,
          add_to_cleanup       => [ 'Debian_CPANTS.txt' ],
          meta_merge =>
              { resources =>
                    { homepage   => 'http://www.fey-project.org/',
                      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Fey-ORM',
                      repository => 'http://hg.urth.org/hg/Fey-ORM',
                    },
              },
        );

$builder->create_build_script();
