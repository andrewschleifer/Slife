SOURCE={*/,}*.{h,m}
APP=Slife
DATE=`date +%Y.%m.%d`
BUILD=`git log --oneline | wc -l`
COMMIT=`git rev-parse --verify HEAD`

DEFAULT: debug

debug: debug-build
	./build/Debug/$(APP).app/Contents/MacOS/$(APP)
debug-build: $(SOURCE)
	xcodebuild -configuration Debug build OBJROOT=build SYMROOT=build

release: release-app
	git tag -a $(DATE) -m"$(DATE)"
	cd build/Release && zip -9r ../../$(APP)-$(DATE).zip $(APP).app
release-app: release-build
	/usr/libexec/PlistBuddy \
		-c "Set :CFBundleShortVersionString $(DATE)" \
		-c "Set :CFBundleGitVersionString $(COMMIT)" \
		-c "Set :CFBundleVersion $(BUILD)" \
		build/Release/$(APP).app/Contents/Info.plist
release-build: $(SOURCE)
	xcodebuild -configuration Release build OBJROOT=build SYMROOT=build

clobber:
	rm -r build

