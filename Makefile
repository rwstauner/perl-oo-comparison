DIR=.build
SHELL=/bin/bash

all: clean
	perl generate-scripts.pl
clean:
	if [[ -d $(DIR) ]]; then \
		rm $(DIR)/*.pl; \
		rmdir $(DIR); \
	fi

.PHONY: deps
deps:
	perl -ne 'eval "require $$_" or print;' < deps

run:
	for i in $(DIR)/*.pl; { perl $$i; }
