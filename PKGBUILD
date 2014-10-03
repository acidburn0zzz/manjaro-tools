# Maintainer: Roland Singer <roland@manjaro.org>

pkgname=manjaro-tools
pkgver=20141004
pkgrel=1
pkgdesc='Tools for Manjaro Linux package maintainers'
arch=('any')
license=('GPL')
url='http://git.manjaro.org/core/devtools/'
depends=('namcap' 'openssh' 'subversion' 'rsync')
provides=('devtools')
backup=('etc/devtools/devtools.conf')
source=("git+https://github.com/udeved/manjaro-tools.git")
sha256sums=('SKIP')

pkgver() {
	date +%Y%m%d
}

build() {
	cd ${srcdir}/${pkgname}
	make PREFIX=/usr SYSCONFDIR=/etc
}

package() {
	cd ${srcdir}/${pkgname}
	make SYSCONFDIR=/etc PREFIX=/usr DESTDIR=${pkgdir} install
}
