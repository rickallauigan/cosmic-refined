# Maintainer: Maxime Gauduin <alucryd@archlinux.org>
# Maintainer: Peter Jung <ptr1337@archlinux.org>
# Contributor: Mark Wagie <mark.wagie@proton.me>

pkgname=cosmic-launcher
pkgver=1.9.0
pkgrel=1
epoch=1
pkgdesc='Layer Shell frontend for Pop Launcher'
arch=(x86_64)
url=https://github.com/pop-os/cosmic-launcher
license=(GPL-3.0-only)
groups=(cosmic)
depends=(
  cosmic-icon-theme
  libgcc
  glibc
  libxkbcommon
  pop-launcher
  wayland
)
makedepends=(
  cargo
  clang
  git
  intltool
  just
  lld
)
source=(
  git+https://github.com/pop-os/cosmic-launcher.git#tag=epoch-${pkgver}
  cosmic-launcher-lto.patch
)
b2sums=('6b21d219ee600f74fc7792ce94bc0edc52ad1ecd23280c6d7e8ebfa9b4609b701ccfbd9049368f45169b76ec81c7738dd8e937eb1f81c853048a6497876cd696'
        'a83c9394a6975f848e6786b3760f762351dd95f6fcd6dcb51c1beb5fae65f46f4d1e218fae00b854e592639bbe7c086e7d9a78ae2e6b0a26702e33c9140553c5')

prepare() {
  cd cosmic-launcher
  patch -Np1 -i ../cosmic-launcher-lto.patch
  cargo fetch --locked
}
build() {
  cd cosmic-launcher
  RUSTFLAGS+=" -C link-arg=-fuse-ld=lld"
  just build-release --frozen
}

package() {
  cd cosmic-launcher
  just rootdir="${pkgdir}" install
}

# vim: ts=2 sw=2 et:
