# Maintainer: artoo <flower_of_life@gmx.net>

pkgname=manjaro-tools-git
pkgver=r130.0af8baf
pkgrel=1
pkgdesc='Tools for Manjaro Linux'
arch=('any')
license=('GPL')
url='https://github.com/udeved/manjaro-tools'
depends=('namcap' 'openssh' 'rsync')
makedepends=('git')
provides=('devtools' 'arch-install-scripts' 'manjaro-tools')
conflicts=('devtools' 'arch-install-scripts' 'manjaro-tools')
backup=('etc/manjaro-tools/manjaro-tools.conf')
source=("git+$url.git")
sha256sums=('SKIP')

pkgver() {
	cd ${srcdir}/manjaro-tools
	printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
	cd ${srcdir}/manjaro-tools
	make SYSCONFDIR=/etc PREFIX=/usr
}

package() {
	cd ${srcdir}/manjaro-tools
	make SYSCONFDIR=/etc PREFIX=/usr DESTDIR=${pkgdir} install
}
