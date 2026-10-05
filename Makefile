# This repo IS the installed plugin (lives in ~/.config/omarchy/plugins/io.github.sspaeti.battery).
# Omarchy hot-reloads most edits; Panel.qml changes need a shell restart.

.PHONY: reload test install-system status validate

## Restart the omarchy shell to pick up Panel.qml edits
reload:
	omarchy restart shell

## Run the Model.js unit tests
test:
	node test/model.test.js
	./test/status.test.sh

## Install root helper + sudoers + boot service (TUXEDO only, needs sudo)
install-system:
	sudo ./install-system.sh

## Print what the panel reads: profile, display cap, cycles, health
status:
	./charging-status.sh

## Validate manifest against the Omarchy plugin schema
validate:
	omarchy plugin validate .
