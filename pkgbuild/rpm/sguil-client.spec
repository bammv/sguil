%define rname sguil
Summary: SGUIL - Analyst console for Snort, Console part
Name: sguil-client
Version: 0.5.3
Release: 1
License: QPL
Group: Applications/Internet
URL: http://sguil.sourceforge.net/

Packager: Michael Boman <michael.boman@boseco.com>
Vendor: BOSECO Internet Security Solutions, http://www.boseco.com

Source: http://sguil.sourceforge.net/%{rname}-%{version}.tar.gz
BuildRoot: %{_tmppath}/root-%{rname}-%{version}
Prefix: %{_prefix}

BuildArch: noarch
Requires: tcl, tcllib, tclx, itcl, tk

Obsoletes: %{name}
Provides: %{name}

%description
Sguil (pronounced sgweel) is built by network security analysts for
network security analysts. Sguil's main component is an intuitive GUI
that provides realtime events from snort/barnyard. It also includes other
components which facilitate the practice of Network Security Monitoring
and event driven analysis of IDS alerts.

%prep
%setup -n %{rname}-%{version}

%install
%{__rm} -rf %{buildroot}
%{__install} -d -m0755 \
	%{buildroot}/etc/sguil \
	%{buildroot}%{_bindir} \
	%{buildroot}%{_libdir}/sguil-client

%{__install} client/sguil.tk %{buildroot}%{_bindir}/sguil.tk
%{__install} client/sguil.conf %{buildroot}/etc/sguil/
%{__install} client/lib/* %{buildroot}%{_libdir}/sguil-client/
sed -i -e s:'set SGUILLIB ./lib':'set SGUILLIB /usr/lib/sguil-client': \
	%{buildroot}/etc/sguil/sguil.conf


%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, root, root, 0755)
%doc doc/*
/etc/sguil/sguil.conf
%{_bindir}/sguil.tk
%{_libdir}/sguil-client/*

%changelog
