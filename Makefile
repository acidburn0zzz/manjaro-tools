V=20141005

PREFIX = /usr/local

BINPROGS = \
	bin/checkpkg \
	bin/lddd \
	bin/finddeps \
	bin/find-libdeps \
	bin/signpkg \
	bin/signpkgs \
	bin/mkchroot \
	bin/mkchrootpkg \
	bin/build-set \
	bin/basestrap \
	bin/manjaro-chroot \
	bin/fstabgen

SYSCONFIGFILES = \
	conf/manjaro-tools.conf

SETS = \
	sets/default.set \
	sets/udev.set \
	sets/nosystemd.set \
	sets/openrc.set \
	sets/openrc-nodeps.set

CONFIGFILES = \
	conf/makepkg-i686.conf \
	conf/makepkg-x86_64.conf \
	conf/pacman-default.conf \
	conf/pacman-mirrors.conf \
	conf/pacman-multilib.conf
LIBS = \
	lib/functions.sh

all: $(BINPROGS)

edit = sed -e "s|@pkgdatadir[@]|$(DESTDIR)$(PREFIX)/share/manjaro-tools|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/manjaro-tools|g" \
	-e "s|@libdir[@]|$(DESTDIR)$(PREFIX)/lib/manjaro-tools|g"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(edit) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

clean:
	rm -f $(BINPROGS)

install:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools
	install -m0644 ${SYSCONFIGFILES} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets
	install -m0644 ${SETS} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0755 ${BINPROGS} $(DESTDIR)$(PREFIX)/bin
	install -m0644 ${CONFIGFILES} $(DESTDIR)$(PREFIX)/share/manjaro-tools
	ln -sf find-libdeps $(DESTDIR)$(PREFIX)/bin/find-libprovides
	install -m0644 ${LIBS} $(DESTDIR)$(PREFIX)/lib/manjaro-tools

uninstall:
	for f in ${SYSCONFIGFILES}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/$$f; done
	for f in ${SETS}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/$$f; done
	for f in ${BINPROGS}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${CONFIGFILES}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides
	for f in ${LIBS}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done

dist:
	git archive --format=tar --prefix=manjaro-tools-$(V)/ $(V) | gzip -9 > manjaro-tools-$(V).tar.gz
	gpg --detach-sign --use-agent manjaro-tools-$(V).tar.gz

.PHONY: all clean install uninstall dist
