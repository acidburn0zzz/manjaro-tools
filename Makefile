V=0.9.3

PREFIX = $(PREFIX)/local

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
	bin/fstabgen \
	bin/make-set \
	bin/chroot-run \
	bin/mkiso \
	bin/buildiso \
	bin/testiso

SYSCONFIGFILES = \
	conf/manjaro-tools.conf

SETS = \
	sets/default.set

CONFIGFILES = \
	conf/makepkg-i686.conf \
	conf/makepkg-x86_64.conf \
	conf/pacman-default.conf \
	conf/pacman-multilib.conf \
	conf/pacman-mirrors-stable.conf \
	conf/pacman-mirrors-testing.conf \
	conf/pacman-mirrors-unstable.conf
	
LIBS = \
	lib/util.sh \
	lib/util-mount.sh \
	lib/util-msg.sh

CPIOHOOKS = \
	hooks/miso \
	hooks/miso_loop_mnt \
	hooks/miso_pxe_nbd
	
CPIOINST = \
	inst/miso \
	inst/miso_loop_mnt \
	inst/miso_pxe_nbd \
	inst/miso_kms
	
all: $(BINPROGS) #bin/bash_completion bin/zsh_completion

edit = sed -e "s|@pkgdatadir[@]|$(DESTDIR)$(PREFIX)/share/manjaro-tools|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/manjaro-tools|g" \
	-e "s|@libdir[@]|$(DESTDIR)$(PREFIX)/lib/manjaro-tools|g" \
	-e "s|@version@|${V}|"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(edit) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

clean:
	rm -f $(BINPROGS) bin/bash_completion bin/zsh_completion

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
	
	install -dm0755 $(DESTDIR)$(PREFIX)/lib/initcpio/hooks
	install -m0755 ${CPIOHOOKS} $(DESTDIR)$(PREFIX)/lib/initcpio/hooks
	install -dm0755 $(DESTDIR)$(PREFIX)/lib/initcpio/install
	install -m0755 ${CPIOINST} $(DESTDIR)$(PREFIX)/lib/initcpio/install

	#install -Dm0644 bin/bash_completion $(DESTDIR)/$(PREFIX)/share/bash-completion/completions/manjaro_tools
	#install -Dm0644 bin/zsh_completion $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_manjaro_tools
	
	# compat symlink for manjaroiso
	#ln -sf basestrap $(DESTDIR)$(PREFIX)/bin/pacstrap
	#ln -sf fstabgen $(DESTDIR)$(PREFIX)/bin/genfstab
	#ln -sf manjaro-chroot $(DESTDIR)$(PREFIX)/bin/arch-chroot

uninstall:
	for f in ${SYSCONFIGFILES}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/$$f; done
	for f in ${SETS}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/$$f; done
	for f in ${BINPROGS}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${CONFIGFILES}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides
	for f in ${LIBS}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	
	for f in ${CPIOHOOKS}; do rm -f $(DESTDIR)$(PREFIX)/lib/initcpio/hooks/$$f; done
	for f in ${CPIOINST}; do rm -f $(DESTDIR)$(PREFIX)/lib/initcpio/install/$$f; done
	
	#rm $(DESTDIR)/$(PREFIX)/share/bash-completion/completions/manjaro_tools
	#rm $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_manjaro_tools
	
	# compat symlink for manjaroiso
	#rm -f $(DESTDIR)$(PREFIX)/bin/pacstrap
	#rm -f $(DESTDIR)$(PREFIX)/bin/genfstab
	#rm -f $(DESTDIR)$(PREFIX)/bin/arch-chroot

dist:
	git archive --format=tar --prefix=manjaro-tools-$(V)/ $(V) | gzip -9 > manjaro-tools-$(V).tar.gz
	gpg --detach-sign --use-agent manjaro-tools-$(V).tar.gz

.PHONY: all clean install uninstall dist
