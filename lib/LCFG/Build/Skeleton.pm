package LCFG::Build::Skeleton;    # -*-cperl-*-
use strict;
use warnings;

# $Id: Skeleton.pm.in,v 1.6 2008/12/05 12:13:58 squinney Exp $
# $Source: /disk/cvs/dice/LCFG-Build-Skeleton/lib/LCFG/Build/Skeleton.pm.in,v $
# $Revision: 1.6 $
# $HeadURL$
# $Date: 2008/12/05 12:13:58 $

our $VERSION = '0.0.9';

use File::Basename ();
use File::Path     ();
use File::Spec     ();
use LCFG::Build::PkgSpec ();
use List::MoreUtils qw(none);
use Sys::Hostname ();
use Template      ();
use UNIVERSAL::require;
use YAML::Syck    ();

my $TMPLDIR
    = exists $ENV{LCFG_BUILD_TMPLDIR}
    ? $ENV{LCFG_BUILD_TMPLDIR}
    : '/usr/share/lcfgbuild/templates';

use Moose;
use Moose::Util::TypeConstraints;

with 'MooseX::Getopt';

subtype 'LCFG::Types::Response' => as 'Str';

coerce 'LCFG::Types::Response' => from 'Str' =>
    via { $_ && ( $_ eq '1' || m/^ye(s|p|ah)!?$/i ) ? 'yes' : 'no' };

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'LCFG::Types::Response' => q{!}, );

has 'configfile' => (
    is        => 'ro',
    isa       => 'Str',
    default   => sub { File::Spec->catfile( $ENV{HOME}, '.lcfg',
                                            'skeleton', 'defaults.yml' ) },
    predicate => 'has_configfile',
    documentation => 'Where defaults should be stored',
);

has 'tmpldir' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { File::Spec->catdir( $ENV{HOME}, '.lcfg',
                                         'skeleton', 'templates' ) },
    documentation => 'Local templates directory',
);

has 'usage' => (
    metaclass => 'NoGetopt',
    is        => 'ro',
    isa       => 'Str',
);

has 'help' => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Display the help text',
);

has 'name' => (
    is            => 'rw',
    isa           => 'Str',
    documentation => 'Name of the project',
);

has 'abstract' => (
    is            => 'rw',
    isa           => 'Str',
    lazy          => 1,
    documentation => 'Short description of the project',
    default       => sub {
        $_[0]->lcfg_component eq 'yes'
            ? 'The LCFG ' . $_[0]->name . ' component'
            : q{};
    },
);

has 'author_name' => (
    is            => 'rw',
    isa           => 'Str',
    default       => sub { ( getpwuid $< )[6] },
    documentation => 'Name of the author',
);

has 'author_email' => (
    is            => 'rw',
    isa           => 'Str',
    builder       => '_default_email',
    documentation => 'Email address for the author',
);

sub _default_email {
    my $username = ( getpwuid $< )[0];

    my ( $hostname, @domain ) = split /\./, Sys::Hostname::hostname;

    my $domain = join q{.}, @domain;
    my $email = join q{@}, $username, $domain;

    return $email;
}

has 'lang' => (
    is            => 'rw',
    isa           => enum( [qw/perl shell/] ),
    documentation => 'Language for component (perl/shell)',
    default       => 'perl',
);

has 'vcs' => (
    is            => 'rw',
    isa           => enum( [qw/CVS None/] ),
    documentation => 'Version Control System (CVS/None)',
    default       => 'CVS',
);

has 'platforms' => (
    is            => 'rw',
    isa           => 'Maybe[Str]',
    documentation => 'Supported platforms',
);

has 'license' => (
    is            => 'rw',
    isa           => 'Str',
    documentation => 'Distribution license',
    default       => 'GPLv2',
);

has 'restart' => (
    is            => 'rw',
    isa           => 'LCFG::Types::Response',
    coerce        => 1,
    documentation => 'Restart component on RPM update (yes/no)',
    default       => 'yes',
);

has 'gencmake' => (
    is            => 'rw',
    isa           => 'LCFG::Types::Response',
    coerce        => 1,
    documentation => 'Use the CMake build system (yes/no)',
    default       => 'yes',
);

has 'genchangelog' => (
    is            => 'rw',
    isa           => 'LCFG::Types::Response',
    coerce        => 1,
    documentation => 'Generate the ChangeLog from the Revision-Control log? (yes/no)',
    default       => 'no',
);

has 'checkcommitted' => (
    is            => 'rw',
    isa           => 'LCFG::Types::Response',
    coerce        => 1,
    documentation => 'Check all changes are committed before a release? (yes/no)',
    default       => 'yes',
);

has 'lcfg_component' => (
    is            => 'rw',
    isa           => 'LCFG::Types::Response',
    coerce        => 1,
    documentation => 'Is this an LCFG component? (yes/no)',
    default       => 'yes',
);

has 'interactive' => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Interactively query the user',
    default       => 1,
);

has 'force' => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Forceably remove an old project directory',
    default       => 0,
);

sub get_config_from_file {
    my ( $self, $file ) = @_;

    my $cfg = {};
    if ( -f $file ) {
        $cfg = YAML::Syck::LoadFile($file);
    }

    return $cfg;
}

# The code for new_with_options() is mostly stolen from
# MooseX::Getopt. It has modifications to allow us to ignore the need
# to check for a MooseX::ConfigFromFile role. That module just pulls
# in far too many extra dependencies for our fairly small
# requirements. This code also handles the default value for the
# configfile being a code-reference.

sub new_with_options {
    my ( $class, @params ) = @_;

    my $config_from_file;
    {
        local @ARGV = @ARGV;

        my $configfile;
        my $opt_parser
            = Getopt::Long::Parser->new( config => [qw(pass_through)] );

        $opt_parser->getoptions( 'configfile=s' => \$configfile );

        if ( !defined $configfile ) {
            my $cfmeta = $class->meta->find_attribute_by_name('configfile');
            if ( $cfmeta->has_default ) {
                $configfile = $cfmeta->default;
            }
            if ( 'CODE' eq ref $configfile ) {
                $configfile = $configfile->();
            }
        }

        if ( defined $configfile ) {
            $config_from_file = $class->get_config_from_file($configfile);
        }

    }

    my $constructor_params = ( @params == 1 ? $params[0] : {@params} );

    if ( ref $constructor_params ne 'HASH' ) {
        die "Single parameters to new_with_options() must be a HASH ref\n";
    }

    my %processed = $class->_parse_argv(
        options => [ $class->_attrs_to_options($config_from_file) ],
        params  => $constructor_params,
    );

    my $params
        = $config_from_file
        ? { %{$config_from_file}, %{ $processed{params} } }
        : $processed{params};

    return $class->new(
        ARGV       => $processed{argv_copy},
        extra_argv => $processed{argv},
        usage      => "$processed{usage}", # stringify immediately
        @params,       # explicit params to ->new
        %{$params},    # params from CLI
    );

}

my @questions = qw(
    name
    lcfg_component
    abstract
    author_name
    author_email
    lang
    vcs
    platforms
    license
    restart
    gencmake
    checkcommitted
    genchangelog
);

sub store_answers {
    my ($self) = @_;

    my @ignore = qw(name lcfg_component abstract);
    my @extra  = qw(tmpldir);

    my %store;
    for my $question ( @questions, @extra ) {
        if ( none { $question eq $_ } @ignore ) {
            $store{$question} = $self->$question;
        }
    }

    my $cfg = $self->configfile;

    my ( $name, $path ) = File::Basename::fileparse($cfg);
    if ( !-d $path ) {
        eval { File::Path::mkpath($path) };
        if ($@) {
            die "Failed to create directory, $cfg: $!\n";
        }
    }

    YAML::Syck::DumpFile( $cfg, \%store );

    return;
}

sub query_user {
    my ($self) = @_;

    if ( $self->interactive ) {
        for my $question (@questions) {

            my $doc = $self->meta->get_attribute($question)->documentation;

            my $default = $self->$question;

            my $defstring = q{};
            if ( defined $default ) {
                $defstring = ' [' . $default . ']';
            }

            while (1) {
                print $doc . $defstring . q{: };
                chomp( my $answer = <STDIN> );

                # trim any whitespace from the response
                $answer =~ s/^\s+//;
                $answer =~ s/\s+$//;

                if ( length $answer > 0 ) {
                    eval { $self->$question($answer) };
                }

                if ($@) {
                    print "Error: Bad choice, please try again.\n";
                }
                else {
                    last;
                }

            }
        }
    }

    # always store the answers as they may have come from the command line
    $self->store_answers;

    return;
}

