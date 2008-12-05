Name:           perl-LCFG-Build-Skeleton
Summary:        Tools for generating new LCFG projects
Version:        0.0.9
Release:        1
Packager:       Stephen Quinney <squinney@inf.ed.ac.uk>
License:        GPLv2
Group:          LCFG/Development
Source:         LCFG-Build-Skeleton-0.0.9.tar.gz
BuildArch:	noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildRequires:  perl(Module::Build)
Requires:	perl(LCFG::Build::PkgSpec) >= 0.0.23
Requires:	perl(LCFG::Build::VCS) >= 0.0.20
Requires:	perl(Moose) >= 0.57
Requires:	perl(MooseX::Getopt) >= 0.13
Requires:       perl(Template) >= 2.14
Requires:       perl(UNIVERSAL::require)
Requires:	perl(YAML::Syck) >= 0.98
Requires:       perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
This module handles the creation of the skeleton of an LCFG software
project. Typically, it prompts the user to answer a set of standard
questions and then generates the necessary files from a set of
templates. These generated files include the necessary metadata, build
files and, for LCFG components, example code. It can also add the new
project into the revision-control system of choice.

More information on the LCFG build tools is available from the website
http://www.lcfg.org/doc/buildtools/


%prep
%setup -q -n LCFG-Build-Skeleton-%{version}

%build
%{__perl} Build.PL installdirs=vendor
./Build

%install
rm -rf $RPM_BUILD_ROOT
./Build install destdir=$RPM_BUILD_ROOT create_packlist=0
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null \;

%{_fixperms} $RPM_BUILD_ROOT/*

%files
%defattr(-,root,root)
%doc ChangeLog
%doc %{_mandir}/man1/*
%doc %{_mandir}/man3/*
%{perl_vendorlib}/LCFG/Build/Skeleton.pm
/usr/share/lcfgbuild/templates/*.tt
/usr/bin/lcfg-skeleton

%clean
rm -rf $RPM_BUILD_ROOT

%changelog
* Fri Dec 05 2008 <<<< Release: 0.0.9 >>>>

* Fri Dec 05 2008 12:13 squinney
- Automatically create templates and nagios directories for LCFG
  components

* Fri Sep 12 2008 11:39 squinney

* Fri Sep 12 2008 11:39 squinney
- Fixed bug with setting the list of questions. Renamed 'rcs'
  attribute to 'vcs' to be consistent with how it is named in the
  rest of the build tools

* Thu Sep 11 2008 20:06 squinney

* Thu Sep 11 2008 20:06 squinney
- Modified some file path handling to use File::Spec

* Thu Sep 11 2008 16:23 squinney
- Added a really basic test to see that the Skeleton module
  actually loads

* Thu Sep 11 2008 16:21 squinney
- Added missing comma in Makefile.PL dependency list

* Thu Sep 11 2008 10:20 squinney

* Thu Sep 11 2008 10:20 squinney
- Fixed error in META.yml which upsets the pause indexer

* Wed Sep 10 2008 19:34 squinney

* Wed Sep 10 2008 19:31 squinney
- Modified META.yml to attempt to avoid pause wrongly indexing
  template files

* Wed Sep 10 2008 15:19 squinney

* Wed Sep 10 2008 15:19 squinney
- Lots of improvements to the documentation. Some code tidying to
  satisfy perltidy and perlcritic.

* Mon Sep 08 2008 11:47 squinney
- Fixed various conditional sections in the specfile template

* Thu Sep 04 2008 12:47 squinney

* Thu Sep 04 2008 12:47 squinney
- Fully converted module to using Module::Build

* Thu Sep 04 2008 10:42 squinney

* Thu Sep 04 2008 10:40 squinney
- Copied over various files from the original project tree. Also
  converted to using the perl Module::Build system to make it the
  same as the other LCFG build tool modules.

* Thu Sep 04 2008 10:08 squinney
- Created with lcfg-skeleton

* Thu Sep 04 2008 10:08 squinney
- Initial revision


