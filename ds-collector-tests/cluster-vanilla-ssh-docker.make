
all: setup test teardown


test:
	# ds-collector over SSH
	docker exec -t ds-collector-tests_bastion_1 /collector/ds-collector -T -f /ds-collector-tests/test-collector-ssh.conf -n ds-collector-tests_cassandra-00_1
	docker exec -t ds-collector-tests_bastion_1 /collector/ds-collector -T -p -f /ds-collector-tests/test-collector-ssh.conf -n ds-collector-tests_cassandra-00_1
	docker exec -t ds-collector-tests_bastion_1 /collector/ds-collector -X -f /ds-collector-tests/test-collector-ssh.conf -n ds-collector-tests_cassandra-00_1
	# test archives exist
	if ! ( docker exec ds-collector-tests_bastion_1 ls /tmp/datastax/ ) | grep -q ".tar.gz" ; then echo "Failed to generate artefacts in the SSH cluster" ; ( docker exec ds-collector-tests_bastion_1 ls /tmp/datastax/ ) ; exit 1 ; fi
	# ds-collector over SSH with verbose mode
	docker exec -t ds-collector-tests_bastion_1 /collector/ds-collector -v -T -f /ds-collector-tests/test-collector-ssh.conf -n ds-collector-tests_cassandra-00_1
	docker exec -t ds-collector-tests_bastion_1 /collector/ds-collector -v -T -p -f /ds-collector-tests/test-collector-ssh.conf -n ds-collector-tests_cassandra-00_1
	docker exec -t ds-collector-tests_bastion_1 /collector/ds-collector -v -X -f /ds-collector-tests/test-collector-ssh.conf -n ds-collector-tests_cassandra-00_1
	# test archives exist
	if ! ( docker exec ds-collector-tests_bastion_1 ls /tmp/datastax/ ) | grep -q ".tar.gz" ; then echo "Failed to generate artefacts in the SSH cluster" ; ( docker exec ds-collector-tests_bastion_1 ls /tmp/datastax/ ) ; exit 1 ; fi
	# ds-collector over docker
	./collector/ds-collector -T -f test-collector-docker.conf -n ds-collector-tests_cassandra-00_1
	./collector/ds-collector -T -p -f test-collector-docker.conf -n ds-collector-tests_cassandra-00_1
	./collector/ds-collector -X -f test-collector-docker.conf -n ds-collector-tests_cassandra-00_1
	# test archives exist
	if ! ls /tmp/datastax/ | grep -q ".tar.gz" ; then echo "Failed to generate artefacts in the docker cluster " ; ls -l /tmp/datastax/ ; exit 1 ; fi
	

setup:
	mkdir -p /tmp/datastax && rm -fr /tmp/datastax/* ../ds-collector.TEST-cluster-vanilla-ssh-docker-*.tar.gz TEST-cluster-vanilla-ssh-docker-*_secret.key
	# make diagnostics bundle
	cd ../ ; ISSUE="TEST-cluster-vanilla-ssh-docker-$$(git rev-parse --abbrev-ref HEAD)--$$(git rev-parse --short HEAD)" make
	tar -xvf ../ds-collector.TEST-cluster-vanilla-ssh-docker-*.tar.gz
	rm collector/collector.conf
	cp TEST-cluster-vanilla-ssh-docker-*_secret.key collector/ || true
	test -f collector/collect-info
	# setup docker cluster and bastion
	docker-compose up --build -d
	docker-compose ps
	while (! docker-compose ps | grep -q "ds-collector-tests_cassandra-02_1") || docker-compose ps | grep -q "Up (health: starting)" || docker-compose ps | grep -q "Exit" ; do docker-compose ps ; echo "waiting 60s…" ; sleep 60 ; done

	# verify sshd and open CQL ports
	docker exec -t ds-collector-tests_cassandra-00_1 bash -c 'pgrep sshd 2>&1 > /dev/null && echo "SSHd is running" || echo "SSHd is not running"'
	docker exec -t ds-collector-tests_cassandra-00_1 bash -c 'ps aux | grep cassandra | grep -v grep 2>&1 > /dev/null && echo "Cassandra is running" || echo "Cassandra is not running"'

	docker exec -t ds-collector-tests_cassandra-01_1 bash -c 'pgrep sshd 2>&1 > /dev/null && echo "SSHd is running" || echo "SSHd is not running"'
	docker exec -t ds-collector-tests_cassandra-01_1 bash -c 'ps aux | grep cassandra | grep -v grep 2>&1 > /dev/null && echo "Cassandra is running" || echo "Cassandra is not running"'

	docker exec -t ds-collector-tests_cassandra-02_1 bash -c 'pgrep sshd 2>&1 > /dev/null && echo "SSHd is running" || echo "SSHd is not running"'
	docker exec -t ds-collector-tests_cassandra-02_1 bash -c 'ps aux | grep cassandra | grep -v grep 2>&1 > /dev/null && echo "Cassandra is running" || echo "Cassandra is not running"'

teardown:
	docker-compose down
