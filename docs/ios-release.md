# iOS GitHub Releases

Pushing a `v*` tag runs the iOS XCTest suite, archives the iPhone/iPad app, and publishes the signed IPA to a GitHub Release. The workflow does not upload to App Store Connect.

Configure these repository Actions secrets before tagging a release:

- `IOS_DISTRIBUTION_CERTIFICATE_P12_BASE64`: base64 encoded Apple Distribution `.p12` certificate.
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`: password used to export that `.p12`.
- `IOS_APP_STORE_PROFILE_BASE64`: base64 encoded App Store provisioning profile for `com.ca5eelo.traverse` and team `9F946WAJQ7`.

To encode the files on macOS, use `base64 -i certificate.p12 | pbcopy` and `base64 -i Traverse_AppStore.mobileprovision | pbcopy`. Keep the signing files and passwords in Actions secrets; never commit them.
