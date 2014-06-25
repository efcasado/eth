##==============================================================================
## Makefile
##
## A simple Makefile for the eth library
##
## Author: Enrique Fernandez <efcasado@gmail.com>
## Date:   June, 2014
##==============================================================================

# ======================
#  Environment variables
# ======================

# Erlang run-time system
ERL  := $(shell which erl)
# Erlang compiler
ERLC := $(shell which erlc)

# Erlang compiler flags
ERLC_FLAGS := -D EUNIT

# Directory where binary files are stored
BIN_DIR := ebin
# Directory where source files are stored
SRC_DIR := src

# Source files
SRC_FILES := $(notdir $(shell find $(SRC_DIR) -name "*.erl"))
# Binary files
BIN_FILES := $(patsubst %.erl,$(BIN_DIR)/%.beam,$(SRC_FILES))
# Module names
MOD_NAMES = $(basename $(notdir $(shell find $(BIN_DIR) -name "*.beam")))

# Virtual path
VPATH := $(SRC_DIR)


# =======
#  Rules
# =======

.PHONY: test

all: build test

build: pre-build
	@$(foreach bin,$(BIN_FILES),$(MAKE) $(bin))

$(BIN_DIR)/%.beam: %.erl
	@echo "Compiling module '$(notdir $<)'"
	@$(ERLC) $(ERLC_FLAGS) -o $(BIN_DIR) $<

pre-build:
	@mkdir -p $(BIN_DIR)

test: build
	@$(foreach mod,$(MOD_NAMES),$(MAKE) $(mod)_test)

%_test: $(BIN_DIR)/%.beam
	@echo "Running unit tests in '$(basename $(notdir $<))'"
	@$(ERL) -pa $(BIN_DIR) -noshell                                  \
		-eval "eunit:test($(shell echo $@|sed 's|\(.*\)_test|\1|1'), \
		           [verbose])"                                       \
		-eval "halt()"

clean:
	@rm -rf $(BIN_DIR)
