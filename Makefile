DESTINATION=$(HOME)/.purple/plugins/hipchat-helper.pl

all:

install: $(DESTINATION)

$(DESTINATION): hipchat-helper.pl
	install $< $@
