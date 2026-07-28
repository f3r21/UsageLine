APP_NAME := UsageLine
BUNDLE   := $(APP_NAME).app
EXEC     := .build/release/$(APP_NAME)
SOURCES  := $(shell find Sources -name '*.swift')

.PHONY: build run install clean dmg install-hook uninstall-hook

build: $(BUNDLE)

$(BUNDLE): $(EXEC) Info.plist
	@rm -rf $(BUNDLE)
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	@cp $(EXEC) $(BUNDLE)/Contents/MacOS/
	@cp Info.plist $(BUNDLE)/Contents/
	@cp scripts/statusline-indicator.sh scripts/install-hook.sh $(BUNDLE)/Contents/Resources/
	@chmod +x $(BUNDLE)/Contents/Resources/statusline-indicator.sh $(BUNDLE)/Contents/Resources/install-hook.sh
	@codesign --force --deep --sign - $(BUNDLE)
	@touch $(BUNDLE)
	@echo "Built and signed $(BUNDLE)"

$(EXEC): $(SOURCES) Package.swift
	swift build -c release

# UsageLine installs the hook and quits immediately — there's no persistent
# process to kill before reopening it.
run: build
	open $(BUNDLE)

install: build
	@rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	@echo "Installed to /Applications/$(BUNDLE)"

dmg: build
	@echo "Creating DMG package..."
	@rm -rf dmg_staging $(APP_NAME).dmg
	@mkdir -p dmg_staging
	@cp -R $(BUNDLE) dmg_staging/
	@ln -s /Applications dmg_staging/Applications
	@cp scripts/install.command "dmg_staging/Install $(APP_NAME).command"
	@chmod +x "dmg_staging/Install $(APP_NAME).command"
	@hdiutil create -volname "$(APP_NAME)" -srcfolder dmg_staging -ov -format UDZO $(APP_NAME).dmg
	@rm -rf dmg_staging
	@echo "Created $(APP_NAME).dmg successfully!"

clean:
	swift package clean
	rm -rf $(BUNDLE) .build $(APP_NAME).dmg dmg_staging

# Installs just the statusLine hook (bash + jq, no app/Xcode/Swift needed).
install-hook:
	@./scripts/install-hook.sh

uninstall-hook:
	@./scripts/uninstall-hook.sh
