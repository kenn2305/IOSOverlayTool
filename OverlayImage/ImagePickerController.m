#import "ImagePickerController.h"
#import <PhotosUI/PhotosUI.h>
#import <Photos/Photos.h>

@interface ImagePickerController () <PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, weak) UIViewController *presentingVC;
@property (nonatomic, weak) id<ImagePickerControllerDelegate> delegate;
@end

@implementation ImagePickerController

- (instancetype)initWithPresentingViewController:(UIViewController *)vc delegate:(id<ImagePickerControllerDelegate>)delegate {
    if (self = [super init]) {
        _presentingVC = vc;
        _delegate = delegate;
    }
    return self;
}

- (void)present {
    // Request photo library access
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite completionHandler:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusDenied && status != PHAuthorizationStatusRestricted) {
                [self presentPicker];
            } else {
                [self.delegate imagePickerControllerDidCancel];
            }
        });
    }];
}

- (void)presentPicker {
    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = [PHPickerFilter imagesFilter];
        config.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self.presentingVC presentViewController:picker animated:YES completion:nil];
    } else {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.mediaTypes = @[@"public.image"];
        picker.delegate = self;
        [self.presentingVC presentViewController:picker animated:YES completion:nil];
    }
}

#pragma mark - PHPicker Delegate (iOS 14+)
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count == 0) {
        [self.delegate imagePickerControllerDidCancel];
        return;
    }
    
    PHPickerResult *result = results.firstObject;
    
    if ([result.itemProvider canLoadObjectOfClass:[UIImage class]]) {
        __weak typeof(self) weakSelf = self;
        [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading>  _Nullable object, NSError * _Nullable error) {
            UIImage *image = (UIImage *)object;
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.delegate imagePickerControllerDidSelectImage:image identifier:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.delegate imagePickerControllerDidCancel];
                });
            }
        }];
    } else {
        [self.delegate imagePickerControllerDidCancel];
    }
}

#pragma mark - UIImagePickerController Delegate (iOS < 14)
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        [self.delegate imagePickerControllerDidSelectImage:image identifier:nil];
    } else {
        [self.delegate imagePickerControllerDidCancel];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self.delegate imagePickerControllerDidCancel];
}

@end
