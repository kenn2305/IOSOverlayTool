export ARCHS = arm64
export TARGET = iphone:clang:latest:15.0

THEOS_MAKE_PATH ?= $(THEOS)/makefiles

TWEAK_NAME = OverlayImage
OverlayImage_FILES = Tweak.xm OverlayManager.m OverlayWindow.m ImagePickerController.m OverlayView.m
OverlayImage_FRAMEWORKS = UIKit QuartzCore Photos Foundation
OverlayImage_PRIVATE_FRAMEWORKS = GraphicsServices
OverlayImage_CFLAGS = -fobjc-arc -fvisibility=hidden -Wno-deprecated-declarations
OverlayImage_LDFLAGS = -lSystem

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
