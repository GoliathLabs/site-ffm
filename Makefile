GLUON_BUILD_DIR := gluon-build
GLUON_GIT_URL := https://github.com/GoliathLabs/gluon.git
GLUON_GIT_REF := 121515b1aa66c73bbddd2ade15afa66400fd1c92

PATCH_DIR := ${GLUON_BUILD_DIR}/site/patches
SECRET_KEY_FILE ?= ${HOME}/.gluon-secret-key

GLUON_TARGETS ?= \
	ramips-mt7621


GLUON_AUTOUPDATER_BRANCH := next

ifneq (,$(shell git describe --exact-match --tags 2>/dev/null))
	GLUON_AUTOUPDATER_ENABLED := 1
	GLUON_RELEASE := $(shell git describe --tags 2>/dev/null)
else
	GLUON_AUTOUPDATER_ENABLED := 0
	EXP_FALLBACK = $(shell date '+%Y%m%d%H')
	BUILD_NUMBER ?= $(EXP_FALLBACK)
	GLUON_RELEASE := $(shell git describe --tags | cut -d- -f1)~next$(BUILD_NUMBER)
endif

JOBS ?= $(shell cat /proc/cpuinfo | grep processor | wc -l)

GLUON_MAKE := ${MAKE} -j ${JOBS} -C ${GLUON_BUILD_DIR} \
	GLUON_RELEASE=${GLUON_RELEASE} \
	GLUON_AUTOUPDATER_BRANCH=${GLUON_AUTOUPDATER_BRANCH} \
	GLUON_AUTOUPDATER_ENABLED=${GLUON_AUTOUPDATER_ENABLED}

all: info
	${MAKE} manifest

info:
	@echo
	@echo '#########################'
	@echo '# FFMUC Firmware build'
	@echo '# Building release ${GLUON_RELEASE} for branch ${GLUON_AUTOUPDATER_BRANCH}'
	@echo

build: gluon-prepare
	for target in ${GLUON_TARGETS}; do \
		echo ""Building target $$target""; \
		${GLUON_MAKE} download all GLUON_TARGET="$$target"; \
	done

manifest: build
	${GLUON_MAKE} manifest
	mv ${GLUON_BUILD_DIR}/output .

sign: manifest
	${GLUON_BUILD_DIR}/contrib/sign.sh ${SECRET_KEY_FILE} output/images/sysupgrade/${GLUON_AUTOUPDATER_BRANCH}.manifest

${GLUON_BUILD_DIR}:
	git clone ${GLUON_GIT_URL} ${GLUON_BUILD_DIR}

gluon-prepare: output-clean ${GLUON_BUILD_DIR}
	cd ${GLUON_BUILD_DIR} \
		&& git remote set-url origin ${GLUON_GIT_URL} \
		&& git fetch origin \
		&& rm -rf packages \
		&& git checkout -q --force ${GLUON_GIT_REF} \
		&& git clean -fd;
	ln -sfT .. ${GLUON_BUILD_DIR}/site
	make gluon-patch
	${GLUON_MAKE} update

gluon-patch:
	echo "Applying Patches ..."
	(cd ${GLUON_BUILD_DIR})
			if [ `git branch --list patched` ]; then \
				(git branch -D patched) \
			fi
	(cd ${GLUON_BUILD_DIR}; git checkout -B patching)
	if [ -d "gluon-build/site/patches" -a "gluon-build/site/patches/*.patch" ]; then \
		(cd ${GLUON_BUILD_DIR}; git apply --ignore-space-change --ignore-whitespace --whitespace=nowarn --verbose site/patches/*.patch) || ( \
			cd ${GLUON_BUILD_DIR}; \
			git clean -fd; \
			git checkout -B patched; \
			git branch -D patching; \
			exit 1 \
		) \
	fi
	(cd ${GLUON_BUILD_DIR}; git branch -M patched)

gluon-clean:
	rm -rf ${GLUON_BUILD_DIR}

output-clean:
	rm -rf output

clean: gluon-clean output-clean
