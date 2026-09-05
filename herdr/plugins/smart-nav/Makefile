CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -std=c11

bin/herdr-smart-nav: smart-nav.c
	@mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -rf bin
