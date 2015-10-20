#
# Makefile for openstack-install
#
NAME                = openstack
TOPDIR              := $(shell basename `pwd`)
GIT_REV		    := $(shell git log --oneline -n1| cut -d" " -f1)
VERSION             := $(shell ./tools/version)
UPSTREAM_DEB        := https://github.com/Ubuntu-Solutions-Engineering/openstack-installer-deb.git
UPSTREAM_DEB_COMMIT := c21a958
UPSTREAM_MACUMBA    := https://github.com/Ubuntu-Solutions-Engineering/macumba.git
UPSTREAM_MACUMBA_COMMIT := 5674861
UPSTREAM_MAASCLIENT := https://github.com/Ubuntu-Solutions-Engineering/maasclient.git
UPSTREAM_MAASCLIENT_COMMIT := 357db23

.PHONY: install-dependencies
install-dependencies:
	sudo apt-get -yy install devscripts equivs pandoc
	sudo mk-build-deps -i -t "apt-get --no-install-recommends -y" debian/control

.PHONY: uninstall-dependencies
uninstall-dependencies:
	sudo apt-get remove openstack-build-deps

# sudo make uninstall type=single-system
# (or just sudo make uninstall)
.PHONY: uninstall
uninstall: uninstall-dependencies
	sudo tools/openstack-uninstall ${type}

clean:
	@-debian/rules clean
	@rm -rf debian/cloud-install*
	@rm -rf docs/_build/*
	@rm -rf mockcfgpath
	@rm -rf ../openstack_*.deb ../cloud-*.deb ../openstack_*.tar.gz ../openstack_*.dsc ../openstack_*.changes \
		../openstack_*.build ../openstack-*.deb ../openstack_*.upload ../cloud-install-*.deb
	@rm -rf cover
	@rm -rf .coverage
	@rm -rf .tox

DPKGBUILDARGS = -us -uc -i'.git.*|.tox|.bzr.*|.editorconfig|.travis-yaml|macumba\/debian|maasclient\/debian'
deb-src: clean update_version
	@dpkg-buildpackage -S -sa $(DPKGBUILDARGS)

deb-release:
	@dpkg-buildpackage -S -sd $(DPKGBUILDARGS)

deb: clean update_version man-pages
	@dpkg-buildpackage -b $(DPKGBUILDARGS)

man-pages:
	@pandoc -s docs/openstack-juju.rst -t man -o man/en/openstack-juju.1
	@pandoc -s docs/openstack-status.rst -t man -o man/en/openstack-status.1
	@pandoc -s docs/openstack-install.rst -t man -o man/en/openstack-install.1
	@pandoc -s docs/openstack-uninstall.rst -t man -o man/en/openstack-uninstall.1
	@pandoc -s docs/openstack-config.md -t man -o man/en/openstack-config.5

current_version:
	@echo $(VERSION)

git-sync-requirements:
	@echo Syncing git repos
	rm -rf tmp && mkdir -p tmp
	rm -rf debian
	rm -rf macumba
	rm -rf maasclient
	git clone -q $(UPSTREAM_DEB) tmp/debian
	git clone -q $(UPSTREAM_MACUMBA) tmp/macumba
	git clone -q $(UPSTREAM_MAASCLIENT) tmp/maasclient
	(cd tmp/debian && git checkout -f $(UPSTREAM_DEB_COMMIT))
	(cd tmp/maasclient && git checkout -f $(UPSTREAM_MAASCLIENT_COMMIT))
	(cd tmp/macumba && git checkout -f $(UPSTREAM_MACUMBA_COMMIT))
	rsync -az --delete tmp/debian/debian .
	rsync -az --delete tmp/macumba/macumba .
	rsync -az --delete tmp/maasclient/maasclient .
	rm -rf tmp

git_rev:
	@echo $(GIT_REV)

update_version:
	wrap-and-sort
	@sed -i -r "s/(^__version__\s=\s)(.*)/\1\"$(VERSION)\"/" cloudinstall/__init__.py

.PHONY: ci-test pyflakes pep8 test travis-test
ci-test: pyflakes pep8 travis-test

pyflakes:
	python3 `which pyflakes` cloudinstall test bin

pep8:
	pep8 cloudinstall test bin

$(HOME)/.cloud-install:
	mkdir -p $(HOME)/.cloud-install

NOSE_ARGS = -v --with-cover --cover-package=cloudinstall --cover-html test --cover-inclusive cloudinstall
test: $(HOME)/.cloud-install tox

travis-test: $(HOME)/.cloud-install
	nosetests $(NOSE_ARGS)

tox: $(HOME)/.cloud-install
	@tox

status:
	PYTHONPATH=$(shell pwd):$(PYTHONPATH) bin/openstack-status

# Indirection to allow 'make run' to build deb automatically, but
# 'make sbuild; make run' will not invoke 'deb'.
../openstack*.deb: deb
	echo "rule to make .deb automatically"

.PHONY: install
install: ../openstack*.deb
	-dpkg -i ../openstack_*deb
	-dpkg -i ../openstack-${type}*deb
	apt-get -yy install -f


# sudo make run type=multi proxy=http://localhost:3128/
.PHONY: run
run: install
	MAAS_HTTP_PROXY=${proxy} openstack-install

# sudo make landscape
.PHONY: landscape
landscape: ../openstack*.deb
	-dpkg -i ../openstack*deb
	-dpkg -i ../openstack-multi*deb
	-dpkg -i ../openstack-landscape*deb
	apt-get -yy install -f
	@echo please follow the instructions in
	@echo "/usr/share/openstack/templates/landscape-deployments.yaml"
	@echo and then run `sudo openstack-install` as usual


all: deb
