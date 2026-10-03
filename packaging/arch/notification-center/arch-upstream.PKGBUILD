# Maintainer: Maxime Gauduin <alucryd@archlinux.org>
# Maintainer: Peter Jung <ptr1337@archlinux.org>
# Contributor: soloturn <soloturn@gmail.com>
# Contributor: Mark Wagie <mark.wagie@proton.me>

pkgname=cosmic-applets
pkgver=1.9.0
pkgrel=1
epoch=1
pkgdesc='Applets for COSMIC Panel'
arch=(x86_64)
url=https://github.com/pop-os/cosmic-applets
license=(GPL-3.0-only)
groups=(cosmic)
depends=(
  cosmic-icon-theme
  dbus
  libgcc
  glibc
  libinput
  libpipewire
  libpulse
  libxkbcommon
  systemd-libs
  util-linux
)
makedepends=(
  cargo
  clang
  git
  just
  mold
)
source=(git+https://github.com/pop-os/cosmic-applets.git#tag=epoch-${pkgver})
b2sums=('bcccb1036ea0c4de278728359cf24ded22973c3509d1023ddd8d022db294743ffe16b8afd3747e4f8feba59711605e7cdfa5f3127d51c6ad5a74c43c29d8a871')

prepare() {
  cd cosmic-applets
  cargo fetch --locked
  sed 's/lto = "fat"/lto = "thin"/' -i Cargo.toml
}

build() {
  cd cosmic-applets
  RUSTFLAGS+=" -C link-arg=-fuse-ld=mold"
  just build-release --frozen
}

package() {
  cd cosmic-applets
  just rootdir="${pkgdir}" install
}

# vim: ts=2 sw=2 et:
