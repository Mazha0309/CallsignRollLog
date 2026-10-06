Name: openlogtool
Version: 2.8.0
Release: 1
Summary: Amateur radio net logging and collaboration client
License: AGPL-3.0
URL: https://github.com/Mazha0309/CallsignRollLog

%description
Callsign Roll Log is an amateur radio net logging and collaboration client.

%prep

%build

%install
mkdir -p %{buildroot}/opt/openlogtool
cp -r %{_sourcedir}/bundle/* %{buildroot}/opt/openlogtool/
mkdir -p %{buildroot}/usr/share/applications
cp %{_sourcedir}/openlogtool.desktop %{buildroot}/usr/share/applications/
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
cp %{_sourcedir}/app_icon_512.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/openlogtool.png

%files
/opt/openlogtool
/usr/share/applications/openlogtool.desktop
/usr/share/icons/hicolor/256x256/apps/openlogtool.png
