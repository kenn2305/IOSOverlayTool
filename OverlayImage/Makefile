THEOS_MAKE_PATH ?= $(THEOS)/makefiles
FINAL_PACKAGE = $(THEOS_OBJ_DIR)/OverlayImage.deb

TWEAK_NAME = OverlayImage
OverlayImage_FILES = Tweak.xm OverlayManager.m OverlayWindow.m ImagePickerController.m OverlayView.m
OverlayImage_FRAMEWORKS = UIKit QuartzCore Photos Foundation
OverlayImage_PRIVATE_FRAMEWORKS = GraphicsServices
OverlayImage_CFLAGS = -fobjc-arc -fvisibility=hidden -std=c99
OverlayImage_LDFLAGS = -lSystem

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
