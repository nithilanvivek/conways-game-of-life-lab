CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Wpedantic
PKGS = gtk+-3.0 json-glib-1.0
PREFIX ?= /usr/local
DATADIR = $(PREFIX)/share
nithi-life: main.c engine.h documents.h patterns.h tour.h
	$(CC) $(CFLAGS) main.c -o $@ $$(pkg-config --cflags --libs $(PKGS)) -lm
install: nithi-life
	./install-local.sh
install-dist: nithi-life
	@test -f packaging/land.nithi.life.metainfo.xml || { echo 'Distribution AppStream metadata is missing.' >&2; exit 1; }
	install -Dm755 nithi-life $(DESTDIR)$(PREFIX)/bin/nithi-life
	install -Dm644 app-icon.png $(DESTDIR)$(DATADIR)/icons/hicolor/256x256/apps/land.nithi.life.png
	install -Dm644 packaging/land.nithi.life.desktop $(DESTDIR)$(DATADIR)/applications/land.nithi.life.desktop
	install -Dm644 packaging/land.nithi.life.metainfo.xml $(DESTDIR)$(DATADIR)/metainfo/land.nithi.life.metainfo.xml
	install -Dm644 ../LICENSE $(DESTDIR)$(DATADIR)/licenses/land.nithi.life/LICENSE
clean:
	rm -f nithi-life
.PHONY: install install-dist clean