sub create_package {
    my ($self) = @_;

    my $author = $self->author_name . ' <' . $self->author_email . '>';

    my @platforms;
    if ( $self->platforms ) {
        @platforms = split /\s*,\s*/, $self->platforms;
    }

    my $pkgspec = LCFG::Build::PkgSpec->new(
        name      => $self->name,
        version   => '0.0.1',
        release   => '1',
        author    => $author,
        abstract  => $self->abstract,
        license   => $self->license,
        translate => ['*.cin'],
        platforms => [@platforms],
    );

    if ( $self->lcfg_component eq 'yes' ) {
        $pkgspec->schema(1);
        $pkgspec->base('lcfg');
        $pkgspec->group('LCFG');
    }

    if ( $self->gencmake eq 'yes' ) {
        $pkgspec->set_buildinfo( gencmake => 1 );
    }
    else {    # not essential but good to be explicit here
        $pkgspec->set_buildinfo( gencmake => 0 );
    }

    # version control information

    $pkgspec->set_vcsinfo( type => $self->vcs );

    $pkgspec->set_vcsinfo( logname => 'ChangeLog' );

    if ( $self->checkcommitted eq 'yes' ) {
        $pkgspec->set_vcsinfo( checkcommitted => 1 );
    }
    if ( $self->genchangelog eq 'yes' ) {
        $pkgspec->set_vcsinfo( genchangelog => 1 );
    }

    my $dirname = $pkgspec->fullname;

    if ( -d $dirname ) {
        if ( $self->force ) {
            File::Path::rmtree($dirname);
        }
        else {
            die "The directory $dirname already exists. Please move it out of the way, choose a different name for your project or use the --force option.\n";
        }
    }

    eval { File::Path::mkpath($dirname) };
    if ($@) {
        die "Failed to create directory, $dirname: $!\n";
    }
    print "Created directory $dirname\n";

    my $new_metafile = File::Spec->catfile( $dirname, 'lcfg.yml' );
    $pkgspec->metafile($new_metafile);
    $pkgspec->save_metafile();

    print "Stored LCFG build metadata\n";

    my @include;
    if ( -d $self->tmpldir ) {
        push @include, $self->tmpldir;
    }
    push @include, $TMPLDIR;

    my $tt = Template->new(
        {   INCLUDE_PATH => \@include,
            FILTERS      => { to_bool => sub { $_ eq 'yes' ? 1 : 0 }, },
            PRE_CHOMP    => 1,
        }
    ) or die $Template::ERROR;

    my %files = (
        specfile       => 'specfile.tt',
        ChangeLog      => 'ChangeLog.tt',
        'README.BUILD' => 'README.BUILD.tt',
        README         => 'README.tt',
    );

    my @exefiles;

    if ( $self->lcfg_component eq 'yes' ) {
        my $comp = $pkgspec->name;

        if ( $self->lang eq 'perl' ) {
            $files{"$comp.cin"} = 'COMPONENT.pl.tt';
        }
        else {
            $files{"$comp.cin"} = 'COMPONENT.sh.tt';
        }
        push @exefiles, "$comp.cin";

        $files{"$comp.def.cin"} = 'COMPONENT.def.tt';
        $files{"$comp.pod.cin"} = 'COMPONENT.pod.tt';

        my $nagios_dir = File::Spec->catdir( $dirname, 'nagios' );
        mkdir $nagios_dir
            or die "Could not create nagios directory, $nagios_dir: $!\n";

        my $templates_dir = File::Spec->catdir( $dirname, 'templates' );
        mkdir $templates_dir
            or die "Could not create templates directory, $templates_dir: $!\n";
    }

    for my $file ( keys %files ) {

        my $template = $files{$file};
        my $output   = File::Spec->catfile( $dirname, $file );

        print "Generating $output\n";
        $tt->process(
            $template,
            {   skel    => $self,
                pkgspec => $pkgspec,
            },
            $output
        ) or warn $tt->error();
    }

    for my $exe (@exefiles) {
        my $path = File::Spec->catfile( $dirname, $exe );
        chmod 0755, $path;
    }

    if ( $self->lang eq 'perl' ) {
        my $testdir = File::Spec->catdir( $dirname, 't' );
        mkdir $testdir
            or die "Could not create tests directory, $testdir: $!\n";
    }

    eval {
        my $vcsmodule = 'LCFG::Build::VCS::' . $pkgspec->get_vcsinfo('type');

        $vcsmodule->require or die $@;

        my $vcs = $vcsmodule->new(
            quiet   => 0,
            dryrun  => 0,
            module  => $pkgspec->fullname,
            workdir => $dirname,
        );

        $vcs->import_project( $pkgspec->version,
            'Created with lcfg-skeleton' );

        # icky but apparently unavoidable
        if ( $pkgspec->get_vcsinfo('type') eq 'CVS' ) {
            File::Path::rmtree($dirname);
        }

        $vcs->checkout_project();
    };

    if ($@) {
        die "Failed to import project to your chosen version-control system\n";
    }

    print "Successfully imported your project into your version-control system.\n";

    return $pkgspec;
}

