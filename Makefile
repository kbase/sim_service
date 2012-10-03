TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

SPEC = sim.spec
MOD = SimService
LDIR = lib/Bio/KBase/$(MOD)
DEPS = $(LDIR)/Impl.pm $(LDIR)/Service.pm $(LDIR)/Client.pm

all: $(DEPS) bin

deploy: $(DEPS) deploy-scripts deploy-libs

$(DEPS): $(SPEC)
	compile_typespec \
		--impl Bio::KBase::$(MOD)::Impl \
		--service Bio::KBase::$(MOD)::Service \
		--psgi $(MOD).psgi \
		--client Bio::KBase::$(MOD)::Client \
		--js $(MOD) \
		--py $(MOD) \
		--scripts tscripts \
		$(SPEC) \
		lib

bin: $(BIN_PERL)

include $(TOP_DIR)/tools/Makefile.common.rules
