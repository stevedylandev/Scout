//
//  MediaPreviewView.swift
//  Scout
//

import SwiftUI
import AVFoundation
import PhotosUI
import Combine

struct MediaPreviewView: View {
    let media: MediaContent
    let onDismiss: () -> Void

    @EnvironmentObject private var themeSettings: ThemeSettings
    @State private var showingSaveOptions = false
    @State private var saveMessage: String?
    @State private var showingSaveAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch media.mediaType {
                case .image:
                    ImagePreviewContent(data: media.data)
                case .audio:
                    AudioPreviewContent(data: media.data, filename: media.suggestedFilename)
                case .unsupported:
                    UnsupportedContent(mimeType: media.mimeType)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(themeSettings.accentColor)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSaveOptions = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(themeSettings.accentColor)
                    }
                }
            }
            .confirmationDialog("Save File", isPresented: $showingSaveOptions, titleVisibility: .visible) {
                if media.mediaType == .image {
                    Button("Save to Photos") {
                        saveToPhotos()
                    }
                }
                Button("Save to Files") {
                    saveToFiles()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Save", isPresented: $showingSaveAlert) {
                Button("OK") {}
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    private func saveToPhotos() {
        guard media.mediaType == .image,
              let image = UIImage(data: media.data) else {
            saveMessage = "Unable to save image"
            showingSaveAlert = true
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    saveMessage = "Image saved to Photos"
                    showingSaveAlert = true
                } else {
                    saveMessage = "Photo library access denied. Please enable in Settings."
                    showingSaveAlert = true
                }
            }
        }
    }

    private func saveToFiles() {
        let filename = media.suggestedFilename
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try media.data.write(to: tempURL)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(activityVC, animated: true)
            }
        } catch {
            saveMessage = "Failed to save file: \(error.localizedDescription)"
            showingSaveAlert = true
        }
    }
}

// MARK: - Image Preview

struct ImagePreviewContent: View {
    let data: Data
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        if let uiImage = UIImage(data: data) {
            GeometryReader { geometry in
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                            .simultaneously(with:
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                Text("Unable to load image")
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Audio Preview

struct AudioPreviewContent: View {
    let data: Data
    let filename: String

    @EnvironmentObject private var themeSettings: ThemeSettings
    @StateObject private var audioPlayer = AudioPlayerViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 120))
                .foregroundColor(themeSettings.mediaAccentColor)

            Text(filename)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 16) {
                // Progress slider
                Slider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...max(audioPlayer.duration, 0.01)
                )
                .accentColor(themeSettings.mediaAccentColor)
                .padding(.horizontal, 32)

                // Time labels
                HStack {
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(formatTime(audioPlayer.duration))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 32)

                // Playback controls
                HStack(spacing: 48) {
                    Button(action: { audioPlayer.skipBackward() }) {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                            .foregroundColor(.white)
                    }

                    Button(action: { audioPlayer.togglePlayPause() }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(themeSettings.mediaAccentColor)
                    }

                    Button(action: { audioPlayer.skipForward() }) {
                        Image(systemName: "goforward.15")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            audioPlayer.loadData(data)
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Player ViewModel

class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var tempFileURL: URL?

    func loadData(_ data: Data) {
        // Write to temp file (AVAudioPlayer works better with files)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("audio")

        do {
            try data.write(to: tempURL)
            tempFileURL = tempURL

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: tempURL)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.play()
            startTimer()
        }
        isPlaying = player.isPlaying
    }

    func stop() {
        player?.stop()
        stopTimer()
        isPlaying = false

        // Cleanup temp file
        if let tempURL = tempFileURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func skipForward() {
        guard let player = player else { return }
        let newTime = min(player.currentTime + 15, duration)
        seek(to: newTime)
    }

    func skipBackward() {
        guard let player = player else { return }
        let newTime = max(player.currentTime - 15, 0)
        seek(to: newTime)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime

            if !player.isPlaying && self.isPlaying {
                self.isPlaying = false
                self.stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Unsupported Content

struct UnsupportedContent: View {
    let mimeType: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("Unsupported media type")
                .font(.headline)
                .foregroundColor(.white)
            Text(mimeType)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    MediaPreviewView(
        media: MediaContent(
            data: Data(),
            mimeType: "image/png",
            sourceURL: "gemini://example.com/test.png"
        ),
        onDismiss: {}
    )
    .environmentObject(ThemeSettings())
}
