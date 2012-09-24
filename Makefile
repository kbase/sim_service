TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

MOD = SimService
LDIR = lib/Bio/KBase/$(MOD)
DEPS = $(LDIR)/Impl.pm $(LDIR)/Service.pm $(LDIR)/Client.pm

all: $(DEPS) bin

deploy: $(DEPS) deploy-scripts deploy-libs

$(DEPS): $(SPEC)
	compile_typespec \
	--impl Bio::KBase::$(MOD)::Impl.pm
	--service Bio::KBase::$(MOD)::Service.pm
	--psgi $(MOD).psgi
	--client Bio::KBase::$(MOD)::Client.pm
	--js $(MOD).js
	--py $(MOD).py
	.

bin: $(BIN_PERL)

include $(TOP_DIR)/tools/Makefile.common.rules
