.PHONY: run app universal install uninstall clean

# Quick iteration: runs the binary directly, no bundle.
run:
	swift run

# Build ClaudeBuddy.app in ./build
app:
	./Scripts/build-app.sh

universal:
	UNIVERSAL=1 ./Scripts/build-app.sh

install: app
	rm -rf "/Applications/ClaudeBuddy.app"
	cp -R "build/ClaudeBuddy.app" /Applications/
	@echo "installed /Applications/ClaudeBuddy.app"

uninstall:
	rm -rf "/Applications/ClaudeBuddy.app"

clean:
	rm -rf .build build
