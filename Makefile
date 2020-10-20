.PHONY: all

all:
	tar czf ../Jenkinsfile-example.tar.gz .*ignore .ruby-version Dockerfile Jenkinsfile jenkins/ lib/tasks/ci.rake Makefile.txt
