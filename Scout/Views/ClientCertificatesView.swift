//
//  ClientCertificatesView.swift
//  Scout
//
//  UI for managing client certificates
//

import SwiftUI

struct ClientCertificatesView: View {
    @Bindable var manager: ClientCertificateManager
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSheet = false
    @State private var showDeleteConfirmation = false
    @State private var certificateToDelete: ClientCertificate?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        List {
            if manager.certificates.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.key")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Client Certificates")
                            .font(.headline)
                        Text("Client certificates are used to authenticate with Gemini capsules that require identity verification.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach(manager.certificates) { certificate in
                        NavigationLink {
                            ClientCertificateDetailView(
                                certificate: certificate,
                                manager: manager
                            )
                        } label: {
                            CertificateRow(certificate: certificate)
                        }
                    }
                    .onDelete(perform: confirmDelete)
                } header: {
                    Text("Certificates")
                } footer: {
                    Text("Swipe left to delete a certificate.")
                }
            }

            Section {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("Create New Certificate", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Client Certificates")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateSheet) {
            CreateClientCertificateView(manager: manager)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Delete Certificate?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                certificateToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let cert = certificateToDelete {
                    deleteCertificate(cert)
                }
            }
        } message: {
            if let cert = certificateToDelete {
                Text("This will delete \"\(cert.name)\" and remove all its site associations. This cannot be undone.")
            }
        }
    }

    private func confirmDelete(at offsets: IndexSet) {
        if let index = offsets.first {
            certificateToDelete = manager.certificates[index]
            showDeleteConfirmation = true
        }
    }

    private func deleteCertificate(_ certificate: ClientCertificate) {
        do {
            try manager.deleteCertificate(id: certificate.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        certificateToDelete = nil
    }
}

struct CertificateRow: View {
    let certificate: ClientCertificate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(certificate.name)
                    .font(.headline)
                if certificate.isExpired {
                    Text("Expired")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red)
                        .cornerRadius(4)
                } else if certificate.daysUntilExpiry < 30 {
                    Text("\(certificate.daysUntilExpiry)d")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange)
                        .cornerRadius(4)
                }
            }

            Text(truncatedFingerprint(certificate.fingerprint))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
        }
        .padding(.vertical, 2)
    }

    private func truncatedFingerprint(_ fingerprint: String) -> String {
        let parts = fingerprint.split(separator: ":")
        if parts.count > 8 {
            return parts.prefix(4).joined(separator: ":") + "..." + parts.suffix(4).joined(separator: ":")
        }
        return fingerprint
    }
}

struct ClientCertificateDetailView: View {
    let certificate: ClientCertificate
    @Bindable var manager: ClientCertificateManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showError = false

    var associations: [CertificateHostAssociation] {
        manager.getAssociationsForCertificate(id: certificate.id)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: certificate.name)
                LabeledContent("Created", value: certificate.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Expires", value: certificate.expiresAt.formatted(date: .abbreviated, time: .shortened))

                if certificate.isExpired {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("This certificate has expired")
                            .foregroundStyle(.red)
                    }
                } else if certificate.daysUntilExpiry < 30 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Expires in \(certificate.daysUntilExpiry) days")
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Certificate Info")
            }

            Section {
                Text(certificate.fingerprint)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("SHA-256 Fingerprint")
            } footer: {
                Text("This fingerprint uniquely identifies your certificate.")
            }

            Section {
                if associations.isEmpty {
                    Text("No sites are using this certificate")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(associations) { assoc in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(assoc.host):\(assoc.port)")
                                .font(.body)
                            Text(assoc.pathPrefix)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteAssociation)
                }
            } header: {
                Text("Associated Sites")
            } footer: {
                if !associations.isEmpty {
                    Text("Swipe left to remove a site association.")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Certificate", systemImage: "trash")
                }
            }
        }
        .navigationTitle(certificate.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Certificate?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCertificate()
            }
        } message: {
            Text("This will delete \"\(certificate.name)\" and remove all its site associations. This cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private func deleteAssociation(at offsets: IndexSet) {
        for index in offsets {
            let assoc = associations[index]
            manager.removeAssociation(host: assoc.host, port: assoc.port, pathPrefix: assoc.pathPrefix)
        }
    }

    private func deleteCertificate() {
        do {
            try manager.deleteCertificate(id: certificate.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct CreateClientCertificateView: View {
    @Bindable var manager: ClientCertificateManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Certificate Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isCreating)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Choose a name to identify this certificate (e.g., \"Personal\", \"BBS Account\").")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("EC P-256 Key", systemImage: "key")
                        Label("SHA-256 Signatures", systemImage: "signature")
                        Label("Valid for 1 year", systemImage: "calendar")
                        Label("Stored in Keychain", systemImage: "lock.shield")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Certificate Details")
                }
            }
            .navigationTitle("New Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            createCertificate()
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func createCertificate() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true

        Task {
            do {
                _ = try manager.createCertificate(name: trimmedName)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Certificate Selection View (for status 60 prompts)

struct CertificateSelectionView: View {
    @Bindable var manager: ClientCertificateManager
    let url: String
    let serverMessage: String
    let onSelect: (UUID) -> Void
    let onCancel: () -> Void

    @State private var showCreateSheet = false
    @State private var selectedCertificateId: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header info
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)

                    Text("Certificate Required")
                        .font(.headline)

                    if !serverMessage.isEmpty {
                        Text(serverMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let urlHost = URL(string: url)?.host {
                        Text(urlHost)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                .padding()

                Divider()

                // Certificate list
                List {
                    if manager.certificates.isEmpty {
                        Section {
                            Text("No certificates available. Create one to continue.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            ForEach(manager.certificates) { cert in
                                Button {
                                    selectedCertificateId = cert.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cert.name)
                                                .foregroundStyle(.primary)
                                            Text(truncatedFingerprint(cert.fingerprint))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fontDesign(.monospaced)
                                        }
                                        Spacer()
                                        if selectedCertificateId == cert.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .disabled(cert.isExpired)
                                .opacity(cert.isExpired ? 0.5 : 1.0)
                            }
                        } header: {
                            Text("Select Certificate")
                        }
                    }

                    Section {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("Create New Certificate", systemImage: "plus.circle")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Certificate") {
                        if let id = selectedCertificateId {
                            onSelect(id)
                        }
                    }
                    .disabled(selectedCertificateId == nil)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateClientCertificateView(manager: manager)
            }
        }
    }

    private func truncatedFingerprint(_ fingerprint: String) -> String {
        let parts = fingerprint.split(separator: ":")
        if parts.count > 8 {
            return parts.prefix(4).joined(separator: ":") + "..." + parts.suffix(4).joined(separator: ":")
        }
        return fingerprint
    }
}

#Preview("Certificate List") {
    NavigationStack {
        ClientCertificatesView(manager: ClientCertificateManager())
    }
}

#Preview("Create Certificate") {
    CreateClientCertificateView(manager: ClientCertificateManager())
}
