TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

DEPLOY_RUNTIME ?= /kb/runtime

SERVER_SPEC = sim.spec
SERVICE = sim_service
SERVICE_PORT = 7055

MOD = SimService
LDIR = lib/Bio/KBase/$(MOD)
DEPS = $(LDIR)/Impl.pm $(LDIR)/Service.pm $(LDIR)/Client.pm

TPAGE_ARGS = --define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT)

CLIENT_TESTS = $(wildcard t/client-tests/*.t)

all: $(DEPS) bin build-docs

test: test-client
	echo "running client and script tests"

# What does it mean to test a client. This is a test of a client
# library. If it is a client-server module, then it should be
# run against a running server. You can say that this also tests
# the server, and I agree. You can add a test-server dependancy
# to the test-client target if it makes sense to you. This test
# example assumes there is already a tested running server.
test-client:
	# run each test
	for t in $(CLIENT_TESTS) ; do \
		if [ -f $$t ] ; then \
			$(DEPLOY_RUNTIME)/bin/perl $$t ; \
			if [ $$? -ne 0 ] ; then \
				exit 1 ; \
			fi \
		fi \
	done

deploy-all: deploy
deploy: $(DEPS) deploy-scripts deploy-libs deploy-docs deploy-service

deploy-client: $(DEPS) deploy-scripts deploy-libs deploy-docs
deploy-service: $(DEPS) deploy-dir-service deploy-services deploy-monit

$(DEPS): $(SERVER_SPEC)
	mkdir -p tscripts
	compile_typespec \
		--impl Bio::KBase::$(MOD)::Impl \
		--service Bio::KBase::$(MOD)::Service \
		--psgi $(MOD).psgi \
		--client Bio::KBase::$(MOD)::Client \
		--js $(MOD) \
		--scripts tscripts \
		$(SERVER_SPEC) \
		lib

bin: $(BIN_PERL)

deploy-services:
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(SERVICE_DIR)/start_service
	chmod +x $(SERVICE_DIR)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(SERVICE_DIR)/stop_service
	chmod +x $(SERVICE_DIR)/stop_service

deploy-monit:
	$(TPAGE) $(TPAGE_ARGS) service/process.$(SERVICE).tt > $(SERVICE_DIR)/process.$(SERVICE)


build-docs: docs/$(SERVICE).html

docs/$(SERVICE).html: $(DEPS)
	mkdir -p docs
	pod2html -t "Similarity Service API" --infile=$(LDIR)/Client.pm --outfile=docs/$(SERVICE).html
	rm -f pod2htmd.tmp

deploy-docs: build-docs
	mkdir -p $(SERVICE_DIR)/webroot
	cp docs/*.html $(SERVICE_DIR)/webroot/.
	

include $(TOP_DIR)/tools/Makefile.common.rules


