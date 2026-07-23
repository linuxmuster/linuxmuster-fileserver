.PHONY: all deb

all: deb

deb:
	dpkg-buildpackage -rfakeroot -tc -sa -us -uc -I".directory" -I".git" -I".omc" -I"buildpackage.sh"
