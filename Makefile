BUILD_DIR=./build

.PHONY: build
build: clean
		mkdir -p $(BUILD_DIR)

.PHONY: deb
deb:
		rm -f $(BUILD_DIR)/ovh-rtm-binaries*.deb
		mkdir -p $(BUILD_DIR)
		fpm -m "<alexis.autret@ovhcloud.com>"\
			--description "ovh real time monitoring. This package provide OVH Real Times Monitoring scripts." \
			--url "https://docs.ovh.com/gb/en/dedicated/install-rtm/" \
			--license "BSD-3-Clause" \
			--version $(shell echo $$(git for-each-ref --sort=taggerdate --format '%(refname) %(taggerdate)' refs/tags | tail -n 1 | awk '{print $$1}' | sed 's/refs\/tags\///')-$$(lsb_release  -cs)) \
            -n ovh-rtm-binaries \
			-d 'smartmontools' \
			-d 'hddtemp' \
			-d 'dmidecode' \
			-d 'util-linux' \
			-d 'sg3-utils' \
			-d 'lsscsi' \
			-d 'sysstat' \
            -d 'lsb-release' \
			-s dir -t deb \
			--vendor "ovh" \
			-a all \
			--after-install deb/after-install.sh \
			-p ./build \
			--inputs deb/input \
			--deb-no-default-config-files

.PHONY: rpm
rpm:
		rm -f $(BUILD_DIR)/ovh-rtm-binaries*.rpm
		mkdir -p $(BUILD_DIR)
		fpm -m "<alexis.autret@ovhcloud.com>"\
			--description "ovh real time monitoring. This package provide OVH Real Times Monitoring scripts." \
			--url "https://docs.ovh.com/gb/en/dedicated/install-rtm/" \
			--license "BSD-3-Clause" \
			--version $(shell git for-each-ref --sort=taggerdate --format '%(refname) %(taggerdate)' refs/tags | tail -n 1 | awk '{print $$1}' | sed 's/refs\/tags\///') \
			-n ovh-rtm-binaries \
			-d 'smartmontools' \
			-d 'dmidecode' \
			-d 'util-linux' \
			-d 'sg3_utils' \
			-d 'lsscsi' \
			-d 'sysstat' \
            -d 'redhat-lsb'\
			--vendor "ovh" \
			--rpm-os "linux" \
			-a all \
			--after-install deb/after-install.sh \
			-p ./build \
			--inputs deb/input \
			-s dir -t rpm

.PHONY: clean
clean:
		rm -rf build
		rm -f *.deb
		rm -f *.rpm
