%define rname sguil
%define server_prefix /sguil_data
%define server_user sguil
%define server_group sguil

Summary: SGUIL - Analyst console for Snort, Server part
Name: sguil-server
Version: 0.5.2
Release: 1
License: QPL
Group: Applications/Internet
URL: http://sguil.sourceforge.net/

Packager: Michael Boman <michael.boman@boseco.com>
Vendor: BOSECO Internet Security Solutions, http://www.boseco.com

Source0: http://sguil.sourceforge.net/%{rname}-%{version}.tar.gz
Source1: sguild.init
Source2: sguild.sysconfig
BuildRoot: %{_tmppath}/root-%{rname}-%{version}
Prefix: %{_prefix}

BuildArch: noarch
Requires: tcl, mysqltcl, tclx, tcllib

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
%{__install} -d -m0755 %{buildroot}%{server_prefix} \
			%{buildroot}%{server_prefix}/{bin,etc,rules,archive} \
			%{buildroot}/etc/init.d \
			%{buildroot}/etc/sysconfig

%{__install} server/sguild %{buildroot}%{server_prefix}/bin

%{__install} server/autocat.conf %{buildroot}%{server_prefix}/etc
%{__install} server/sguild.conf %{buildroot}%{server_prefix}/etc
%{__install} server/sguild.queries %{buildroot}%{server_prefix}/etc
%{__install} server/sguild.users %{buildroot}%{server_prefix}/etc
%{__install} server/sguild.access %{buildroot}%{server_prefix}/etc
%{__install} server/sguild.reports %{buildroot}%{server_prefix}/etc

%{__install} %{SOURCE1} %{buildroot}/etc/init.d/sguild
%{__install} %{SOURCE2} %{buildroot}/etc/sysconfig/sguild

%clean
%{__rm} -rf %{buildroot}

%pre
grep -q %{server_user} /etc/passwd || useradd %{server_user}

%postun 
grep -q %{server_user} /etc/passwd && userdel %{server_user}

%files
%defattr(-, root, root, 0755)
%doc doc/* server/sql_scripts/*
%config %{server_prefix}/etc/*
%{server_prefix}/bin/* 
/etc/init.d/sguild
/etc/sysconfig/sguild

%changelog
