V=20141001

PREFIX = /usr/local

BINPROGS = \
	bin/checkpkg \
	bin/manjarobuild \
	bin/lddd \
	bin/finddeps \
	bin/find-libdeps \
	bin/signpkg \
	bin/signpkgs \
	bin/mkmanjaroroot \
	bin/makechrootpkg \
	bin/build-set \
	bin/build-set-helper

SYSCONFIGFILES = \
	conf/devtools.conf

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

all: $(BINPROGS)

edit = sed -e "s|@pkgdatadir[@]|$(DESTDIR)$(PREFIX)/share/devtools|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/devtools|g"

%: bin/%.in Makefile lib/common.sh
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(edit) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

clean:
	rm -f $(BINPROGS)

install:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/devtools
	install -m0644 ${SYSCONFIGFILES} $(DESTDIR)$(SYSCONFDIR)/devtools
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/devtools/sets
	install -m0644 ${SETS} $(DESTDIR)$(SYSCONFDIR)/devtools/sets
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(PREFIX)/share/devtools
	install -m0755 ${BINPROGS} $(DESTDIR)$(PREFIX)/bin
	install -m0644 ${CONFIGFILES} $(DESTDIR)$(PREFIX)/share/devtools
	ln -sf find-libdeps $(DESTDIR)$(PREFIX)/bin/find-libprovides

uninstall:
	for f in ${SYSCONFIGFILES}; do rm -f $(DESTDIR)$(SYSCONFDIR)/devtools/$$f; done
	for f in ${SETS}; do rm -f $(DESTDIR)$(SYSCONFDIR)/devtools/sets/$$f; done
	for f in ${BINPROGS}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${CONFIGFILES}; do rm -f $(DESTDIR)$(PREFIX)/share/devtools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides

dist:
	git archive --format=tar --prefix=devtools-$(V)/ $(V) | gzip -9 > devtools-$(V).tar.gz
	gpg --detach-sign --use-agent devtools-$(V).tar.gz

.PHONY: all clean install uninstall dist