1;
__END__

=head1 NAME

    LCFG::Build::Skeleton - LCFG software package generator

=head1 VERSION

    This documentation refers to LCFG::Build::Skeleton version 0.0.9

=head1 SYNOPSIS

    my $skel = LCFG::Build::Skeleton->new_with_options();

    $skel->query_user();

    $skel->create_package();

=head1 DESCRIPTION

This module handles the creation of the skeleton of an LCFG software
project. Typically, it prompts the user to answer a set of standard
questions and then generates the necessary files from a set of
templates. These generated files include the necessary metadata, build
files and, for LCFG components, example code. It can also add the new
project into the revision-control system of choice.

=head1 ATTRIBUTES

If using the new_with_options() method then any of the attributes can
be set from the commandline (or, more precisely, via the @ARGV
list). An attribute named C<foo> is accessible as the commandline
option C<--foo>. If it is a boolean value then the module will also
support the C<--no-foo> form to turn off a feature
(e.g. --no-gencmake).

=over 4

=item name

The name of the project. Note that in the case of an LCFG component
this should be C<foo> B<NOT> C<lcfg-foo>.

=item abstract

A short description of the project. If this is an LCFG component the
default value suggested to the user is "The LCFG $name component".

=item author_name

The name of the author (i.e you!). The default is the string stored in
the gecos field of the passwd entry.

=item author_email

The email address for the author. The default is built from the
current username and domain name.

=item lcfg_component

This controls whether the generated project is an LCFG component. This
is a yes/no answer and it defaults to "yes" (it is handled in the same
way as a boolean value on the command line).

=item lang

The language which will be used, this is either "perl" or
"shell". This only really has an affect if you are creating an LCFG
component.

=item vcs

Which revision-control system you intend to use for the
project. Currently only "CVS" and "None" are supported. You will need
the relevant LCFG::Build::VCS helper module installed for this to
work.

=item platforms

The comma-separate list of platforms which are supported by this code
(e.g. ScientificLinux5).

=item license

The license under which the source code can be distributed. This
defaults to "GPLv2".

=item restart

This controls whether, if this is an LCFG component, should it be
restarted after package upgrade if the component is already
running. This is a yes/no answer and it defaults to "yes" (it is
handled in the same way as a boolean value on the command line).

=item gencmake

This controls whether the LCFG CMake infrastructure will be used to
build the project. This is a yes/no answer and it defaults to "yes"
(it is handled in the same way as a boolean value on the command
line).

=item genchangelog

This controls whether or not to generate the project changelog from
the revision-control commit logs. This is a yes/no answer and it
defaults to "no" (it is handled in the same way as a boolean value on
the command line).

=item checkcommitted

This controls whether the revision-control tools should check that all
files are committed before making a new release. This is a yes/no
answer and it defaults to "yes" (it is handled in the same way as a
boolean value on the command line).

