Name:           axiome
Version:        1.2
Release:        1%{?dist}
Summary:        QIIME automation toolkit
Source:         axiome.tar.bz2
Group:          Applications/Engineering

License:        GPLv3+
URL:            http://neufeld.github.com/AXIOME

BuildRequires:  zlib-devel
BuildRequires:  bzip2-devel
BuildRequires:  vala
BuildRequires:  libgee-devel
BuildRequires:  file-devel
BuildRequires:  libxml2-devel
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
Requires:       gawk
Requires:       make
Requires:       bzip2
Requires:       gzip
Requires:       R-core

%description
AXIOME is a set of tools for making QIIME <http://qiime.sourceforge.net>
easier to manage by automating error-prone tasks and walking through
common analyses.

%prep
%setup -q
autoreconf -i

%build
%configure
make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

%files
%{_bindir}/aq-*
%{_bindir}/axiome
%doc %{_mandir}/man1/*
%doc %{_defaultdocdir}/axiome/sample.ax*
%doc %{_defaultdocdir}/axiome/hmmb.ax*
%doc %{_defaultdocdir}/axiome/hmmb.fasta.gz
%{_datadir}/axiome/primers.lst

%changelog
 * Tue Oct 11 2011 Andre Masella <andre@masella.name> 1.1-1
 - Fixed packaging issue with stock Vala
 * Tue Oct 11 2011 Andre Masella <andre@masella.name> 1.0-1
 - Initial Release.
