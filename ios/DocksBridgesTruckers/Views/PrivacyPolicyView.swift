import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy Policy")
                        .font(.largeTitle.bold())
                    Text("Last updated: \(formattedDate)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                policySection(
                    title: "Overview",
                    body: "Docks & Bridges Trucker is designed with your privacy in mind. We do not collect, store, or share any personal information. Your data stays on your device."
                )

                policySection(
                    title: "Data We Do Not Collect",
                    body: "We do not collect names, email addresses, phone numbers, location history, usage analytics, or any other personally identifiable information. No account creation is required to use this app."
                )

                policySection(
                    title: "On-Device Storage",
                    body: "Your truck profile (vehicle name, dimensions, weight, and plate number) is stored locally on your device using standard iOS storage. This data never leaves your device and is not transmitted to any server."
                )

                policySection(
                    title: "Location Services",
                    body: "The app may request access to your location to show nearby hazards, docks, and to calculate routes. Location data is processed on-device and is not collected, stored, or shared with any third party."
                )

                policySection(
                    title: "Third-Party Services",
                    body: "The app uses Apple Maps for mapping and route calculation. Apple's own privacy policy governs their handling of map data. We do not integrate any third-party analytics, advertising, or tracking services."
                )

                policySection(
                    title: "Widgets",
                    body: "The app includes an optional home screen widget that displays hazard information. Widget data is shared between the app and widget using on-device App Groups and is never transmitted externally."
                )

                policySection(
                    title: "Children's Privacy",
                    body: "This app does not knowingly collect any information from children under 13. Since we do not collect data from any user, no special provisions are necessary."
                )

                policySection(
                    title: "Changes to This Policy",
                    body: "We may update this privacy policy from time to time. Any changes will be reflected in the app with an updated date. Continued use of the app constitutes acceptance of the updated policy."
                )

                policySection(
                    title: "Contact",
                    body: "If you have questions about this privacy policy, contact us at support@docksbridgestruckers.com."
                )

                Text("© \(Calendar.current.component(.year, from: Date())) Docks & Bridges Trucker. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedDate: String {
        "1 April 2025"
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
