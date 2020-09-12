.PHONY: lint install-local install-global

SRC_FILES := src/*.sh

lint:
	shellcheck $(SRC_FILES)

install-local:
	mkdir -p ${HOME}/bin
	cp src/muximi.sh ${HOME}/bin/muximi
	chmod +x ${HOME}/bin/muximi

install-global:
	cp src/muximi.sh /usr/local/bin/muximi
	chmod +x ${HOME}/bin/muximi
