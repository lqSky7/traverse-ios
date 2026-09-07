# Traverse iOS Root

| File | Description | Key Types & Symbols |
| :--- | :--- | :--- |
| `traverseApp.swift` | Application entry point configuring environment objects and main scene | `struct traverseApp: App` |
| `ContentView.swift` | Root view router checking auth state to show onboarding or main tabs | `struct ContentView: View` |
| `OnboardingFlow.swift` | Multi-step onboarding experience and orientation for new users | `struct OnboardingFlow: View` |
| `Info.plist` | Application bundle metadata and capability definitions | Configuration property list |
| `traverse.entitlements` | App entitlements for iCloud, App Groups, and authentication | Security entitlements |
