%define rname sguil
%define sensor_prefix /snort_data
%define sensor_user snort
%define sensor_group snort

Summary: SGUIL - Analyst console for Snort, Sensor part
Name: sguil-sensor
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
Requires: tcl, snort, barnyard, tcpdump

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
%{__install} -d -m0755  %{buildroot}%{sensor_prefix}/{bin,etc,ssn_logs,portscans,dailylogs,sancp} \
			%{buildroot}/etc/rc.d/init.d \
			%{buildroot}/etc/cron.d

%{__install} sensor/sensor_agent.tcl %{buildroot}%{sensor_prefix}/bin
%{__install} sensor/sensor_agent.conf %{buildroot}%{sensor_prefix}/etc
%{__install} sensor/log_packets.sh %{buildroot}%{sensor_prefix}/bin
ln -s %{sensor_prefix}/bin/log_packets.sh %{buildroot}/etc/rc.d/init.d/log_packets.sh
echo "00 0-23/1 * * *	root	%{sensor_prefix}/bin/log_packets.sh restart" >> %{buildroot}/etc/cron.d/log_packets.sh

%clean
%{__rm} -rf %{buildroot}

%pre
grep -q %{sensor_user} /etc/passwd || useradd %{sensor_user}

%postun 
grep -q %{sensor_user} /etc/passwd && userdel %{sensor_user}

%files
%defattr(-, root, root, 0755)
%doc doc/*
/etc/rc.d/init.d/log_packets.sh
/etc/cron.d/log_packets.sh
%defattr(-, %{sensor_user}, %{sensor_group}, 0755)
%{sensor_prefix}/*

%changelog
