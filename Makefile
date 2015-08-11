prefix=/usr/local

install:
	-mkdir $(prefix)/share/mtpm
	-mv mtpm.lua mtpm
	install -m 0755 mtpm $(prefix)/bin
	-mv mtpm mtpm.lua
	install -m 0644 *.lua $(prefix)/share/mtpm

uninstall:
	-rm -f $(prefix)/bin/mtpm
	-rm -rf $(prefix)/share/mtpm

.PHONY: install
