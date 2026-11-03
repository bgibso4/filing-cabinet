import Core
import TestSupport
import Testing

@Test(arguments: [CameraAuthorization.authorized, .notDetermined, .denied])
func fakeReportsItsStatus(_ status: CameraAuthorization) {
    let access: any CameraAccess = FakeCameraAccess(status: status, grantsOnRequest: false)
    #expect(access.status == status)
}

@Test(arguments: [true, false])
func fakeAnswersRequestsAsScripted(_ grants: Bool) async {
    let access: any CameraAccess = FakeCameraAccess(status: .notDetermined, grantsOnRequest: grants)
    #expect(await access.requestAccess() == grants)
}