=item interactive

This controls whether the L<query_user()> method will actually interact with the user or just store the values taken from the defaults file and any commandline options. This is a boolean value which defaults to false (zero).

=item force

This controls whether an existing project directory will be removed if the name matches that required for the new skeleton project. This is a boolean value which defaults to false (zero).

=item configfile

This is the configuration file which is used to store the defaults
between calls to the lcfg-skeleton tool. Normally you should not need
to modify this and it defaults to C<~/.lcfg/skeleton/defaults.yml>.

=item tmpldir

This is the directory into which local versions of templates should be
placed. Normally you should not need to modify this and it defaults to
C<~/.lcfg/skeleton/templates/>. For reference, the standard templates
are normally stored in C</usr/share/lcfgbuild/templates>.

=back


=head1 SUBROUTINES/METHODS

=over 4

=item new(%hash_of_options)

Creates a new object of the LCFG::Build::Skeleton class. Values for
any attribute can be specified in the hash of options.

=item new_with_options(%hash_of_options)

Creates a new object of the LCFG::Build::Skeleton class and if any
attribute values were specified on the command line those will be set
in the returned instance. Values for any attribute can be specified in
the hash of options.

=item query_user()

This prompts the user to answer a set of standard questions (except
when the C<interactive> option is set to false) and stores the answer
in the object attributes. If an invalid value is given the user will
be prompted again. For convenience, the answers are also stored in a
file and used as the defaults in the next run of the command. The
default value is shown in the prompt between square-brackets and just
pressing return is enough to accept the default.

=item create_package()

This uses the skeleton object attribute values to generate the
skeleton tree of files for the new project. If a project directory of
the desired name already exists you will need to move it aside, choose
a different project name or set the C<force> attribute to true.

=item store_answers()

This is primarily intended for internal usage. It will store the
values of the answers given be the user (except the project name and
abstract) so that they can be used as defaults in future calls to the
lcfg-skeleton command. The default values are stored in the file name
specified in the C<configfile> attribute, that defaults to
C<~/lcfg/skeleton/defaults.yml>

=item get_config_from_file($filename)

This is primarily intended for internal usage. This retrieves the
configuration data from the specified file, which must be in YAML
format, and returns it as a reference to a hash.

=back

=head1 CONFIGURATION AND ENVIRONMENT

The default values for the answers are stored in the file referred to
in the C<configfile> attribute. This is normally
C<~/.lcfg/skeleton/defaults.yml> but that can be overridden by the
user. If the file does not exist it will be created when this tool is
first run.

It is possible to override any of the standard templates used to
generate the skeleton project by placing your own version into the
directory referred to in the C<tmpldir> attribute. This is normally
C<~/.lcfg/skeleton/templates/> but that can be overridden by the
user. For reference, the standard templates are normally stored in
C</usr/share/lcfgbuild/templates>.

=head1 DEPENDENCIES

This module is L<Moose> powered and uses L<MooseX::Getopt> to provide
a new_with_options() method for creating new instances from the
options specified in @ARGV (typically via the commandline). The
L<YAML::Syck> module is used to parse the file which holds the default
values for the answers.  You will also need the L<List::MoreUtils> and
L<UNIVERSAL::require> modules.

The Perl Template Toolkit is required to generate the files for the
skeleton project.

The following LCFG Build Tools modules are also required:
L<LCFG::Build::PkgSpec>(3), L<LCFG::Build::VCS>(3) and VCS helper modules.

=head1 SEE ALSO

L<LCFG::Build::Tools>, lcfg-skeleton(1), lcfg-reltool(1)

=head1 PLATFORMS

This is the list of platforms on which we have tested this
software. We expect this software to work on any Unix-like platform
which is supported by Perl.

FedoraCore5, Fedora6, ScientificLinux5

=head1 BUGS AND LIMITATIONS

There are no known bugs in this application. Please report any
problems to bugs@lcfg.org, feedback and patches are also always very
welcome.

=head1 AUTHOR

    Stephen Quinney <squinney@inf.ed.ac.uk>

=head1 LICENSE AND COPYRIGHT

    Copyright (C) 2008 University of Edinburgh

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL, version 2 or later.

=cut
